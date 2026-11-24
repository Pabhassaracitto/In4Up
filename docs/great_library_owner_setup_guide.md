# Hướng dẫn owner — đưa Thư Viện Chung lên chạy thật (~20–30 phút)

> Repo: code đã xong và CI xanh (GLIB-001…008). Phần còn lại là 3 việc trên
> Firebase Console + 1 lệnh publish — chỉ owner làm được (cần quyền project
> `vipsound-df903`). Làm theo thứ tự 1 → 4, mỗi bước có cách kiểm tra ngay.

---

## Bước 0 — Chuẩn bị (2 phút)

- Mở <https://console.firebase.google.com/project/vipsound-df903/overview>
  bằng tài khoản `be.you8778@gmail.com`.
- Lấy **UID** của tài khoản owner:
  **Authentication → Users** → hàng `be.you8778@gmail.com` → copy cột **User UID**
  (chuỗi dạng `aBc123…`). Giữ sẵn trong clipboard — dùng ở bước 1, 2, 3.

---

## Bước 1 — Deploy Firestore Security Rules (5 phút)

> Vì sao: hiện tại collection `gl_packs` chưa có rules → app đọc catalog bị
> chặn → Thư Viện Chung trống. Rules mới cho phép đọc public pack đã duyệt,
> chặn mọi ghi trái phép (AT3).

1. **Firestore Database → Rules**.
2. **Thêm** block sau vào cuối — QUAN TRỌNG: dán **TRƯỚC 2 dấu `}` cuối
   cùng** (block `gl_*` phải nằm BÊN TRONG `match /databases/{database}/
   documents { … }`; dán ra ngoài sẽ báo "unexpected 'match'"). Giữ nguyên
   mọi `match` hiện có của app. Block Firestore **không chứa UID** (quyền
   admin đọc từ doc `gl_config/admins` ở Bước 2) — dán nguyên văn:

```
    // ===== Thư Viện Chung I4U (GLIB-003) =====
    function glIsAdmin() {
      return request.auth != null
        && exists(/databases/$(database)/documents/gl_config/admins)
        && request.auth.uid in get(/databases/$(database)/documents/gl_config/admins).data.uids;
    }

    match /gl_packs/{packId} {
      allow read: if resource.data.status == 'published' || glIsAdmin();
      allow write: if glIsAdmin();
    }

    match /gl_pack_versions/{docId} {
      allow read: if true;
      allow write: if glIsAdmin();
    }

    match /gl_contributions/{contribId} {
      allow create: if request.auth != null
        && request.resource.data.authorUid == request.auth.uid
        && request.resource.data.status == 'pending';
      allow read: if glIsAdmin()
        || (request.auth != null && resource.data.authorUid == request.auth.uid);
      allow update, delete: if glIsAdmin();
    }

    match /gl_config/{docId} {
      allow read: if glIsAdmin();
      allow write: if false;
    }
```

3. Bấm **Publish**.
4. **Kiểm tra** (Rules Playground ngay trong tab Rules): mô phỏng
   `get /gl_packs/anything` với **unauthenticated** → kỳ vọng **deny** là đúng
   (list public đi qua query có where status==published; đọc đơn lẻ yêu cầu
   doc đã published). Không sao nếu chưa rõ — bước 5 kiểm tra bằng app thật.

## Bước 2 — Tạo doc cổng admin `gl_config/admins` (2 phút)

> Vì sao: màn "Duyệt pack" (GLIB-007) chỉ hiện khi uid của bạn nằm trong doc
> này; rules ở bước 1 cũng đọc doc này để quyết định quyền ghi.

1. **Firestore Database → Data** → **+ Start collection**:
   - Collection ID: `gl_config`
   - Document ID: `admins`
   - Field: tên `uids`, kiểu **array** → thêm 1 phần tử **string** = UID ở
     Bước 0.
2. **Save**. (Doc này chỉ sửa tay trong Console — rules đã khóa ghi từ app.)

## Bước 3 — Deploy Storage Rules (3 phút)

> Vì sao: file `.i4upack` nằm trên Firebase Storage; rules cho phép ai cũng
> đọc pack đã publish (D5), chỉ owner ghi, user upload bản nháp vào thư mục
> của chính mình khi đóng góp (GLIB-006).

1. **Storage → Rules**.
2. Dán block sau (UID của bạn **đã điền sẵn** — dán nguyên văn), giữ nguyên
   rules cũ:

```
    // ===== Thư Viện Chung I4U =====
    match /packs/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null
        && request.auth.uid == "xCOoQZ6KX0OscU4X6EqWteHq8rZ2"
        && request.resource.size < 210 * 1024 * 1024;
    }

    match /gl_uploads/{uid}/{file} {
      allow read: if request.auth != null
        && (request.auth.uid == uid || request.auth.uid == "xCOoQZ6KX0OscU4X6EqWteHq8rZ2");
      allow write: if request.auth != null
        && request.auth.uid == uid
        && request.resource.size < 210 * 1024 * 1024;
    }
```

3. Bấm **Publish**.

## Bước 4 — Publish 22 pack seed (10 phút)

> Vì sao: catalog trống → app chưa có gì hiển thị. Script upload 22 file
> `.i4upack` lên `packs/seed/` và ghi 22 doc `gl_packs` (status `published`).

Trên máy đã clone repo (cần Python 3):

```bash
cd In4Up
pip install firebase-admin

# Lấy service account key: Firebase Console → Project settings →
# Service accounts → "Generate new private key" → lưu file JSON.
python3 tool/great_library_seed/build_seed_packs.py   # build 22 pack (nếu chưa)
python3 tool/great_library_seed/seed_publish.py \
    --service-account /đường/dẫn/tới/service-account.json
```

- Script in `✓ seed_vocab_500_verbs` … cho 22 pack → xong.
- Không cài được `firebase-admin`? Script sẽ in **checklist thủ công** tương
  đương (upload file + tạo doc qua Console theo `catalog_seed.json`).

> Lưu ý: audio trong pack v1 là placeholder tone (xem
> `tool/great_library_seed/README.md`); thay bằng TTS/LibriVox thật sau cũng
> được — chỉ cần build lại + chạy lại publish.

## Bước 5 — Kiểm tra end-to-end trên app (5 phút)

1. Mở app → **Thư Viện Chung**: thấy ≥ 20 pack seed.
2. Chọn 1 pack → **Tải về** → sau tải thấy khu **Xem trước nội dung** →
   **Nhập vào Studio** → từ xuất hiện trong Vườn nhớ.
3. Đăng nhập owner → AppBar Thư Viện Chung hiện biểu tượng **khiên admin**
   (Duyệt pack). Vào màn duyệt — hàng chờ đang trống là đúng.
4. (Tuỳ chọn) Thử đóng góp 1 pack bằng tài khoản thường → pack xuất hiện
   trong hàng chờ "Duyệt pack" của owner → Duyệt → pack lên catalog.

---

## Nếu gặp lỗi

| Triệu chứng | Nguyên nhân thường gặp | Cách xử lý |
|---|---|---|
| Catalog trống, lỗi "Firestore http 403" | Chưa deploy rules (Bước 1) | Dán lại block rules, Publish |
| Không thấy biểu tượng khiên admin | UID trong `gl_config/admins` sai/chưa tạo | Kiểm tra lại UID ở Authentication → Users, sửa doc |
| Đóng góp báo "not-signed-in" | Chưa đăng nhập trong app | Đăng nhập rồi gửi lại |
| Publish script lỗi 403 upload | Service account thiếu quyền Storage | Project settings → Service accounts → tạo key mới của tài khoản đủ quyền Editor |
