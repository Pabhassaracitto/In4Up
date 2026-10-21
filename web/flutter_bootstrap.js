{{flutter_js}}
{{flutter_build_config}}

// IN4-109 (2026-10-21) — trang web bị TRẮNG.
//
// Nguyên nhân: bootstrap mặc định của Flutter tải CanvasKit từ CDN
// `https://www.gstatic.com/flutter-canvaskit/<engineRevision>/`:
//     useLocalCanvasKit = false ⇒ E() trả URL gstatic.
// Build có sẵn thư mục `canvaskit/` cục bộ nhưng KHÔNG được dùng ⇒ mạng
// chặn/slow gstatic thì app không khởi tạo được renderer ⇒ trang trắng.
//
// Cách sửa: trỏ `canvasKitBaseUrl` về thư mục `canvaskit/` đi kèm build
// (copy trong `flutter build web`) ⇒ không phụ thuộc CDN, tải nhanh hơn.
//
// `serviceWorkerSettings` giữ nguyên để SW cũ (đã cache bản lỗi) được
// thay bằng bản mới — nếu bỏ SW, SW cũ vẫn kiểm soát trang và tiếp tục
// phục vụ file cũ ⇒ trang vẫn trắng.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
