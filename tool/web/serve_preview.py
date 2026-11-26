#!/usr/bin/env python3
"""tool/web/serve_preview.py — phục vụ bản build preview đã fetch từ nhánh git.

Vì sao có file này
------------------
Sandbox agent KHÔNG có Flutter SDK, bị chặn `storage.googleapis.com` (cài SDK),
chặn blob storage (tải artifact Actions) và không chạy được Chromium. Đường duy
nhất lấy được bản build là **git**: `.github/workflows/web_preview_branch.yml`
build trên runner rồi force-push vào nhánh `preview/<...>`, sandbox fetch về.

Script này lo hai việc còn lại:
  * `sync`  — fetch nhánh preview (github.com là host được phép) và giải nén vào
              `<dest>` (mặc định /tmp/preview). Dựng lại được sau khi mất /tmp.
  * `serve` — chạy HTTP server tĩnh bind 0.0.0.0:<port> để panel LIVE PREVIEW
              proxy tới `https://<port>-<sandboxId>.e2b.app`.

Vì sao không dùng `python3 -m http.server` trơn: Flutter web dùng routing
client-side, và preview có HAI app con (`/` gallery, `/web-lite/` app web chính
thức). Server ở đây trả `index.html` của ĐÚNG app con cho route sâu, và gửi
COOP/COEP để CanvasKit/SharedArrayBuffer không bị chặn.

Cách dùng
---------
  # dựng lại /tmp/preview từ nhánh preview (sau khi sandbox mất /tmp)
  python3 tool/web/serve_preview.py sync

  # chạy server (giữ chạy dài hạn ⇒ dùng start_process, không dùng bash)
  python3 tool/web/serve_preview.py serve 4173

  # sync rồi serve trong một lệnh
  python3 tool/web/serve_preview.py serve 4173 --sync

`sync` cần `git` và quyền đọc repo; `serve` chỉ cần thư mục build đã có.
"""

from __future__ import annotations

import argparse
import http.server
import os
import shutil
import socketserver
import subprocess
import sys
import tarfile
import tempfile
import urllib.parse

DEFAULT_REMOTE_BRANCH = "preview/arena-395208ef-in4up"
DEFAULT_DEST = "/tmp/preview"
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


# --------------------------------------------------------------------------- #
# sync: fetch nhánh preview và giải nén
# --------------------------------------------------------------------------- #

def _git(*args: str, cwd: str = REPO_ROOT) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", *args], cwd=cwd, capture_output=True, text=True, check=False
    )


def sync(branch: str, dest: str, remote: str = "origin") -> int:
    """Fetch `branch` (nông) rồi giải nén toàn bộ cây vào `dest`."""
    local_ref = "refs/remotes/origin/preview-tmp"

    print(f"[sync] fetch {remote} {branch} …", flush=True)
    res = _git(
        "fetch", "--depth=1", "--force",
        f"{remote}", f"{branch}:{local_ref}",
    )
    if res.returncode != 0:
        print(f"[sync] LỖI fetch:\n{res.stderr}", file=sys.stderr)
        return 1

    sha = _git("rev-parse", local_ref).stdout.strip()
    print(f"[sync] nhánh trỏ tới {sha[:12]}", flush=True)

    if os.path.isdir(dest):
        shutil.rmtree(dest)
    os.makedirs(dest, exist_ok=True)

    with tempfile.TemporaryFile() as blob:
        res = subprocess.run(
            ["git", "archive", local_ref],
            cwd=REPO_ROOT, stdout=blob, stderr=subprocess.PIPE, check=False,
        )
        if res.returncode != 0:
            print(f"[sync] LỖI git archive: {res.stderr.decode()}", file=sys.stderr)
            return 1
        blob.seek(0)
        with tarfile.open(fileobj=blob) as tar:
            tar.extractall(dest)

    required = ["index.html", "main.dart.js", "flutter_bootstrap.js"]
    missing = [f for f in required if not os.path.isfile(os.path.join(dest, f))]
    if missing:
        print(f"[sync] LỖI: thiếu {missing} trong {dest}", file=sys.stderr)
        return 1

    info = os.path.join(dest, "BUILD_INFO.txt")
    if os.path.isfile(info):
        print("[sync] BUILD_INFO.txt:")
        with open(info, encoding="utf-8") as fh:
            for line in fh:
                print("        " + line.rstrip())
    print(f"[sync] OK → {dest} ({_du_mb(dest):.0f} MB)", flush=True)
    return 0


def _du_mb(path: str) -> float:
    total = 0
    for root, _dirs, files in os.walk(path):
        for name in files:
            try:
                total += os.path.getsize(os.path.join(root, name))
            except OSError:
                pass
    return total / (1024 * 1024)


# --------------------------------------------------------------------------- #
# serve: HTTP tĩnh + SPA fallback theo từng app con
# --------------------------------------------------------------------------- #

class PreviewHandler(http.server.SimpleHTTPRequestHandler):
    """Static handler cho preview 2 app con.

    Route sâu (không phải file tĩnh) trả index.html của đúng app con:
      /web-lite/<bất kỳ>  → /web-lite/index.html
      /<bất kỳ>          → /index.html
    """

    root = DEFAULT_DEST

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=type(self).root, **kwargs)

    def translate_path(self, path: str) -> str:  # noqa: D102
        clean = urllib.parse.urlparse(path).path
        resolved = super().translate_path(path)

        # 1) file tĩnh có thật
        if os.path.isfile(resolved):
            return resolved

        # 2) thư mục có index.html  (/web-lite/ hoặc /web-lite)
        for candidate in (os.path.join(resolved, "index.html"),
                          resolved + "/index.html"):
            if os.path.isfile(candidate):
                return candidate

        # 3) route sâu ⇒ index.html của app con tương ứng
        if clean == "/web-lite" or clean.startswith("/web-lite/"):
            return os.path.join(self.root, "web-lite", "index.html")
        return os.path.join(self.root, "index.html")

    def end_headers(self) -> None:  # noqa: D102
        if self.path.endswith((".js", ".json", ".html", ".wasm", ".txt")):
            self.send_header("Cache-Control", "no-store")
        # CanvasKit cần các header này khi engine dùng SharedArrayBuffer.
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "credentialless")
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()

    def log_message(self, fmt: str, *args) -> None:  # noqa: D102
        sys.stderr.write("%s %s\n" % (self.address_string(), fmt % args))


def serve(port: int, dest: str, bind: str = "0.0.0.0") -> int:
    if not os.path.isdir(dest):
        print(
            f"[serve] LỖI: {dest} không tồn tại.\n"
            f"        Chạy trước: python3 tool/web/serve_preview.py sync",
            file=sys.stderr,
        )
        return 1

    PreviewHandler.root = dest
    socketserver.TCPServer.allow_reuse_address = True

    with socketserver.ThreadingTCPServer((bind, port), PreviewHandler) as httpd:
        httpd.daemon_threads = True
        print(f"[serve] {dest} → http://{bind}:{port}", flush=True)
        if (os.path.isfile(os.path.join(dest, "index.html"))
                and os.path.isdir(os.path.join(dest, "web-lite"))):
            print("[serve]   /           → UI Gallery", flush=True)
            print("[serve]   /web-lite/  → app web chính thức", flush=True)
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n[serve] dừng theo yêu cầu", flush=True)
    return 0


# --------------------------------------------------------------------------- #

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Sync + phục vụ bản build preview của In4Up.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_sync = sub.add_parser("sync", help="fetch nhánh preview vào --dest")
    p_sync.add_argument("--branch", default=DEFAULT_REMOTE_BRANCH)
    p_sync.add_argument("--remote", default="origin")
    p_sync.add_argument("--dest", default=DEFAULT_DEST)

    p_serve = sub.add_parser("serve", help="chạy HTTP server tĩnh")
    p_serve.add_argument("port", type=int)
    p_serve.add_argument("--dest", default=DEFAULT_DEST)
    p_serve.add_argument("--bind", default="0.0.0.0")
    p_serve.add_argument(
        "--sync", action="store_true",
        help="fetch + giải nén trước khi serve (dựng lại từ đầu)",
    )
    p_serve.add_argument("--branch", default=DEFAULT_REMOTE_BRANCH)

    args = parser.parse_args(argv)

    if args.cmd == "sync":
        return sync(args.branch, args.dest, remote=args.remote)

    if args.sync:
        code = sync(args.branch, args.dest, remote="origin")
        if code != 0:
            return code
    return serve(args.port, args.dest, bind=args.bind)


if __name__ == "__main__":
    raise SystemExit(main())
