// Module Gradle RIÊNG cho engine TTS VieNeu-TTS (ADR-0028, lane L6 của 1.29.0).
//
// Vì sao không nhét vào `:app`:
//   audio.cpp kéo theo bản ggml **của nó** (`third_party/audio.cpp/external/ggml`,
//   ggml 0.12.0) trong khi llama.cpp của `:app` kéo ggml 0.21.0. Cả hai
//   `add_subdirectory()` vào CÙNG một project CMake ⇒ trùng tên target:
//     add_library cannot create ALIAS target "ggml::ggml" because another target
//     with the same name already exists.
//   (run 43318161013 — configureCMakeDebug[arm64-v8a] đỏ)
//   audio.cpp KHÔNG có option nào để dùng ggml bên ngoài (nó
//   `add_subdirectory(AUDIOCPP_GGML_SOURCE_DIR)` vô điều kiện), nên cách duy nhất
//   là tách thành CMake project riêng. Gradle module riêng ⇒ AGP gọi CMake hai
//   lần với hai thư mục build riêng ⇒ mỗi bên một bản ggml, mỗi bên một .so.
//
// Hệ quả: `flutter build apk` (máy owner, không cần script phụ) vẫn dựng engine
// và đóng gói `libvieneu_tts.so` + `libaudiocpp.so`; `libsea_g2p_rs.so` do
// `android/app/src/main/jniLibs/arm64-v8a/` cung cấp (workflow dựng bằng cargo-ndk).

plugins {
    id("com.android.library")
}

android {
    namespace = "com.in4up.vieneu"

    defaultConfig {
        minSdk = 24

        externalNativeBuild {
            cmake {
                // c++_static giống :app — tránh phụ thuộc libc++_shared.so của Flutter.
                arguments += listOf("-DANDROID_STL=c++_static")

                // CHỈ hai target cần cho app. Mặc định AGP build MỌI target trong
                // project ⇒ kéo cả audiocpp_cli / audiocpp_server / model_perf, và
                // app/workflow/workflow.cpp dùng `posix_spawnp` (chỉ có từ API 28,
                // minSdk của app là 24) ⇒ run 43323259962 đỏ:
                //   workflow.cpp:392: error: use of undeclared identifier 'posix_spawnp'
                targets += listOf("audiocpp", "vieneu_tts")
            }
        }

        ndk {
            // CHỈ arm64-v8a: ggml + audio.cpp build rất lâu và model Q8_0 188 MB
            // không chạy nổi trên máy 32-bit. Thêm ABI khác = thời gian CI ×N.
            abiFilters += listOf("arm64-v8a")
        }
    }

    externalNativeBuild {
        cmake {
            path = file("CMakeLists.txt")
            // Giống :app — SDK trên runner ubuntu-latest chỉ có cmake 3.31.5;
            // máy dev dùng 3.22.1 mặc định của Android SDK.
            version = if (System.getenv("CI") == "true") "3.31.5" else "3.22.1"
        }
    }
}
