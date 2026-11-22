# Thư Viện Chung I4U — Firestore schema & Security Rules (GLIB-003)

> PLAN-049 · ADR-0031 D2/D4/D5. Ngày: 2026-11-15.
> Repo hiện **không** có file `firestore.rules` (rules app đang quản trong
> Firebase Console). Tài liệu này cung cấp block rules để **owner dán vào
> Console** + hướng dẫn tạo doc admin. Agent không tự deploy rules.

---

## 1. Collections

### `gl_packs/{packId}` — catalog công khai
Một doc = metadata của pack (trải phẳng fields của `PackManifest`) + 3 field file:

| Field | Kiểu | Ghi chú |
|---|---|---|
| `schemaVersion` | int | hiện = 1 |
| `id` | string | trùng packId trong path |
| `type` | string | `vocab` / `audio` / `image` |
| `title`, `description` | string | |
| `srcLang`, `dstLang` | string | `en`, `vi`, `pi`… |
| `tags` | array\<string\> | |
| `level` | string | `A1..C2`, `mixed` |
| `author` | map | `{uid, displayName, verified}` |
| `license` | string | `cc0`/`cc-by`/`cc-by-nc`/`self-made`/`permission-granted` |
| `version` | int | ≥ 1, tăng mỗi lần phát hành lại |
| `status` | string | `pending`/`published`/`rejected`/`hidden` — **query public lọc `published`** |
| `sizeBytes` | int | tổng payload (ước lượng cho UI) |
| `fileBytes` | int | dung lượng file `.i4upack` thật |
| `fileSha256` | string | sha256 nguyên file — DownloadManager verify |
| `storage` | map | `{backend: 'firebase'|'supabase', path: 'packs/{packId}/{version}.i4upack'}` |
| `stats` | map | `{downloads, rating, ratings}` |
| `createdAt`, `updatedAt`, `publishedAt` | timestamp | |

### `gl_pack_versions/{packId_version}` (P1+ — lịch sử bản phát hành)
`{packId, version, fileSha256, fileBytes, storage, releasedAt, changelog}`

### `gl_contributions/{contribId}` — hàng chờ kiểm duyệt (P1)
`{packId, authorUid, status: 'pending', manifest, storage, submittedAt, reviewedAt, reviewerNote}`

### `gl_config/admins` — cổng admin (D6)
Doc duy nhất, tạo **thủ công** trong Console:
```
gl_config/admins  →  { "uids": ["<UID của be.you8778@gmail.com>"] }
```
Lấy UID: Firebase Console → Authentication → Users → copy UID của email owner.

---

## 2. Firestore Security Rules — block `gl_*` để owner dán

> Dán **bổ sung** vào rules hiện có (Console → Firestore → Rules), giữ nguyên
> các match cũ của app.

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ... giữ nguyên rules hiện có của app ...

    // ===== Thư Viện Chung I4U (GLIB-003) =====
    // Admin = uid nằm trong gl_config/admins.uids (đọc trực tiếp, không đệ quy rules).
    function glIsAdmin() {
      return request.auth != null
        && exists(/databases/$(database)/documents/gl_config/admins)
        && request.auth.uid in get(/databases/$(database)/documents/gl_config/admins).data.uids;
    }

    match /gl_packs/{packId} {
      // D5: ai cũng đọc được pack published (kể cả chưa đăng nhập).
      allow read: if resource.data.status == 'published' || glIsAdmin();
      // P0: chỉ admin (seed script của owner). P1 vẫn giữ — contribute đi qua
      // gl_contributions, admin duyệt rồi mới ghi gl_packs.
      allow write: if glIsAdmin();
    }

    match /gl_pack_versions/{docId} {
      allow read: if true; // checksum/size không nhạy cảm
      allow write: if glIsAdmin();
    }

    match /gl_contributions/{contribId} {
      // P1: user đăng nhập gửi đề xuất cho CHÍNH MÌNH, luôn ở trạng thái pending.
      allow create: if request.auth != null
        && request.resource.data.authorUid == request.auth.uid
        && request.resource.data.status == 'pending';
      allow read: if glIsAdmin()
        || (request.auth != null && resource.data.authorUid == request.auth.uid);
      allow update, delete: if glIsAdmin();
    }

    match /gl_config/{docId} {
      allow read: if glIsAdmin();
      allow write: if false; // chỉ sửa tay trong Console
    }
  }
}
```

## 3. Firebase Storage Rules — block packs

Console → Storage → Rules:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    // Pack đã publish: đọc public (D5). Ghi chỉ uid owner (seed/publish).
    match /packs/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null
        && request.auth.uid == "<UID của be.you8778@gmail.com>"
        && request.resource.size < 210 * 1024 * 1024; // trần 200MB + margin
    }

    // P1: user upload bản nháp chờ duyệt vào thư mục của chính mình.
    match /gl_uploads/{uid}/{file} {
      allow read: if request.auth != null
        && (request.auth.uid == uid
            || request.auth.uid == "<UID của be.you8778@gmail.com>");
      allow write: if request.auth != null
        && request.auth.uid == uid
        && request.resource.size < 210 * 1024 * 1024;
    }
  }
}
```

## 4. Checklist deploy (owner làm, ~10 phút)

1. **Console → Authentication**: copy UID của `be.you8778@gmail.com`.
2. **Firestore → Data**: tạo collection `gl_config` → doc `admins` → field
   `uids` kiểu **array**, thêm UID vừa copy.
3. **Firestore → Rules**: dán block `gl_*` (mục 2) → Publish.
4. **Storage → Rules**: thay `<UID của be.you8778@gmail.com>` → dán mục 3 → Publish.
5. **Kiểm tra nhanh** (Rules Playground hoặc curl):
   - `GET /v1/.../documents:runQuery` không token lọc `status==published` → 200.
   - Ghi thẳng `gl_packs` bằng tài khoản thường → bị chặn (AT3 PLAN-049).

## 5. Test AT3 (chặn ghi trái phép) — sau khi deploy

```bash
# Chưa đăng nhập — cố tạo pack published (phải bị chặn 403):
curl -s -o /dev/null -w '%{http_code}' -X POST \
  "https://firestore.googleapis.com/v1/projects/vipsound-df903/databases/(default)/documents/gl_packs" \
  -H 'Content-Type: application/json' \
  -d '{"fields":{"status":{"stringValue":"published"}}}'
# Kỳ vọng: 401/403
```
