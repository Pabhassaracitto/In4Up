# Priority-locale chrome leak report

Sinh tự động bởi `python3 tool/lang_ui_inventory.py --write-report`.
Đừng sửa tay — chạy lại tool sau mỗi wave bản dịch.

- Chrome strings quét được: **4391** trong **325** file presentation.
- `vietnamese`: chuỗi vẫn hiện tiếng Việt ở locale đó (vi phạm rule #5).
- `english`: chuỗi vẫn hiện English trên màn hình (kể cả khi fallback sang English) — đây là việc còn lại của các wave bản địa hoá tiếp theo.

| locale | vietnamese | english |
| --- | ---: | ---: |
| `zh` | 339 | 87 |
| `zh_TW` | 339 | 87 |
| `hi` | 341 | 95 |
| `si` | 339 | 96 |
| `my` | 339 | 218 |
| `th` | 339 | 210 |
| `ja` | 339 | 207 |

## `zh` — theo khu vực

| khu vực | còn lại |
| --- | ---: |
| Web Reader | 56 |
| Learn by heart | 51 |
| Tools / WordList | 43 |
| Translation | 43 |
| Other features | 30 |
| TTS | 27 |
| Other screens | 26 |
| YouTube | 23 |
| Other | 22 |
| PDF Reader | 18 |
| Shared widgets | 13 |
| Memory | 12 |
| Grammar / Understand | 12 |
| Settings | 9 |
| Cabin | 8 |
| Tipiṭaka | 6 |
| Listen | 5 |
| Read | 5 |
| Understand | 5 |
| Video library | 4 |
| AI Chat | 4 |
| OCR | 3 |
| Home | 1 |

## `zh_TW` — theo khu vực

| khu vực | còn lại |
| --- | ---: |
| Web Reader | 56 |
| Learn by heart | 51 |
| Tools / WordList | 43 |
| Translation | 43 |
| Other features | 30 |
| TTS | 27 |
| Other screens | 26 |
| YouTube | 23 |
| Other | 22 |
| PDF Reader | 18 |
| Shared widgets | 13 |
| Memory | 12 |
| Grammar / Understand | 12 |
| Settings | 9 |
| Cabin | 8 |
| Tipiṭaka | 6 |
| Listen | 5 |
| Read | 5 |
| Understand | 5 |
| Video library | 4 |
| AI Chat | 4 |
| OCR | 3 |
| Home | 1 |

## `hi` — theo khu vực

| khu vực | còn lại |
| --- | ---: |
| Web Reader | 56 |
| Learn by heart | 51 |
| Translation | 44 |
| Tools / WordList | 43 |
| Other features | 33 |
| TTS | 28 |
| Other screens | 26 |
| YouTube | 23 |
| Other | 22 |
| PDF Reader | 18 |
| Shared widgets | 13 |
| Memory | 12 |
| Grammar / Understand | 12 |
| Settings | 10 |
| Cabin | 8 |
| Listen | 7 |
| Read | 7 |
| Tipiṭaka | 6 |
| Understand | 5 |
| Video library | 4 |
| AI Chat | 4 |
| OCR | 3 |
| Home | 1 |

## `si` — theo khu vực

| khu vực | còn lại |
| --- | ---: |
| Web Reader | 56 |
| Learn by heart | 51 |
| Translation | 44 |
| Tools / WordList | 43 |
| Other features | 33 |
| TTS | 28 |
| Other screens | 26 |
| YouTube | 23 |
| Other | 22 |
| PDF Reader | 18 |
| Shared widgets | 13 |
| Memory | 12 |
| Grammar / Understand | 12 |
| Settings | 10 |
| Cabin | 8 |
| Listen | 7 |
| Read | 6 |
| Tipiṭaka | 6 |
| Understand | 5 |
| Video library | 4 |
| AI Chat | 4 |
| OCR | 3 |
| Home | 1 |

## `my` — theo khu vực

| khu vực | còn lại |
| --- | ---: |
| Web Reader | 61 |
| Learn by heart | 52 |
| Translation | 48 |
| Tools / WordList | 45 |
| Grammar / Understand | 45 |
| Other features | 44 |
| PDF Reader | 43 |
| YouTube | 31 |
| TTS | 28 |
| Other screens | 26 |
| Other | 26 |
| Shared widgets | 22 |
| Settings | 17 |
| Listen | 13 |
| Memory | 13 |
| Cabin | 10 |
| Read | 8 |
| Tipiṭaka | 6 |
| Understand | 5 |
| OCR | 5 |
| Video library | 4 |
| AI Chat | 4 |
| Home | 1 |

## `th` — theo khu vực

| khu vực | còn lại |
| --- | ---: |
| Web Reader | 60 |
| Learn by heart | 52 |
| Translation | 48 |
| Tools / WordList | 45 |
| Grammar / Understand | 45 |
| PDF Reader | 43 |
| Other features | 41 |
| YouTube | 31 |
| TTS | 28 |
| Other screens | 26 |
| Other | 26 |
| Shared widgets | 20 |
| Settings | 17 |
| Memory | 13 |
| Listen | 11 |
| Cabin | 10 |
| Read | 8 |
| Tipiṭaka | 6 |
| Understand | 5 |
| OCR | 5 |
| Video library | 4 |
| AI Chat | 4 |
| Home | 1 |

## `ja` — theo khu vực

| khu vực | còn lại |
| --- | ---: |
| Web Reader | 60 |
| Learn by heart | 52 |
| Translation | 48 |
| Tools / WordList | 45 |
| Grammar / Understand | 45 |
| PDF Reader | 43 |
| Other features | 39 |
| YouTube | 31 |
| TTS | 27 |
| Other screens | 26 |
| Other | 26 |
| Shared widgets | 21 |
| Settings | 17 |
| Memory | 13 |
| Listen | 11 |
| Cabin | 10 |
| Read | 7 |
| Tipiṭaka | 6 |
| Understand | 5 |
| OCR | 5 |
| Video library | 4 |
| AI Chat | 4 |
| Home | 1 |

## Chi tiết (ưu tiên chuỗi còn tiếng Việt)

### `zh`

- **AI Chat** — `⚡ ${usage.promptTokens} token vào · ${usage.completionTokens} token ra`
- **Cabin** — `App chưa hỗ trợ nhận diện offline cho $language — chọn Tiếng Việt/English hoặc dùng Engine "Hệ thống".`
- **Cabin** — `Cabin chỉ nhận diện $language khi model đã có trên máy. Thiếu model, app KHÔNG tự nhận $language bằng model ngôn ngữ khác.`
- **Cabin** — `Dịch: ${pref == HyMtOfflinePreference.hymt ? "Hy-MT" : pref == HyMtOfflinePreference.mlkit ? "ML Kit" : "Offline"}`
- **Cabin** — `Lỗi khởi động Sherpa STT: $e`
- **Cabin** — `Máy đang có $languageNote — cần bạn xác nhận mới dùng thay.`
- **Cabin** — `}.Máy có thể KHÔNG có sẵn dịch vụ Speech Recognition. Bạn có thể chuyển sang Engine "Offline (sherpa)" để nhận diện không cần dịch vụ hệ thống.`
- **Grammar / Understand** — `Không`
- **Grammar / Understand** — `Preset cá nhân gồm ${categories.length} nhóm từ loại được chọn thủ công.`
- **Grammar / Understand** — `Preset hiện tại: $activePresetName`
- **Grammar / Understand** — `^Preset cá nhân gồm \d+ nhóm từ loại được chọn thủ công\.$`
- **Grammar / Understand** — `Đang chỉnh tay từ preset gần nhất: $previousPresetName`
- **Grammar / Understand** — `Đang ẩn ${hiddenCategories.length} nhóm từ loại. Chúng chưa bị mất — bạn có thể bật lại từng nhóm, bật lại tất cả, hoặc quay về preset gần nhất $previousPresetName.`
- **Home** — `Speech recognition của hệ thống không khả dụng`
- **Learn by heart** — `$diff ngày`
- **Learn by heart** — `$value lần`
- **Learn by heart** — `${math.max(1, (base * 0.8).round())} ngày`
- **Learn by heart** — `${math.max(1, (s * 1.1).round())} ngày`
- **Learn by heart** — `${math.max(1, base)} ngày`
- **Learn by heart** — `${math.max(2, (base * 1.3).round())} ngày`
- **Learn by heart** — `${math.max(2, (s * 1.25).round())} ngày`
- **Learn by heart** — `${math.max(4, (s * 1.5).round())} ngày`
- **Learn by heart** — `1 ngày`
- **Learn by heart** — `Bản dịch (${RecitationLanguage.fromCode(_targetLang).displayName(`
- **Learn by heart** — `Bản dịch (${item.targetLanguage.displayName(`
- **Learn by heart** — `Chưa đặt tên`
- **Learn by heart** — `Chạm mở các từ ẩn để tự kiểm tra`
- **Learn by heart** — `Cần củng cố`
- **Learn by heart** — `Cẩn trọng trong từng suy nghĩ và lời nói hàng ngày.`
- **Learn by heart** — `Ghép đoạn (Chunk 1 → ${chunk.index})`
- **Learn by heart** — `Gần đúng`
- **Learn by heart** — `Hành động từ tâm ô nhiễm đem lại khổ đau.`
- **Learn by heart** — `Học ${chunk.label}`
- **Learn by heart** — `Học lại`
- **Learn by heart** — `Hợp nhất các đoạn đã học trước khi sang phần tiếp theo`
- **Learn by heart** — `Không được để trống`
- **Learn by heart** — `Kinh Pháp Cú`
- **Learn by heart** — `Kinh Tụng & Chân Ngôn`
- **Learn by heart** — `Kệ Ngôn & Thơ Thiền`
- **Learn by heart** — `Lắng nghe và đọc theo nhịp`
- **Learn by heart** — `Nguyên văn (${RecitationLanguage.fromCode(_sourceLang).displayName(`
- **Learn by heart** — `Nguyên văn (${item.sourceLanguage.displayName(`
- **Learn by heart** — `Rất tốt! Giữ vững tiến độ để đạt chuẩn thuộc lòng 100%.`
- **Learn by heart** — `Sai nhiều`
- **Learn by heart** — `Thử thách: ${chunk.label}`
- **Learn by heart** — `Tự Tạo & Ghi Chú`
- **Learn by heart** — `Ví dụ: Kệ Pháp Cú 01, Từ Bi Kinh...`
- **Learn by heart** — `Ví dụ: Tâm dẫn đầu các pháp...`
- **Learn by heart** — `Xuất sắc! Trí nhớ bền vững được tăng gấp đôi (2x FSRS Weight).`
- **Learn by heart** — `hôm nay`
- **Learn by heart** — `Ý dẫn đầu các pháp,
Ý làm chủ, ý tạo...`
- **Learn by heart** — `Ý dẫn đầu, Ý ô nhiễm, Khổ não`
- **Learn by heart** — `Đang ôn`
- **Learn by heart** — `Đã ghi nhận củng cố lại. FSRS sẽ đưa vào lịch ôn tập sớm.`
- **Learn by heart** — `Đúng hoàn toàn`
- **Learn by heart** — `Được`
- **Learn by heart** — `Đọc theo nhịp 2 dòng`
- **Learn by heart** — `Đọc trọn vẹn bài kinh và đánh giá chu kỳ ôn tập`
- **Learn by heart** — `✅ LHB sync (REST): kéo ${records.length} doc, áp dụng $applied thay đổi`
- **Learn by heart** — `✅ LHB sync (REST): đẩy ${ids.length} thay đổi`
- **Learn by heart** — `✅ LHB sync: kéo ${records.length} doc, áp dụng $applied thay đổi`
- **Learn by heart** — `✅ LHB sync: đẩy ${ids.length} thay đổi`
- **Listen** — `  Âm cần chú ý: ${word.phonemeIssues.join(`
- **Listen** — `Chưa có bản ghi nội dung (transcript).

Chạy "⚡ Tự tạo mục lục" (VAD + Whisper)
hoặc tạo LRC trong tab AI —
sau đó tìm chữ là nhảy tới đúng chỗ.`
- **Listen** — `Chưa có mục lục.
Nhấn "⚡ Tự tạo mục lục" phía trên để app
tự tách đoạn theo khoảng lặng (VAD)
và đặt tên chương (Whisper).

Hoặc nhấn "＋ Chương" để tạo thủ công
(tự neo vào vị trí đang nghe).`
- **Listen** — `Âm cần chú ý: ${word.phonemeIssues.join(`
- **Memory** — `${(stats.averageAccuracy * 100).round()}% chính xác`
- **Memory** — `${absDiff.inDays} ngày trước`
- **Memory** — `${absDiff.inHours} giờ trước`
- **Memory** — `${absDiff.inMinutes} phút trước`
- **Memory** — `${item.overdueHours.toStringAsFixed(1)}h trước`
- **Memory** — `${item.totalReviews}x ôn`
- **Memory** — `${stats.reviewedToday}/${stats.dueToday} hôm nay`
- **Memory** — `Chưa có từ nào ở giai đoạn "${context.uiText(stage.label)}"`
- **Memory** — `Xóa "${item.word}" khỏi vườn nhớ?
Dữ liệu ôn tập sẽ mất.`
- **Memory** — `sau ${diff.inDays} ngày`
- **Memory** — `sau ${diff.inHours} giờ`
- **Memory** — `Đã ôn ${stats.reviewedToday} từ
Đúng ${stats.correctToday}/${stats.reviewedToday}`
- **OCR** — `Dữ liệu ảnh ${pixels.length} byte không khớp ${width}x$height BGRA`
- **OCR** — `Không tìm thấy ảnh: $imagePath`
- **OCR** — `Lỗi nhận dạng chữ: $e`
- **Other** — `Chưa cấu hình GOOGLE_DESKTOP_CLIENT_SECRET.
Lấy secret từ Google Cloud Console và truyền qua --dart-define hoặc env.
Ví dụ: flutter run -d windows --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=GOCSPX-...`
- **Other** — `Chưa cấu hình Google Sign In cho Desktop.
Tạo OAuth client ID loại Desktop app trong Google Cloud Console > APIs & Services > Credentials.
Truyền qua --dart-define=GOOGLE_DESKTOP_CLIENT_ID=xxx --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=yyy hoặc đặt env var GOOGLE_DESKTOP_CLIENT_ID/SECRET.`
- **Other** — `Chương ${i + 1}`
- **Other** — `Không khởi tạo được Google Sign-In ($e). Khởi động lại app rồi thử lại.`
- **Other** — `Không lấy được ID token từ Google. Kiểm tra:
1. SHA-1/SHA-256 của BẢN ĐANG CÀI có trong Firebase Console chưa? (Project Settings > Your apps > SHA certificate fingerprints)
2. Google Sign-In provider đã bật trong Authentication > Sign-in method chưa?
3. serverClientId=$_webClientId có đúng Web client không?`
- **Other** — `Lỗi tải danh sách: $e`
- **Other** — `Lỗi đăng nhập: $e`
- **Other** — `cuộn ${(scrollProgressHint! * 100).round()}%`
- **Other** — `có`
- **Other** — `dòng ${lineIndex + 1}`
- **Other** — `dòng ${lineIndexHint! + 1}`
- **Other** — `không tách được đoạn theo khoảng lặng — file quá ngắn (< 2× độ dài đoạn tối thiểu) hoặc máy không đọc được waveform/thời lượng của file này. Thử: mở bài audio trong trình phát rồi chạy lại, hoặc giảm "đoạn tối thiểu" trong preset Tách nhiều.`
- **Other** — `Đang bóc băng qua API (whisper-large-v3)…
File dài sẽ tự chia chunk — có thể tắt mạng giữa chừng để dừng.`
- **Other** — `Đang nhận diện giọng nói (Whisper)…
File dài có thể mất vài phút.`
- **Other features** — ` (dòng ${context.focusLineIndex! + 1})`
- **Other features** — `${(compressionRatio * 100).round()}% độ dài nguồn`
- **Other features** — `${(copiedPhraseRatio * 100).round()}% cụm 3 từ trùng nguồn`
- **Other features** — `${(keywordPresenceRatio * 100).round()}% từ khóa quan sát được`
- **Other features** — `${shadowing.sessionResults.length} lần`
- **Other features** — `Cho mình MỘT gợi ý ngắn giúp hiểu tốt hơn đoạn này: chỉ gợi ý mở (từ khoá, cấu trúc cần chú ý), chưa giải thích trọn vẹn, để mình tự suy ra.`
- **Other features** — `Chưa có câu nào đang phát. Cho mình một gợi ý luyện tập tiếp theo phù hợp với chế độ mình đang chọn nhé.`
- **Other features** — `Câu mình đang hỏi$lineLabel:
`
- **Other features** — `File audio không tồn tại (existsSync false): $audioPath`
- **Other features** — `Giải thích câu trong dấu « » giúp mình: dịch nghĩa tiếng Việt, chỉ ra các từ/cụm từ khó và cấu trúc ngữ pháp đáng chú ý. Viết ngắn gọn, dễ hiểu.`
- **Other features** — `Hoàn tất! ${allSegments.length} segments trong ${totalSw.elapsed.inSeconds}s`
- **Other features** — `Kiểm tra hiểu bài của mình về đoạn vừa rồi: đặt 3 câu hỏi từ dễ đến khó, đợi mình tự trả lời, rồi mới đưa đáp án ngắn ở cuối.`
- **Other features** — `Mình đang học ở tab Hiểu (${parts.join(`
- **Other features** — `Tóm tắt đoạn trong « Đoạn vừa nghe » bằng 3–5 câu tiếng Việt: nêu ý chính và 3–5 từ vựng đáng nhớ kèm nghĩa ngắn.`
- **Other features** — `Tối đa: ${shadowing.settings.maxRecordDuration.inSeconds}s`
- **Other features** — `VAD lỗi: $e`
- **Other features** — `bài: « ${context.sourceTitle} »`
- **Other features** — `Đang bóc băng chunk ${i + 1}/$totalChunks...`
- **Other features** — `Đang cắt chunk ${i + 1}/$totalChunks (${seg.startTime.toStringAsFixed(1)}s->${seg.endTime.toStringAsFixed(1)}s)...`
- **Other features** — `Đang dịch $done/$total khối chữ…`
- **Other features** — `Đang quét VAD… ${(f * 100).toStringAsFixed(0)}%`
- **Other features** — `Đã tìm ${speechSegments.length} đoạn speech, bỏ $skipped đoạn silence`
- **Other features** — `ℹ️ screen translate: vùng chọn $requestedRegion quá bé/ngoài màn hình ⇒ dịch cả màn hình`
- **Other features** — `⚠️ Segment $i: không cắt được chunk (FFmpeg lỗi?) — bỏ qua THAY VÌ re-transcribe toàn bộ file gốc`
- **Other screens** — `"${entry.title}" sẽ bị xoá khỏi thư viện cloud.`
- **Other screens** — `${tp.lines.length} dòng`
- **Other screens** — `Cài từ điển có sẵn bằng một chạm (offline)`
- **Other screens** — `Đã cập nhật "${updated.title}" từ văn bản hiện tại`
- **Other screens** — `Đã cập nhật file cloud "${updatedEntry.title}"`
- **Other screens** — `Đã cập nhật trực tiếp file cloud "${updated.title}"`
- **Other screens** — `Đã lưu "${entry.title}" lên cloud`
- **PDF Reader** — `    <!-- không có highlight/ghi chú nào để xuất -->
`
- **PDF Reader** — `${annotations.length} ghi chú đã lưu`
- **PDF Reader** — `${controller.annotations.length} ghi chú`
- **PDF Reader** — `${entry.encounterCount} lần gặp`
- **PDF Reader** — `${entry.sourceFiles.length} nguồn`
- **PDF Reader** — `PDF đoạn chọn · ${_title.replaceAll(`
- **PDF Reader** — `aàáảãạăằắẳẵặâầấẩẫậ`
- **PDF Reader** — `dđ`
- **PDF Reader** — `eèéẻẽẹêềếểễệ`
- **PDF Reader** — `iìíỉĩị`
- **PDF Reader** — `oòóỏõọôồốổỗộơờớởỡợ`
- **PDF Reader** — `uùúủũụưừứửữự`
- **PDF Reader** — `yỳýỷỹỵ`
- **PDF Reader** — `✅ Đã load "$_title" vào Text Studio`
- **PDF Reader** — `✅ Đã lưu "$_displayWord" vào Vườn Nhớ`
- **Read** — ` : selectedText}" → Đã lưu nhanh`
- **Read** — `${sourceLanguage.translationCode}×3 chậm 0.75x`
- **Read** — `Bạn bỏ sót một số từ khóa quan trọng: ${result.missingWords.join(`
- **Read** — `Đáp án: ${_blankPrompts.map((e) => `
- **Settings** — `Ngôn ngữ: ${lang.isEmpty ? `
- **Settings** — `Xoá (${level.sizeInMB}MB)`
- **Settings** — `Xoá (${profile.approxSizeMB}MB)`
- **Shared widgets** — `$displayLabel chưa chắc`
- **Shared widgets** — `$displayLabel ổn`
- **Shared widgets** — `${_getRepeatCount(level)}x lặp`
- **Shared widgets** — `${_lines!.length} dòng · Nhấn để mở rộng`
- **Shared widgets** — `${diff.inDays} ngày`
- **Shared widgets** — `${diff.inHours}h trước`
- **Shared widgets** — `${widget.title} (${_lines!.length} dòng)`
- **Shared widgets** — `Ví dụ: ${word.example!.trim()}`
- **Shared widgets** — `Ôn tiếp sau ${word.daysUntilDue} ngày`
- **Shared widgets** — `Đang chờ... ${player.gapDuration.toStringAsFixed(1)}s`
- **Shared widgets** — `Đã lưu $relativeTime`
- **Shared widgets** — `Đã lưu: ${segment.title}`
- **Shared widgets** — `Đã phân loại $_classifiedCount / ${_candidates.length}`
- **TTS** — `"${provider.label}" lỗi: ${e.message}`
- **TTS** — `"${provider.label}" phản hồi quá chậm (timeout)`
- **TTS** — `"${provider.label}" đang rate-limit (429) — thử giảm tốc độ gọi`
- **TTS** — `${_friendlyError(e)} (đoạn ${i + 1}/${chunks.length})`
- **TTS** — `${_preview!.originalLineCount} dòng → ${_preview!.totalLines} dòng (~${_preview!.avgWordsPerLine.toStringAsFixed(1)} từ/dòng)`
- **TTS** — `API key sai/thiếu quyền tại "${provider.label}"`
- **TTS** — `Chưa có giọng Piper cho $language`
- **TTS** — `Dữ liệu trả về không phải audio hợp lệ: ${e.message}`
- **TTS** — `Edge TTS lỗi: $error`
- **TTS** — `Edge TTS từ chối kết nối WebSocket: ${error.message}`
- **TTS** — `Không có engine TTS nào phát được văn bản này ($lang).`
- **TTS** — `Không kết nối được "${provider.label}" (mất mạng/sai địa chỉ server)`
- **TTS** — `Không nạp được giọng Piper $name (thiếu espeak-ng-data?)`
- **TTS** — `Lỗi phát: $e`
- **TTS** — `Lỗi stream: $e`
- **TTS** — `Provider "${provider.label}" chưa chọn model TTS — cấu hình ở Server & API`
- **TTS** — `Provider "${provider.label}" thiếu baseUrl`
- **TTS** — `Tối thiểu $_minWords từ trước khi tách`
- **TTS** — `Tối đa $_maxWords từ/dòng`
- **TTS** — `Áp dụng (${_preview!.totalLines} dòng)`
- **Tipiṭaka** — `Tuyển tập chính văn ${orderIndex + 1}`
- **Tipiṭaka** — `diệu`
- **Tipiṭaka** — `luật`
- **Tools / WordList** — `"$documentTitle" — ${tp.lines.length} dòng`
- **Tools / WordList** — `$_correct / $_total đúng`
- **Tools / WordList** — `$pct% đã ôn tập`
- **Tools / WordList** — `$value ký tự`
- **Tools / WordList** — `${_selectedIds.length} đã chọn`
- **Tools / WordList** — `${provider.blindSpots} điểm mù`
- **Tools / WordList** — `${provider.masteredCount} thành thạo`
- **Tools / WordList** — `${w.sourceFiles.length} nguồn`
- **Tools / WordList** — `${widget.tools.where((t) => t.isAvailable).length} tính năng`
- **Tools / WordList** — `${words.length} từ tìm thấy · $selectedCount được chọn`
- **Tools / WordList** — `(${displayWords.length} từ)`
- **Tools / WordList** — `Chọn từ/cụm muốn lưu riêng từ "${parent.word}"`
- **Tools / WordList** — `Gặp lần $encounterCount!`
- **Tools / WordList** — `Import $count từ vào danh sách`
- **Tools / WordList** — `Không có từ nào cần ôn ${context.uiText(_skillName(_currentSkill!))}!`
- **Tools / WordList** — `Lưu ${selWords.length + selPhrases.length} mục`
- **Tools / WordList** — `Lưu từ: "$word"`
- **Tools / WordList** — `Lỗi đọc file: $e`
- **Tools / WordList** — `Ngữ cảnh (${entry.contexts.length})`
- **Tools / WordList** — `Thuần thục: ${(word.mastery * 100).toInt()}%`
- **Tools / WordList** — `Tất cả (${displayWords.length} từ)`
- **Tools / WordList** — `Tối thiểu $_minLength ký tự`
- **Tools / WordList** — `Ví dụ phức: ${data[`
- **Tools / WordList** — `Ví dụ đơn: ${data[`
- **Tools / WordList** — `Vòng ${_playbackService.listRepeatCurrent}/${_playbackService.listRepeatCount}`
- **Tools / WordList** — `Vòng ${_playbackService.listRepeatCurrent}/∞`
- **Tools / WordList** — `hình`
- **Tools / WordList** — `hình ảnh`
- **Tools / WordList** — `minh họa`
- **Tools / WordList** — `sai $wrong/${w.totalReviews} lần`
- **Tools / WordList** — `Ôn tập: ${context.uiText(_skillName(skill)).toUpperCase()}`
- **Tools / WordList** — `Đánh giá: ${context.uiText(_skillName(skill))}`
- **Tools / WordList** — `Đã lưu "$word" vào Tools`
- **Tools / WordList** — `Đã lưu ${ui.uiText(typeLabel)}: $text`
- **Tools / WordList** — `ảnh`
- **Tools / WordList** — `ảnh minh họa`
- **Tools / WordList** — `✅ Đã tạo ${selWords.length + selPhrases.length} entry con`
- **Tools / WordList** — `🌱 "${entry.word}" đã được gieo trong vườn nhớ rồi!`
- **Tools / WordList** — `🌱 Đã gieo mầm "${entry.word}" vào vườn trí nhớ!`
- **Tools / WordList** — `📅 Lần tới: ${entry.daysUntilDue} ngày nữa`
- **Tools / WordList** — `📌 Gặp nhiều lần (${frequent.length})`
- **Translation** — `$base (cặp nguồn đã chọn)`
- **Translation** — `$base (nguồn tự nhận diện — kiểm tra lại ngôn ngữ nguồn)`
- **Translation** — `${language.flag} Đã đổi bản dịch và giọng đọc sang ${language.nativeName}`
- **Translation** — `${language.nativeName} • ngôn ngữ nguồn`
- **Translation** — `File Hy-MT $issue: $path — bấm "Tải về" để tải lại file đầy đủ hoặc chọn đúng model Hy-MT GGUF.`
- **Translation** — `Hy-MT không hỗ trợ cặp $sourceLang → $targetLang`
- **Translation** — `Hy-MT trả về rỗng cho segment ${chunkIndex + 1}/$chunkCount`
- **Translation** — `Isolate Hy-MT không còn sống: ${_deathError ?? `
- **Translation** — `Isolate Hy-MT đã chết: ${error == null ? `
- **Translation** — `Không có heartbeat trong ${_pingTimeout.inSeconds}s`
- **Translation** — `Không tải được Hy-MT (HTTP ${e.response?.statusCode ?? `
- **Translation** — `Lỗi ML Kit: $e`
- **Translation** — `Lỗi tải Hy-MT: $e`
- **Translation** — `Lỗi tải gói $code`
- **Translation** — `ML Kit không hỗ trợ cặp $source → $target`
- **Translation** — `Model Hy-MT tải về $issue`
- **Translation** — `Rate limited (429) tại $server`
- **Translation** — `Server $server yêu cầu API key`
- **Translation** — `Timeout ML Kit sau 30 giây`
- **Translation** — `Timeout sau 12 giây`
- **Translation** — `Tự nhận diện ${sourceLanguage.nativeName} → ${targetLanguage.nativeName}`
- **Translation** — `[đĐơƠưƯạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹýàáảãạèéẻẽẹ`
- **Translation** — `bị cắt ($mb MB; cần khoảng 601 MB)`
- **Translation** — `không đọc được file ($e)`
- **Translation** — `không đọc được file (${e.osError?.message ?? e.message})`
- **Translation** — `model trả rỗng cho segment ${chunkIndex + 1}/$chunkCount`
- **Translation** — `mất slot glossary $lost ở segment ${chunkIndex + 1}/$chunkCount`
- **Translation** — `việt`
- **Translation** — `}). Wi-Fi rồi thử lại.`
- **Translation** — `}. Thử "Tải về" lại model rồi dịch lại.`
- **Translation** — `ìíỉĩịòóỏõọùúủũụ]`
- **Translation** — `Đã nhận diện ${widget.sourceLanguage.flag} ${widget.sourceLanguage.nativeName} • ${AppLanguageCatalog.languages.length} ngôn ngữ đích`
- **Translation** — `Đã tải gói $code`
- **Translation** — `ℹ️ LLM API: chưa cấu hình provider cho dịch LLM (màn Server & API) hoặc routing "Dịch" đang "Chỉ offline" — bỏ qua lớp LLM, dùng engine khác. (thông báo này chỉ in 1 lần)`
- **Translation** — `🧩 Hỗn hợp ngôn ngữ · ${engines.join(`
- **Understand** — `Dừng (${_formatDuration(shadowing.recordingDuration)})`
- **Understand** — `Đếm: ${shadowing.countdown}`
- **Video library** — `Quyền đọc thư mục đã mất (do gỡ hoặc cập nhật app). Chạm "Chọn thư mục khác" để cấp lại quyền.`
- **Web Reader** — `$draftCount batch nháp`
- **Web Reader** — `$noteCount ghi chú`
- **Web Reader** — `$pinnedArticleCount bài ghim`
- **Web Reader** — `$resumeCount tiếp tục`
- **Web Reader** — `$selectedCount đã chọn`
- **Web Reader** — `$statusCount theo bộ lọc`
- **Web Reader** — `${_candidates.length} ứng viên`
- **Web Reader** — `${analyzed!.encounterCount} lần gặp`
- **Web Reader** — `${collection.linkCount} liên kết`
- **Web Reader** — `${currentCollection.linkCount} liên kết`
- **Web Reader** — `${diff.inDays} ngày trước`
- **Web Reader** — `${diff.inHours} giờ trước`
- **Web Reader** — `${diff.inMinutes} phút trước`
- **Web Reader** — `${draft.candidates.length} mục`
- **Web Reader** — `).length} dòng`
- **Web Reader** — `Batch nháp · ${draftBatches.length}`
- **Web Reader** — `Bài có ghi chú · ${notedArticles.length}`
- **Web Reader** — `Bài đã ghim · ${pinnedArticles.length}`
- **Web Reader** — `Bộ sưu tập có sẵn · ${presetCollections.length}`
- **Web Reader** — `Cập nhật ${context.uiText(_HistoryTile._formatVisitedAt(draft.updatedAt))}`
- **Web Reader** — `Ghi chú · ${_controller.pageTitle.isEmpty ? _controller.currentUrl : _controller.pageTitle}`
- **Web Reader** — `Ghi chú · ${entry.title.isEmpty ? entry.url : entry.title}`
- **Web Reader** — `Mới $_newCount`
- **Web Reader** — `Mới mở · ${context.uiText(_HistoryTile._formatVisitedAt(entry.effectiveReadAt))}`
- **Web Reader** — `Nhóm "${collection.title}" sẽ bị xoá, nhưng các preset mặc định và lịch sử duyệt sẽ không bị ảnh hưởng.`
- **Web Reader** — `Nhóm của tôi · ${userCollections.length}`
- **Web Reader** — `Nhập $_selectedCount mục vào WordList`
- **Web Reader** — `Nhập $_selectedReadyCount mục sẵn sàng`
- **Web Reader** — `Ready đã chọn: $_selectedReadyCount`
- **Web Reader** — `Sẵn sàng $_readyCount`
- **Web Reader** — `Thiếu: ${missing.join(`
- **Web Reader** — `Tiến độ ~ ${entry.progressPercent}%`
- **Web Reader** — `Tiếp tục đọc · ${resumeEntries.length}`
- **Web Reader** — `Trang này đã có sẵn trong nhóm "${collection.title}"`
- **Web Reader** — `Trang này đã có sẵn trong nhóm "${currentCollection.title}"`
- **Web Reader** — `Trích đoạn · $sourceLabel`
- **Web Reader** — `Trích đoạn · ${_controller.pageTitle.isEmpty ? _controller.currentUrl : _controller.pageTitle}`
- **Web Reader** — `Xem tất cả ${collection.linkCount} link`
- **Web Reader** — `Đang lọc: “$queryLabel”`
- **Web Reader** — `Đang đọc ${entry.progressPercent}%`
- **Web Reader** — `Đã chọn $_selectedCount`
- **Web Reader** — `Đã chọn: $_selectedCount`
- **Web Reader** — `Đã có $_existingCount`
- **Web Reader** — `Đã enrich $_enrichedCount`
- **Web Reader** — `Đã lưu nhanh · ${bookmarks.length}`
- **Web Reader** — `Đã lưu trang hiện tại vào nhóm "${currentCollection.title}"`
- **Web Reader** — `Đã phân loại $_selectedClassifiedCount / $_selectedCount`
- **Web Reader** — `Đã đánh giá $_classifiedCount`
- **Web Reader** — `Độ khó đã lưu: ${context.uiText(analyzed!.userDifficulty!.label)}`
- **Web Reader** — `Ưu tiên $_priorityCount`
- **Web Reader** — `✅ Đã load vào Text Studio — ${text.split(`
- **Web Reader** — `✅ Đã lưu "$cleanWord" vào Vườn Nhớ`
- **Web Reader** — `✅ Đã lưu vào nhóm "${collection.title}"`
- **Web Reader** — `📚 Đã bổ sung ngữ cảnh cho "$cleanWord" trong WordList`
- **Web Reader** — `📚 Đã thêm "$cleanWord" vào WordList`
- **Web Reader** — `🛠️ Đã áp dụng bulk fields cho ${targets.length} mục`
- **YouTube** — `$ext · ${kbps}kbps (chọn thủ công)`
- **YouTube** — `$v lượt xem`
- **YouTube** — `${(v / 1000).toStringAsFixed(0)}K lượt xem`
- **YouTube** — `${(v / 1000000).toStringAsFixed(1)}M lượt xem`
- **YouTube** — `${_captions.length} dòng`
- **YouTube** — `${d.inDays ~/ 365} năm trước`
- **YouTube** — `${d.inDays} ngày trước`
- **YouTube** — `Chuẩn bị · ${kbps}kbps · ${_sizeLabel(totalBytes)}`
- **YouTube** — `Không có captions cho "$_lang".
Thử ngôn ngữ khác.`
- **YouTube** — `Lấy captions ($_lang)`
- **YouTube** — `Lỗi tải phụ đề: $e`
- **YouTube** — `Tải thất bại: ${event.message}`
- **YouTube** — `YouTube từ chối phát video này (lỗi cấu hình trình phát, mã $code). Bấm Thử lại, hoặc Mở ngoài để xem trong trình duyệt.`
- **YouTube** — `yt-dlp lỗi: $e`
- **YouTube** — `Đã chờ ${_waitedSec}s. AI chạy trên máy nên có thể mất 30–90 giây.`
- **YouTube** — `Đã lưu phụ đề (${lines.length} dòng): ${path ?? "?"}`
- **YouTube** — `Đã lưu phụ đề vào: $folder`
- **YouTube** — `Đã tải xong (${event.quality})`
- **YouTube** — `✅ [in4up-yt] tải xong $received / $totalBytes bytes (số lần nối: $attempt)`
- **YouTube** — `❌ [in4up-yt] tải chưa hoàn tất: $got / $totalBytes bytes sau $_maxAttempts lần thử.`

### `zh_TW`

- **AI Chat** — `⚡ ${usage.promptTokens} token vào · ${usage.completionTokens} token ra`
- **Cabin** — `App chưa hỗ trợ nhận diện offline cho $language — chọn Tiếng Việt/English hoặc dùng Engine "Hệ thống".`
- **Cabin** — `Cabin chỉ nhận diện $language khi model đã có trên máy. Thiếu model, app KHÔNG tự nhận $language bằng model ngôn ngữ khác.`
- **Cabin** — `Dịch: ${pref == HyMtOfflinePreference.hymt ? "Hy-MT" : pref == HyMtOfflinePreference.mlkit ? "ML Kit" : "Offline"}`
- **Cabin** — `Lỗi khởi động Sherpa STT: $e`
- **Cabin** — `Máy đang có $languageNote — cần bạn xác nhận mới dùng thay.`
- **Cabin** — `}.Máy có thể KHÔNG có sẵn dịch vụ Speech Recognition. Bạn có thể chuyển sang Engine "Offline (sherpa)" để nhận diện không cần dịch vụ hệ thống.`
- **Grammar / Understand** — `Không`
- **Grammar / Understand** — `Preset cá nhân gồm ${categories.length} nhóm từ loại được chọn thủ công.`
- **Grammar / Understand** — `Preset hiện tại: $activePresetName`
- **Grammar / Understand** — `^Preset cá nhân gồm \d+ nhóm từ loại được chọn thủ công\.$`
- **Grammar / Understand** — `Đang chỉnh tay từ preset gần nhất: $previousPresetName`
- **Grammar / Understand** — `Đang ẩn ${hiddenCategories.length} nhóm từ loại. Chúng chưa bị mất — bạn có thể bật lại từng nhóm, bật lại tất cả, hoặc quay về preset gần nhất $previousPresetName.`
- **Home** — `Speech recognition của hệ thống không khả dụng`
- **Learn by heart** — `$diff ngày`
- **Learn by heart** — `$value lần`
- **Learn by heart** — `${math.max(1, (base * 0.8).round())} ngày`
- **Learn by heart** — `${math.max(1, (s * 1.1).round())} ngày`
- **Learn by heart** — `${math.max(1, base)} ngày`
- **Learn by heart** — `${math.max(2, (base * 1.3).round())} ngày`
- **Learn by heart** — `${math.max(2, (s * 1.25).round())} ngày`
- **Learn by heart** — `${math.max(4, (s * 1.5).round())} ngày`
- **Learn by heart** — `1 ngày`
- **Learn by heart** — `Bản dịch (${RecitationLanguage.fromCode(_targetLang).displayName(`
- **Learn by heart** — `Bản dịch (${item.targetLanguage.displayName(`
- **Learn by heart** — `Chưa đặt tên`
- **Learn by heart** — `Chạm mở các từ ẩn để tự kiểm tra`
- **Learn by heart** — `Cần củng cố`
- **Learn by heart** — `Cẩn trọng trong từng suy nghĩ và lời nói hàng ngày.`
- **Learn by heart** — `Ghép đoạn (Chunk 1 → ${chunk.index})`
- **Learn by heart** — `Gần đúng`
- **Learn by heart** — `Hành động từ tâm ô nhiễm đem lại khổ đau.`
- **Learn by heart** — `Học ${chunk.label}`
- **Learn by heart** — `Học lại`
- **Learn by heart** — `Hợp nhất các đoạn đã học trước khi sang phần tiếp theo`
- **Learn by heart** — `Không được để trống`
- **Learn by heart** — `Kinh Pháp Cú`
- **Learn by heart** — `Kinh Tụng & Chân Ngôn`
- **Learn by heart** — `Kệ Ngôn & Thơ Thiền`
- **Learn by heart** — `Lắng nghe và đọc theo nhịp`
- **Learn by heart** — `Nguyên văn (${RecitationLanguage.fromCode(_sourceLang).displayName(`
- **Learn by heart** — `Nguyên văn (${item.sourceLanguage.displayName(`
- **Learn by heart** — `Rất tốt! Giữ vững tiến độ để đạt chuẩn thuộc lòng 100%.`
- **Learn by heart** — `Sai nhiều`
- **Learn by heart** — `Thử thách: ${chunk.label}`
- **Learn by heart** — `Tự Tạo & Ghi Chú`
- **Learn by heart** — `Ví dụ: Kệ Pháp Cú 01, Từ Bi Kinh...`
- **Learn by heart** — `Ví dụ: Tâm dẫn đầu các pháp...`
- **Learn by heart** — `Xuất sắc! Trí nhớ bền vững được tăng gấp đôi (2x FSRS Weight).`
- **Learn by heart** — `hôm nay`
- **Learn by heart** — `Ý dẫn đầu các pháp,
Ý làm chủ, ý tạo...`
- **Learn by heart** — `Ý dẫn đầu, Ý ô nhiễm, Khổ não`
- **Learn by heart** — `Đang ôn`
- **Learn by heart** — `Đã ghi nhận củng cố lại. FSRS sẽ đưa vào lịch ôn tập sớm.`
- **Learn by heart** — `Đúng hoàn toàn`
- **Learn by heart** — `Được`
- **Learn by heart** — `Đọc theo nhịp 2 dòng`
- **Learn by heart** — `Đọc trọn vẹn bài kinh và đánh giá chu kỳ ôn tập`
- **Learn by heart** — `✅ LHB sync (REST): kéo ${records.length} doc, áp dụng $applied thay đổi`
- **Learn by heart** — `✅ LHB sync (REST): đẩy ${ids.length} thay đổi`
- **Learn by heart** — `✅ LHB sync: kéo ${records.length} doc, áp dụng $applied thay đổi`
- **Learn by heart** — `✅ LHB sync: đẩy ${ids.length} thay đổi`
- **Listen** — `  Âm cần chú ý: ${word.phonemeIssues.join(`
- **Listen** — `Chưa có bản ghi nội dung (transcript).

Chạy "⚡ Tự tạo mục lục" (VAD + Whisper)
hoặc tạo LRC trong tab AI —
sau đó tìm chữ là nhảy tới đúng chỗ.`
- **Listen** — `Chưa có mục lục.
Nhấn "⚡ Tự tạo mục lục" phía trên để app
tự tách đoạn theo khoảng lặng (VAD)
và đặt tên chương (Whisper).

Hoặc nhấn "＋ Chương" để tạo thủ công
(tự neo vào vị trí đang nghe).`
- **Listen** — `Âm cần chú ý: ${word.phonemeIssues.join(`
- **Memory** — `${(stats.averageAccuracy * 100).round()}% chính xác`
- **Memory** — `${absDiff.inDays} ngày trước`
- **Memory** — `${absDiff.inHours} giờ trước`
- **Memory** — `${absDiff.inMinutes} phút trước`
- **Memory** — `${item.overdueHours.toStringAsFixed(1)}h trước`
- **Memory** — `${item.totalReviews}x ôn`
- **Memory** — `${stats.reviewedToday}/${stats.dueToday} hôm nay`
- **Memory** — `Chưa có từ nào ở giai đoạn "${context.uiText(stage.label)}"`
- **Memory** — `Xóa "${item.word}" khỏi vườn nhớ?
Dữ liệu ôn tập sẽ mất.`
- **Memory** — `sau ${diff.inDays} ngày`
- **Memory** — `sau ${diff.inHours} giờ`
- **Memory** — `Đã ôn ${stats.reviewedToday} từ
Đúng ${stats.correctToday}/${stats.reviewedToday}`
- **OCR** — `Dữ liệu ảnh ${pixels.length} byte không khớp ${width}x$height BGRA`
- **OCR** — `Không tìm thấy ảnh: $imagePath`
- **OCR** — `Lỗi nhận dạng chữ: $e`
- **Other** — `Chưa cấu hình GOOGLE_DESKTOP_CLIENT_SECRET.
Lấy secret từ Google Cloud Console và truyền qua --dart-define hoặc env.
Ví dụ: flutter run -d windows --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=GOCSPX-...`
- **Other** — `Chưa cấu hình Google Sign In cho Desktop.
Tạo OAuth client ID loại Desktop app trong Google Cloud Console > APIs & Services > Credentials.
Truyền qua --dart-define=GOOGLE_DESKTOP_CLIENT_ID=xxx --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=yyy hoặc đặt env var GOOGLE_DESKTOP_CLIENT_ID/SECRET.`
- **Other** — `Chương ${i + 1}`
- **Other** — `Không khởi tạo được Google Sign-In ($e). Khởi động lại app rồi thử lại.`
- **Other** — `Không lấy được ID token từ Google. Kiểm tra:
1. SHA-1/SHA-256 của BẢN ĐANG CÀI có trong Firebase Console chưa? (Project Settings > Your apps > SHA certificate fingerprints)
2. Google Sign-In provider đã bật trong Authentication > Sign-in method chưa?
3. serverClientId=$_webClientId có đúng Web client không?`
- **Other** — `Lỗi tải danh sách: $e`
- **Other** — `Lỗi đăng nhập: $e`
- **Other** — `cuộn ${(scrollProgressHint! * 100).round()}%`
- **Other** — `có`
- **Other** — `dòng ${lineIndex + 1}`
- **Other** — `dòng ${lineIndexHint! + 1}`
- **Other** — `không tách được đoạn theo khoảng lặng — file quá ngắn (< 2× độ dài đoạn tối thiểu) hoặc máy không đọc được waveform/thời lượng của file này. Thử: mở bài audio trong trình phát rồi chạy lại, hoặc giảm "đoạn tối thiểu" trong preset Tách nhiều.`
- **Other** — `Đang bóc băng qua API (whisper-large-v3)…
File dài sẽ tự chia chunk — có thể tắt mạng giữa chừng để dừng.`
- **Other** — `Đang nhận diện giọng nói (Whisper)…
File dài có thể mất vài phút.`
- **Other features** — ` (dòng ${context.focusLineIndex! + 1})`
- **Other features** — `${(compressionRatio * 100).round()}% độ dài nguồn`
- **Other features** — `${(copiedPhraseRatio * 100).round()}% cụm 3 từ trùng nguồn`
- **Other features** — `${(keywordPresenceRatio * 100).round()}% từ khóa quan sát được`
- **Other features** — `${shadowing.sessionResults.length} lần`
- **Other features** — `Cho mình MỘT gợi ý ngắn giúp hiểu tốt hơn đoạn này: chỉ gợi ý mở (từ khoá, cấu trúc cần chú ý), chưa giải thích trọn vẹn, để mình tự suy ra.`
- **Other features** — `Chưa có câu nào đang phát. Cho mình một gợi ý luyện tập tiếp theo phù hợp với chế độ mình đang chọn nhé.`
- **Other features** — `Câu mình đang hỏi$lineLabel:
`
- **Other features** — `File audio không tồn tại (existsSync false): $audioPath`
- **Other features** — `Giải thích câu trong dấu « » giúp mình: dịch nghĩa tiếng Việt, chỉ ra các từ/cụm từ khó và cấu trúc ngữ pháp đáng chú ý. Viết ngắn gọn, dễ hiểu.`
- **Other features** — `Hoàn tất! ${allSegments.length} segments trong ${totalSw.elapsed.inSeconds}s`
- **Other features** — `Kiểm tra hiểu bài của mình về đoạn vừa rồi: đặt 3 câu hỏi từ dễ đến khó, đợi mình tự trả lời, rồi mới đưa đáp án ngắn ở cuối.`
- **Other features** — `Mình đang học ở tab Hiểu (${parts.join(`
- **Other features** — `Tóm tắt đoạn trong « Đoạn vừa nghe » bằng 3–5 câu tiếng Việt: nêu ý chính và 3–5 từ vựng đáng nhớ kèm nghĩa ngắn.`
- **Other features** — `Tối đa: ${shadowing.settings.maxRecordDuration.inSeconds}s`
- **Other features** — `VAD lỗi: $e`
- **Other features** — `bài: « ${context.sourceTitle} »`
- **Other features** — `Đang bóc băng chunk ${i + 1}/$totalChunks...`
- **Other features** — `Đang cắt chunk ${i + 1}/$totalChunks (${seg.startTime.toStringAsFixed(1)}s->${seg.endTime.toStringAsFixed(1)}s)...`
- **Other features** — `Đang dịch $done/$total khối chữ…`
- **Other features** — `Đang quét VAD… ${(f * 100).toStringAsFixed(0)}%`
- **Other features** — `Đã tìm ${speechSegments.length} đoạn speech, bỏ $skipped đoạn silence`
- **Other features** — `ℹ️ screen translate: vùng chọn $requestedRegion quá bé/ngoài màn hình ⇒ dịch cả màn hình`
- **Other features** — `⚠️ Segment $i: không cắt được chunk (FFmpeg lỗi?) — bỏ qua THAY VÌ re-transcribe toàn bộ file gốc`
- **Other screens** — `"${entry.title}" sẽ bị xoá khỏi thư viện cloud.`
- **Other screens** — `${tp.lines.length} dòng`
- **Other screens** — `Cài từ điển có sẵn bằng một chạm (offline)`
- **Other screens** — `Đã cập nhật "${updated.title}" từ văn bản hiện tại`
- **Other screens** — `Đã cập nhật file cloud "${updatedEntry.title}"`
- **Other screens** — `Đã cập nhật trực tiếp file cloud "${updated.title}"`
- **Other screens** — `Đã lưu "${entry.title}" lên cloud`
- **PDF Reader** — `    <!-- không có highlight/ghi chú nào để xuất -->
`
- **PDF Reader** — `${annotations.length} ghi chú đã lưu`
- **PDF Reader** — `${controller.annotations.length} ghi chú`
- **PDF Reader** — `${entry.encounterCount} lần gặp`
- **PDF Reader** — `${entry.sourceFiles.length} nguồn`
- **PDF Reader** — `PDF đoạn chọn · ${_title.replaceAll(`
- **PDF Reader** — `aàáảãạăằắẳẵặâầấẩẫậ`
- **PDF Reader** — `dđ`
- **PDF Reader** — `eèéẻẽẹêềếểễệ`
- **PDF Reader** — `iìíỉĩị`
- **PDF Reader** — `oòóỏõọôồốổỗộơờớởỡợ`
- **PDF Reader** — `uùúủũụưừứửữự`
- **PDF Reader** — `yỳýỷỹỵ`
- **PDF Reader** — `✅ Đã load "$_title" vào Text Studio`
- **PDF Reader** — `✅ Đã lưu "$_displayWord" vào Vườn Nhớ`
- **Read** — ` : selectedText}" → Đã lưu nhanh`
- **Read** — `${sourceLanguage.translationCode}×3 chậm 0.75x`
- **Read** — `Bạn bỏ sót một số từ khóa quan trọng: ${result.missingWords.join(`
- **Read** — `Đáp án: ${_blankPrompts.map((e) => `
- **Settings** — `Ngôn ngữ: ${lang.isEmpty ? `
- **Settings** — `Xoá (${level.sizeInMB}MB)`
- **Settings** — `Xoá (${profile.approxSizeMB}MB)`
- **Shared widgets** — `$displayLabel chưa chắc`
- **Shared widgets** — `$displayLabel ổn`
- **Shared widgets** — `${_getRepeatCount(level)}x lặp`
- **Shared widgets** — `${_lines!.length} dòng · Nhấn để mở rộng`
- **Shared widgets** — `${diff.inDays} ngày`
- **Shared widgets** — `${diff.inHours}h trước`
- **Shared widgets** — `${widget.title} (${_lines!.length} dòng)`
- **Shared widgets** — `Ví dụ: ${word.example!.trim()}`
- **Shared widgets** — `Ôn tiếp sau ${word.daysUntilDue} ngày`
- **Shared widgets** — `Đang chờ... ${player.gapDuration.toStringAsFixed(1)}s`
- **Shared widgets** — `Đã lưu $relativeTime`
- **Shared widgets** — `Đã lưu: ${segment.title}`
- **Shared widgets** — `Đã phân loại $_classifiedCount / ${_candidates.length}`
- **TTS** — `"${provider.label}" lỗi: ${e.message}`
- **TTS** — `"${provider.label}" phản hồi quá chậm (timeout)`
- **TTS** — `"${provider.label}" đang rate-limit (429) — thử giảm tốc độ gọi`
- **TTS** — `${_friendlyError(e)} (đoạn ${i + 1}/${chunks.length})`
- **TTS** — `${_preview!.originalLineCount} dòng → ${_preview!.totalLines} dòng (~${_preview!.avgWordsPerLine.toStringAsFixed(1)} từ/dòng)`
- **TTS** — `API key sai/thiếu quyền tại "${provider.label}"`
- **TTS** — `Chưa có giọng Piper cho $language`
- **TTS** — `Dữ liệu trả về không phải audio hợp lệ: ${e.message}`
- **TTS** — `Edge TTS lỗi: $error`
- **TTS** — `Edge TTS từ chối kết nối WebSocket: ${error.message}`
- **TTS** — `Không có engine TTS nào phát được văn bản này ($lang).`
- **TTS** — `Không kết nối được "${provider.label}" (mất mạng/sai địa chỉ server)`
- **TTS** — `Không nạp được giọng Piper $name (thiếu espeak-ng-data?)`
- **TTS** — `Lỗi phát: $e`
- **TTS** — `Lỗi stream: $e`
- **TTS** — `Provider "${provider.label}" chưa chọn model TTS — cấu hình ở Server & API`
- **TTS** — `Provider "${provider.label}" thiếu baseUrl`
- **TTS** — `Tối thiểu $_minWords từ trước khi tách`
- **TTS** — `Tối đa $_maxWords từ/dòng`
- **TTS** — `Áp dụng (${_preview!.totalLines} dòng)`
- **Tipiṭaka** — `Tuyển tập chính văn ${orderIndex + 1}`
- **Tipiṭaka** — `diệu`
- **Tipiṭaka** — `luật`
- **Tools / WordList** — `"$documentTitle" — ${tp.lines.length} dòng`
- **Tools / WordList** — `$_correct / $_total đúng`
- **Tools / WordList** — `$pct% đã ôn tập`
- **Tools / WordList** — `$value ký tự`
- **Tools / WordList** — `${_selectedIds.length} đã chọn`
- **Tools / WordList** — `${provider.blindSpots} điểm mù`
- **Tools / WordList** — `${provider.masteredCount} thành thạo`
- **Tools / WordList** — `${w.sourceFiles.length} nguồn`
- **Tools / WordList** — `${widget.tools.where((t) => t.isAvailable).length} tính năng`
- **Tools / WordList** — `${words.length} từ tìm thấy · $selectedCount được chọn`
- **Tools / WordList** — `(${displayWords.length} từ)`
- **Tools / WordList** — `Chọn từ/cụm muốn lưu riêng từ "${parent.word}"`
- **Tools / WordList** — `Gặp lần $encounterCount!`
- **Tools / WordList** — `Import $count từ vào danh sách`
- **Tools / WordList** — `Không có từ nào cần ôn ${context.uiText(_skillName(_currentSkill!))}!`
- **Tools / WordList** — `Lưu ${selWords.length + selPhrases.length} mục`
- **Tools / WordList** — `Lưu từ: "$word"`
- **Tools / WordList** — `Lỗi đọc file: $e`
- **Tools / WordList** — `Ngữ cảnh (${entry.contexts.length})`
- **Tools / WordList** — `Thuần thục: ${(word.mastery * 100).toInt()}%`
- **Tools / WordList** — `Tất cả (${displayWords.length} từ)`
- **Tools / WordList** — `Tối thiểu $_minLength ký tự`
- **Tools / WordList** — `Ví dụ phức: ${data[`
- **Tools / WordList** — `Ví dụ đơn: ${data[`
- **Tools / WordList** — `Vòng ${_playbackService.listRepeatCurrent}/${_playbackService.listRepeatCount}`
- **Tools / WordList** — `Vòng ${_playbackService.listRepeatCurrent}/∞`
- **Tools / WordList** — `hình`
- **Tools / WordList** — `hình ảnh`
- **Tools / WordList** — `minh họa`
- **Tools / WordList** — `sai $wrong/${w.totalReviews} lần`
- **Tools / WordList** — `Ôn tập: ${context.uiText(_skillName(skill)).toUpperCase()}`
- **Tools / WordList** — `Đánh giá: ${context.uiText(_skillName(skill))}`
- **Tools / WordList** — `Đã lưu "$word" vào Tools`
- **Tools / WordList** — `Đã lưu ${ui.uiText(typeLabel)}: $text`
- **Tools / WordList** — `ảnh`
- **Tools / WordList** — `ảnh minh họa`
- **Tools / WordList** — `✅ Đã tạo ${selWords.length + selPhrases.length} entry con`
- **Tools / WordList** — `🌱 "${entry.word}" đã được gieo trong vườn nhớ rồi!`
- **Tools / WordList** — `🌱 Đã gieo mầm "${entry.word}" vào vườn trí nhớ!`
- **Tools / WordList** — `📅 Lần tới: ${entry.daysUntilDue} ngày nữa`
- **Tools / WordList** — `📌 Gặp nhiều lần (${frequent.length})`
- **Translation** — `$base (cặp nguồn đã chọn)`
- **Translation** — `$base (nguồn tự nhận diện — kiểm tra lại ngôn ngữ nguồn)`
- **Translation** — `${language.flag} Đã đổi bản dịch và giọng đọc sang ${language.nativeName}`
- **Translation** — `${language.nativeName} • ngôn ngữ nguồn`
- **Translation** — `File Hy-MT $issue: $path — bấm "Tải về" để tải lại file đầy đủ hoặc chọn đúng model Hy-MT GGUF.`
- **Translation** — `Hy-MT không hỗ trợ cặp $sourceLang → $targetLang`
- **Translation** — `Hy-MT trả về rỗng cho segment ${chunkIndex + 1}/$chunkCount`
- **Translation** — `Isolate Hy-MT không còn sống: ${_deathError ?? `
- **Translation** — `Isolate Hy-MT đã chết: ${error == null ? `
- **Translation** — `Không có heartbeat trong ${_pingTimeout.inSeconds}s`
- **Translation** — `Không tải được Hy-MT (HTTP ${e.response?.statusCode ?? `
- **Translation** — `Lỗi ML Kit: $e`
- **Translation** — `Lỗi tải Hy-MT: $e`
- **Translation** — `Lỗi tải gói $code`
- **Translation** — `ML Kit không hỗ trợ cặp $source → $target`
- **Translation** — `Model Hy-MT tải về $issue`
- **Translation** — `Rate limited (429) tại $server`
- **Translation** — `Server $server yêu cầu API key`
- **Translation** — `Timeout ML Kit sau 30 giây`
- **Translation** — `Timeout sau 12 giây`
- **Translation** — `Tự nhận diện ${sourceLanguage.nativeName} → ${targetLanguage.nativeName}`
- **Translation** — `[đĐơƠưƯạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹýàáảãạèéẻẽẹ`
- **Translation** — `bị cắt ($mb MB; cần khoảng 601 MB)`
- **Translation** — `không đọc được file ($e)`
- **Translation** — `không đọc được file (${e.osError?.message ?? e.message})`
- **Translation** — `model trả rỗng cho segment ${chunkIndex + 1}/$chunkCount`
- **Translation** — `mất slot glossary $lost ở segment ${chunkIndex + 1}/$chunkCount`
- **Translation** — `việt`
- **Translation** — `}). Wi-Fi rồi thử lại.`
- **Translation** — `}. Thử "Tải về" lại model rồi dịch lại.`
- **Translation** — `ìíỉĩịòóỏõọùúủũụ]`
- **Translation** — `Đã nhận diện ${widget.sourceLanguage.flag} ${widget.sourceLanguage.nativeName} • ${AppLanguageCatalog.languages.length} ngôn ngữ đích`
- **Translation** — `Đã tải gói $code`
- **Translation** — `ℹ️ LLM API: chưa cấu hình provider cho dịch LLM (màn Server & API) hoặc routing "Dịch" đang "Chỉ offline" — bỏ qua lớp LLM, dùng engine khác. (thông báo này chỉ in 1 lần)`
- **Translation** — `🧩 Hỗn hợp ngôn ngữ · ${engines.join(`
- **Understand** — `Dừng (${_formatDuration(shadowing.recordingDuration)})`
- **Understand** — `Đếm: ${shadowing.countdown}`
- **Video library** — `Quyền đọc thư mục đã mất (do gỡ hoặc cập nhật app). Chạm "Chọn thư mục khác" để cấp lại quyền.`
- **Web Reader** — `$draftCount batch nháp`
- **Web Reader** — `$noteCount ghi chú`
- **Web Reader** — `$pinnedArticleCount bài ghim`
- **Web Reader** — `$resumeCount tiếp tục`
- **Web Reader** — `$selectedCount đã chọn`
- **Web Reader** — `$statusCount theo bộ lọc`
- **Web Reader** — `${_candidates.length} ứng viên`
- **Web Reader** — `${analyzed!.encounterCount} lần gặp`
- **Web Reader** — `${collection.linkCount} liên kết`
- **Web Reader** — `${currentCollection.linkCount} liên kết`
- **Web Reader** — `${diff.inDays} ngày trước`
- **Web Reader** — `${diff.inHours} giờ trước`
- **Web Reader** — `${diff.inMinutes} phút trước`
- **Web Reader** — `${draft.candidates.length} mục`
- **Web Reader** — `).length} dòng`
- **Web Reader** — `Batch nháp · ${draftBatches.length}`
- **Web Reader** — `Bài có ghi chú · ${notedArticles.length}`
- **Web Reader** — `Bài đã ghim · ${pinnedArticles.length}`
- **Web Reader** — `Bộ sưu tập có sẵn · ${presetCollections.length}`
- **Web Reader** — `Cập nhật ${context.uiText(_HistoryTile._formatVisitedAt(draft.updatedAt))}`
- **Web Reader** — `Ghi chú · ${_controller.pageTitle.isEmpty ? _controller.currentUrl : _controller.pageTitle}`
- **Web Reader** — `Ghi chú · ${entry.title.isEmpty ? entry.url : entry.title}`
- **Web Reader** — `Mới $_newCount`
- **Web Reader** — `Mới mở · ${context.uiText(_HistoryTile._formatVisitedAt(entry.effectiveReadAt))}`
- **Web Reader** — `Nhóm "${collection.title}" sẽ bị xoá, nhưng các preset mặc định và lịch sử duyệt sẽ không bị ảnh hưởng.`
- **Web Reader** — `Nhóm của tôi · ${userCollections.length}`
- **Web Reader** — `Nhập $_selectedCount mục vào WordList`
- **Web Reader** — `Nhập $_selectedReadyCount mục sẵn sàng`
- **Web Reader** — `Ready đã chọn: $_selectedReadyCount`
- **Web Reader** — `Sẵn sàng $_readyCount`
- **Web Reader** — `Thiếu: ${missing.join(`
- **Web Reader** — `Tiến độ ~ ${entry.progressPercent}%`
- **Web Reader** — `Tiếp tục đọc · ${resumeEntries.length}`
- **Web Reader** — `Trang này đã có sẵn trong nhóm "${collection.title}"`
- **Web Reader** — `Trang này đã có sẵn trong nhóm "${currentCollection.title}"`
- **Web Reader** — `Trích đoạn · $sourceLabel`
- **Web Reader** — `Trích đoạn · ${_controller.pageTitle.isEmpty ? _controller.currentUrl : _controller.pageTitle}`
- **Web Reader** — `Xem tất cả ${collection.linkCount} link`
- **Web Reader** — `Đang lọc: “$queryLabel”`
- **Web Reader** — `Đang đọc ${entry.progressPercent}%`
- **Web Reader** — `Đã chọn $_selectedCount`
- **Web Reader** — `Đã chọn: $_selectedCount`
- **Web Reader** — `Đã có $_existingCount`
- **Web Reader** — `Đã enrich $_enrichedCount`
- **Web Reader** — `Đã lưu nhanh · ${bookmarks.length}`
- **Web Reader** — `Đã lưu trang hiện tại vào nhóm "${currentCollection.title}"`
- **Web Reader** — `Đã phân loại $_selectedClassifiedCount / $_selectedCount`
- **Web Reader** — `Đã đánh giá $_classifiedCount`
- **Web Reader** — `Độ khó đã lưu: ${context.uiText(analyzed!.userDifficulty!.label)}`
- **Web Reader** — `Ưu tiên $_priorityCount`
- **Web Reader** — `✅ Đã load vào Text Studio — ${text.split(`
- **Web Reader** — `✅ Đã lưu "$cleanWord" vào Vườn Nhớ`
- **Web Reader** — `✅ Đã lưu vào nhóm "${collection.title}"`
- **Web Reader** — `📚 Đã bổ sung ngữ cảnh cho "$cleanWord" trong WordList`
- **Web Reader** — `📚 Đã thêm "$cleanWord" vào WordList`
- **Web Reader** — `🛠️ Đã áp dụng bulk fields cho ${targets.length} mục`
- **YouTube** — `$ext · ${kbps}kbps (chọn thủ công)`
- **YouTube** — `$v lượt xem`
- **YouTube** — `${(v / 1000).toStringAsFixed(0)}K lượt xem`
- **YouTube** — `${(v / 1000000).toStringAsFixed(1)}M lượt xem`
- **YouTube** — `${_captions.length} dòng`
- **YouTube** — `${d.inDays ~/ 365} năm trước`
- **YouTube** — `${d.inDays} ngày trước`
- **YouTube** — `Chuẩn bị · ${kbps}kbps · ${_sizeLabel(totalBytes)}`
- **YouTube** — `Không có captions cho "$_lang".
Thử ngôn ngữ khác.`
- **YouTube** — `Lấy captions ($_lang)`
- **YouTube** — `Lỗi tải phụ đề: $e`
- **YouTube** — `Tải thất bại: ${event.message}`
- **YouTube** — `YouTube từ chối phát video này (lỗi cấu hình trình phát, mã $code). Bấm Thử lại, hoặc Mở ngoài để xem trong trình duyệt.`
- **YouTube** — `yt-dlp lỗi: $e`
- **YouTube** — `Đã chờ ${_waitedSec}s. AI chạy trên máy nên có thể mất 30–90 giây.`
- **YouTube** — `Đã lưu phụ đề (${lines.length} dòng): ${path ?? "?"}`
- **YouTube** — `Đã lưu phụ đề vào: $folder`
- **YouTube** — `Đã tải xong (${event.quality})`
- **YouTube** — `✅ [in4up-yt] tải xong $received / $totalBytes bytes (số lần nối: $attempt)`
- **YouTube** — `❌ [in4up-yt] tải chưa hoàn tất: $got / $totalBytes bytes sau $_maxAttempts lần thử.`

### `hi`

- **AI Chat** — `⚡ ${usage.promptTokens} token vào · ${usage.completionTokens} token ra`
- **Cabin** — `App chưa hỗ trợ nhận diện offline cho $language — chọn Tiếng Việt/English hoặc dùng Engine "Hệ thống".`
- **Cabin** — `Cabin chỉ nhận diện $language khi model đã có trên máy. Thiếu model, app KHÔNG tự nhận $language bằng model ngôn ngữ khác.`
- **Cabin** — `Dịch: ${pref == HyMtOfflinePreference.hymt ? "Hy-MT" : pref == HyMtOfflinePreference.mlkit ? "ML Kit" : "Offline"}`
- **Cabin** — `Lỗi khởi động Sherpa STT: $e`
- **Cabin** — `Máy đang có $languageNote — cần bạn xác nhận mới dùng thay.`
- **Cabin** — `}.Máy có thể KHÔNG có sẵn dịch vụ Speech Recognition. Bạn có thể chuyển sang Engine "Offline (sherpa)" để nhận diện không cần dịch vụ hệ thống.`
- **Grammar / Understand** — `Không`
- **Grammar / Understand** — `Preset cá nhân gồm ${categories.length} nhóm từ loại được chọn thủ công.`
- **Grammar / Understand** — `Preset hiện tại: $activePresetName`
- **Grammar / Understand** — `^Preset cá nhân gồm \d+ nhóm từ loại được chọn thủ công\.$`
- **Grammar / Understand** — `Đang chỉnh tay từ preset gần nhất: $previousPresetName`
- **Grammar / Understand** — `Đang ẩn ${hiddenCategories.length} nhóm từ loại. Chúng chưa bị mất — bạn có thể bật lại từng nhóm, bật lại tất cả, hoặc quay về preset gần nhất $previousPresetName.`
- **Home** — `Speech recognition của hệ thống không khả dụng`
- **Learn by heart** — `$diff ngày`
- **Learn by heart** — `$value lần`
- **Learn by heart** — `${math.max(1, (base * 0.8).round())} ngày`
- **Learn by heart** — `${math.max(1, (s * 1.1).round())} ngày`
- **Learn by heart** — `${math.max(1, base)} ngày`
- **Learn by heart** — `${math.max(2, (base * 1.3).round())} ngày`
- **Learn by heart** — `${math.max(2, (s * 1.25).round())} ngày`
- **Learn by heart** — `${math.max(4, (s * 1.5).round())} ngày`
- **Learn by heart** — `1 ngày`
- **Learn by heart** — `Bản dịch (${RecitationLanguage.fromCode(_targetLang).displayName(`
- **Learn by heart** — `Bản dịch (${item.targetLanguage.displayName(`
- **Learn by heart** — `Chưa đặt tên`
- **Learn by heart** — `Chạm mở các từ ẩn để tự kiểm tra`
- **Learn by heart** — `Cần củng cố`
- **Learn by heart** — `Cẩn trọng trong từng suy nghĩ và lời nói hàng ngày.`
- **Learn by heart** — `Ghép đoạn (Chunk 1 → ${chunk.index})`
- **Learn by heart** — `Gần đúng`
- **Learn by heart** — `Hành động từ tâm ô nhiễm đem lại khổ đau.`
- **Learn by heart** — `Học ${chunk.label}`
- **Learn by heart** — `Học lại`
- **Learn by heart** — `Hợp nhất các đoạn đã học trước khi sang phần tiếp theo`
- **Learn by heart** — `Không được để trống`
- **Learn by heart** — `Kinh Pháp Cú`
- **Learn by heart** — `Kinh Tụng & Chân Ngôn`
- **Learn by heart** — `Kệ Ngôn & Thơ Thiền`
- **Learn by heart** — `Lắng nghe và đọc theo nhịp`
- **Learn by heart** — `Nguyên văn (${RecitationLanguage.fromCode(_sourceLang).displayName(`
- **Learn by heart** — `Nguyên văn (${item.sourceLanguage.displayName(`
- **Learn by heart** — `Rất tốt! Giữ vững tiến độ để đạt chuẩn thuộc lòng 100%.`
- **Learn by heart** — `Sai nhiều`
- **Learn by heart** — `Thử thách: ${chunk.label}`
- **Learn by heart** — `Tự Tạo & Ghi Chú`
- **Learn by heart** — `Ví dụ: Kệ Pháp Cú 01, Từ Bi Kinh...`
- **Learn by heart** — `Ví dụ: Tâm dẫn đầu các pháp...`
- **Learn by heart** — `Xuất sắc! Trí nhớ bền vững được tăng gấp đôi (2x FSRS Weight).`
- **Learn by heart** — `hôm nay`
- **Learn by heart** — `Ý dẫn đầu các pháp,
Ý làm chủ, ý tạo...`
- **Learn by heart** — `Ý dẫn đầu, Ý ô nhiễm, Khổ não`
- **Learn by heart** — `Đang ôn`
- **Learn by heart** — `Đã ghi nhận củng cố lại. FSRS sẽ đưa vào lịch ôn tập sớm.`
- **Learn by heart** — `Đúng hoàn toàn`
- **Learn by heart** — `Được`
- **Learn by heart** — `Đọc theo nhịp 2 dòng`
- **Learn by heart** — `Đọc trọn vẹn bài kinh và đánh giá chu kỳ ôn tập`
- **Learn by heart** — `✅ LHB sync (REST): kéo ${records.length} doc, áp dụng $applied thay đổi`
- **Learn by heart** — `✅ LHB sync (REST): đẩy ${ids.length} thay đổi`
- **Learn by heart** — `✅ LHB sync: kéo ${records.length} doc, áp dụng $applied thay đổi`
- **Learn by heart** — `✅ LHB sync: đẩy ${ids.length} thay đổi`
- **Listen** — `  Âm cần chú ý: ${word.phonemeIssues.join(`
- **Listen** — `Chưa có bản ghi nội dung (transcript).

Chạy "⚡ Tự tạo mục lục" (VAD + Whisper)
hoặc tạo LRC trong tab AI —
sau đó tìm chữ là nhảy tới đúng chỗ.`
- **Listen** — `Chưa có mục lục.
Nhấn "⚡ Tự tạo mục lục" phía trên để app
tự tách đoạn theo khoảng lặng (VAD)
và đặt tên chương (Whisper).

Hoặc nhấn "＋ Chương" để tạo thủ công
(tự neo vào vị trí đang nghe).`
- **Listen** — `Âm cần chú ý: ${word.phonemeIssues.join(`
- **Memory** — `${(stats.averageAccuracy * 100).round()}% chính xác`
- **Memory** — `${absDiff.inDays} ngày trước`
- **Memory** — `${absDiff.inHours} giờ trước`
- **Memory** — `${absDiff.inMinutes} phút trước`
- **Memory** — `${item.overdueHours.toStringAsFixed(1)}h trước`
- **Memory** — `${item.totalReviews}x ôn`
- **Memory** — `${stats.reviewedToday}/${stats.dueToday} hôm nay`
- **Memory** — `Chưa có từ nào ở giai đoạn "${context.uiText(stage.label)}"`
- **Memory** — `Xóa "${item.word}" khỏi vườn nhớ?
Dữ liệu ôn tập sẽ mất.`
- **Memory** — `sau ${diff.inDays} ngày`
- **Memory** — `sau ${diff.inHours} giờ`
- **Memory** — `Đã ôn ${stats.reviewedToday} từ
Đúng ${stats.correctToday}/${stats.reviewedToday}`
- **OCR** — `Dữ liệu ảnh ${pixels.length} byte không khớp ${width}x$height BGRA`
- **OCR** — `Không tìm thấy ảnh: $imagePath`
- **OCR** — `Lỗi nhận dạng chữ: $e`
- **Other** — `Chưa cấu hình GOOGLE_DESKTOP_CLIENT_SECRET.
Lấy secret từ Google Cloud Console và truyền qua --dart-define hoặc env.
Ví dụ: flutter run -d windows --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=GOCSPX-...`
- **Other** — `Chưa cấu hình Google Sign In cho Desktop.
Tạo OAuth client ID loại Desktop app trong Google Cloud Console > APIs & Services > Credentials.
Truyền qua --dart-define=GOOGLE_DESKTOP_CLIENT_ID=xxx --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=yyy hoặc đặt env var GOOGLE_DESKTOP_CLIENT_ID/SECRET.`
- **Other** — `Chương ${i + 1}`
- **Other** — `Không khởi tạo được Google Sign-In ($e). Khởi động lại app rồi thử lại.`
- **Other** — `Không lấy được ID token từ Google. Kiểm tra:
1. SHA-1/SHA-256 của BẢN ĐANG CÀI có trong Firebase Console chưa? (Project Settings > Your apps > SHA certificate fingerprints)
2. Google Sign-In provider đã bật trong Authentication > Sign-in method chưa?
3. serverClientId=$_webClientId có đúng Web client không?`
- **Other** — `Lỗi tải danh sách: $e`
- **Other** — `Lỗi đăng nhập: $e`
- **Other** — `cuộn ${(scrollProgressHint! * 100).round()}%`
- **Other** — `có`
- **Other** — `dòng ${lineIndex + 1}`
- **Other** — `dòng ${lineIndexHint! + 1}`
- **Other** — `không tách được đoạn theo khoảng lặng — file quá ngắn (< 2× độ dài đoạn tối thiểu) hoặc máy không đọc được waveform/thời lượng của file này. Thử: mở bài audio trong trình phát rồi chạy lại, hoặc giảm "đoạn tối thiểu" trong preset Tách nhiều.`
- **Other** — `Đang bóc băng qua API (whisper-large-v3)…
File dài sẽ tự chia chunk — có thể tắt mạng giữa chừng để dừng.`
- **Other** — `Đang nhận diện giọng nói (Whisper)…
File dài có thể mất vài phút.`
- **Other features** — ` (dòng ${context.focusLineIndex! + 1})`
- **Other features** — `${(compressionRatio * 100).round()}% độ dài nguồn`
- **Other features** — `${(copiedPhraseRatio * 100).round()}% cụm 3 từ trùng nguồn`
- **Other features** — `${(keywordPresenceRatio * 100).round()}% từ khóa quan sát được`
- **Other features** — `${shadowing.sessionResults.length} lần`
- **Other features** — `Cho mình MỘT gợi ý ngắn giúp hiểu tốt hơn đoạn này: chỉ gợi ý mở (từ khoá, cấu trúc cần chú ý), chưa giải thích trọn vẹn, để mình tự suy ra.`
- **Other features** — `Chưa có câu nào đang phát. Cho mình một gợi ý luyện tập tiếp theo phù hợp với chế độ mình đang chọn nhé.`
- **Other features** — `Câu mình đang hỏi$lineLabel:
`
- **Other features** — `File audio không tồn tại (existsSync false): $audioPath`
- **Other features** — `Giải thích câu trong dấu « » giúp mình: dịch nghĩa tiếng Việt, chỉ ra các từ/cụm từ khó và cấu trúc ngữ pháp đáng chú ý. Viết ngắn gọn, dễ hiểu.`
- **Other features** — `Hoàn tất! ${allSegments.length} segments trong ${totalSw.elapsed.inSeconds}s`
- **Other features** — `Kiểm tra hiểu bài của mình về đoạn vừa rồi: đặt 3 câu hỏi từ dễ đến khó, đợi mình tự trả lời, rồi mới đưa đáp án ngắn ở cuối.`
- **Other features** — `Mình đang học ở tab Hiểu (${parts.join(`
- **Other features** — `Tóm tắt đoạn trong « Đoạn vừa nghe » bằng 3–5 câu tiếng Việt: nêu ý chính và 3–5 từ vựng đáng nhớ kèm nghĩa ngắn.`
- **Other features** — `Tối đa: ${shadowing.settings.maxRecordDuration.inSeconds}s`
- **Other features** — `VAD lỗi: $e`
- **Other features** — `bài: « ${context.sourceTitle} »`
- **Other features** — `Đang bóc băng chunk ${i + 1}/$totalChunks...`
- **Other features** — `Đang cắt chunk ${i + 1}/$totalChunks (${seg.startTime.toStringAsFixed(1)}s->${seg.endTime.toStringAsFixed(1)}s)...`
- **Other features** — `Đang dịch $done/$total khối chữ…`
- **Other features** — `Đang quét VAD… ${(f * 100).toStringAsFixed(0)}%`
- **Other features** — `Đã tìm ${speechSegments.length} đoạn speech, bỏ $skipped đoạn silence`
- **Other features** — `ℹ️ screen translate: vùng chọn $requestedRegion quá bé/ngoài màn hình ⇒ dịch cả màn hình`
- **Other features** — `⚠️ Segment $i: không cắt được chunk (FFmpeg lỗi?) — bỏ qua THAY VÌ re-transcribe toàn bộ file gốc`
- **Other screens** — `"${entry.title}" sẽ bị xoá khỏi thư viện cloud.`
- **Other screens** — `${tp.lines.length} dòng`
- **Other screens** — `Cài từ điển có sẵn bằng một chạm (offline)`
- **Other screens** — `Đã cập nhật "${updated.title}" từ văn bản hiện tại`
- **Other screens** — `Đã cập nhật file cloud "${updatedEntry.title}"`
- **Other screens** — `Đã cập nhật trực tiếp file cloud "${updated.title}"`
- **Other screens** — `Đã lưu "${entry.title}" lên cloud`
- **PDF Reader** — `    <!-- không có highlight/ghi chú nào để xuất -->
`
- **PDF Reader** — `${annotations.length} ghi chú đã lưu`
- **PDF Reader** — `${controller.annotations.length} ghi chú`
- **PDF Reader** — `${entry.encounterCount} lần gặp`
- **PDF Reader** — `${entry.sourceFiles.length} nguồn`
- **PDF Reader** — `PDF đoạn chọn · ${_title.replaceAll(`
- **PDF Reader** — `aàáảãạăằắẳẵặâầấẩẫậ`
- **PDF Reader** — `dđ`
- **PDF Reader** — `eèéẻẽẹêềếểễệ`
- **PDF Reader** — `iìíỉĩị`
- **PDF Reader** — `oòóỏõọôồốổỗộơờớởỡợ`
- **PDF Reader** — `uùúủũụưừứửữự`
- **PDF Reader** — `yỳýỷỹỵ`
- **PDF Reader** — `✅ Đã load "$_title" vào Text Studio`
- **PDF Reader** — `✅ Đã lưu "$_displayWord" vào Vườn Nhớ`
- **Read** — ` : selectedText}" → Đã lưu nhanh`
- **Read** — `${sourceLanguage.translationCode}×3 chậm 0.75x`
- **Read** — `Bạn bỏ sót một số từ khóa quan trọng: ${result.missingWords.join(`
- **Read** — `Trên`
- **Read** — `Đáp án: ${_blankPrompts.map((e) => `
- **Settings** — `Ngôn ngữ: ${lang.isEmpty ? `
- **Settings** — `Xoá (${level.sizeInMB}MB)`
- **Settings** — `Xoá (${profile.approxSizeMB}MB)`
- **Shared widgets** — `$displayLabel chưa chắc`
- **Shared widgets** — `$displayLabel ổn`
- **Shared widgets** — `${_getRepeatCount(level)}x lặp`
- **Shared widgets** — `${_lines!.length} dòng · Nhấn để mở rộng`
- **Shared widgets** — `${diff.inDays} ngày`
- **Shared widgets** — `${diff.inHours}h trước`
- **Shared widgets** — `${widget.title} (${_lines!.length} dòng)`
- **Shared widgets** — `Ví dụ: ${word.example!.trim()}`
- **Shared widgets** — `Ôn tiếp sau ${word.daysUntilDue} ngày`
- **Shared widgets** — `Đang chờ... ${player.gapDuration.toStringAsFixed(1)}s`
- **Shared widgets** — `Đã lưu $relativeTime`
- **Shared widgets** — `Đã lưu: ${segment.title}`
- **Shared widgets** — `Đã phân loại $_classifiedCount / ${_candidates.length}`
- **TTS** — `"${provider.label}" lỗi: ${e.message}`
- **TTS** — `"${provider.label}" phản hồi quá chậm (timeout)`
- **TTS** — `"${provider.label}" đang rate-limit (429) — thử giảm tốc độ gọi`
- **TTS** — `${_friendlyError(e)} (đoạn ${i + 1}/${chunks.length})`
- **TTS** — `${_preview!.originalLineCount} dòng → ${_preview!.totalLines} dòng (~${_preview!.avgWordsPerLine.toStringAsFixed(1)} từ/dòng)`
- **TTS** — `API key sai/thiếu quyền tại "${provider.label}"`
- **TTS** — `Chưa có giọng Piper cho $language`
- **TTS** — `Dữ liệu trả về không phải audio hợp lệ: ${e.message}`
- **TTS** — `Edge TTS lỗi: $error`
- **TTS** — `Edge TTS từ chối kết nối WebSocket: ${error.message}`
- **TTS** — `Không có engine TTS nào phát được văn bản này ($lang).`
- **TTS** — `Không kết nối được "${provider.label}" (mất mạng/sai địa chỉ server)`
- **TTS** — `Không nạp được giọng Piper $name (thiếu espeak-ng-data?)`
- **TTS** — `Lỗi phát: $e`
- **TTS** — `Lỗi stream: $e`
- **TTS** — `Provider "${provider.label}" chưa chọn model TTS — cấu hình ở Server & API`
- **TTS** — `Provider "${provider.label}" thiếu baseUrl`
- **TTS** — `Tối thiểu $_minWords từ trước khi tách`
- **TTS** — `Tối đa $_maxWords từ/dòng`
- **TTS** — `Áp dụng (${_preview!.totalLines} dòng)`
- **Tipiṭaka** — `Tuyển tập chính văn ${orderIndex + 1}`
- **Tipiṭaka** — `diệu`
- **Tipiṭaka** — `luật`
- **Tools / WordList** — `"$documentTitle" — ${tp.lines.length} dòng`
- **Tools / WordList** — `$_correct / $_total đúng`
- **Tools / WordList** — `$pct% đã ôn tập`
- **Tools / WordList** — `$value ký tự`
- **Tools / WordList** — `${_selectedIds.length} đã chọn`
- **Tools / WordList** — `${provider.blindSpots} điểm mù`
- **Tools / WordList** — `${provider.masteredCount} thành thạo`
- **Tools / WordList** — `${w.sourceFiles.length} nguồn`
- **Tools / WordList** — `${widget.tools.where((t) => t.isAvailable).length} tính năng`
- **Tools / WordList** — `${words.length} từ tìm thấy · $selectedCount được chọn`
- **Tools / WordList** — `(${displayWords.length} từ)`
- **Tools / WordList** — `Chọn từ/cụm muốn lưu riêng từ "${parent.word}"`
- **Tools / WordList** — `Gặp lần $encounterCount!`
- **Tools / WordList** — `Import $count từ vào danh sách`
- **Tools / WordList** — `Không có từ nào cần ôn ${context.uiText(_skillName(_currentSkill!))}!`
- **Tools / WordList** — `Lưu ${selWords.length + selPhrases.length} mục`
- **Tools / WordList** — `Lưu từ: "$word"`
- **Tools / WordList** — `Lỗi đọc file: $e`
- **Tools / WordList** — `Ngữ cảnh (${entry.contexts.length})`
- **Tools / WordList** — `Thuần thục: ${(word.mastery * 100).toInt()}%`
- **Tools / WordList** — `Tất cả (${displayWords.length} từ)`
- **Tools / WordList** — `Tối thiểu $_minLength ký tự`
- **Tools / WordList** — `Ví dụ phức: ${data[`
- **Tools / WordList** — `Ví dụ đơn: ${data[`
- **Tools / WordList** — `Vòng ${_playbackService.listRepeatCurrent}/${_playbackService.listRepeatCount}`
- **Tools / WordList** — `Vòng ${_playbackService.listRepeatCurrent}/∞`
- **Tools / WordList** — `hình`
- **Tools / WordList** — `hình ảnh`
- **Tools / WordList** — `minh họa`
- **Tools / WordList** — `sai $wrong/${w.totalReviews} lần`
- **Tools / WordList** — `Ôn tập: ${context.uiText(_skillName(skill)).toUpperCase()}`
- **Tools / WordList** — `Đánh giá: ${context.uiText(_skillName(skill))}`
- **Tools / WordList** — `Đã lưu "$word" vào Tools`
- **Tools / WordList** — `Đã lưu ${ui.uiText(typeLabel)}: $text`
- **Tools / WordList** — `ảnh`
- **Tools / WordList** — `ảnh minh họa`
- **Tools / WordList** — `✅ Đã tạo ${selWords.length + selPhrases.length} entry con`
- **Tools / WordList** — `🌱 "${entry.word}" đã được gieo trong vườn nhớ rồi!`
- **Tools / WordList** — `🌱 Đã gieo mầm "${entry.word}" vào vườn trí nhớ!`
- **Tools / WordList** — `📅 Lần tới: ${entry.daysUntilDue} ngày nữa`
- **Tools / WordList** — `📌 Gặp nhiều lần (${frequent.length})`
- **Translation** — `$base (cặp nguồn đã chọn)`
- **Translation** — `$base (nguồn tự nhận diện — kiểm tra lại ngôn ngữ nguồn)`
- **Translation** — `${language.flag} Đã đổi bản dịch và giọng đọc sang ${language.nativeName}`
- **Translation** — `${language.nativeName} • ngôn ngữ nguồn`
- **Translation** — `Dưới`
- **Translation** — `File Hy-MT $issue: $path — bấm "Tải về" để tải lại file đầy đủ hoặc chọn đúng model Hy-MT GGUF.`
- **Translation** — `Hy-MT không hỗ trợ cặp $sourceLang → $targetLang`
- **Translation** — `Hy-MT trả về rỗng cho segment ${chunkIndex + 1}/$chunkCount`
- **Translation** — `Isolate Hy-MT không còn sống: ${_deathError ?? `
- **Translation** — `Isolate Hy-MT đã chết: ${error == null ? `
- **Translation** — `Không có heartbeat trong ${_pingTimeout.inSeconds}s`
- **Translation** — `Không tải được Hy-MT (HTTP ${e.response?.statusCode ?? `
- **Translation** — `Lỗi ML Kit: $e`
- **Translation** — `Lỗi tải Hy-MT: $e`
- **Translation** — `Lỗi tải gói $code`
- **Translation** — `ML Kit không hỗ trợ cặp $source → $target`
- **Translation** — `Model Hy-MT tải về $issue`
- **Translation** — `Rate limited (429) tại $server`
- **Translation** — `Server $server yêu cầu API key`
- **Translation** — `Timeout ML Kit sau 30 giây`
- **Translation** — `Timeout sau 12 giây`
- **Translation** — `Tự nhận diện ${sourceLanguage.nativeName} → ${targetLanguage.nativeName}`
- **Translation** — `[đĐơƠưƯạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹýàáảãạèéẻẽẹ`
- **Translation** — `bị cắt ($mb MB; cần khoảng 601 MB)`
- **Translation** — `không đọc được file ($e)`
- **Translation** — `không đọc được file (${e.osError?.message ?? e.message})`
- **Translation** — `model trả rỗng cho segment ${chunkIndex + 1}/$chunkCount`
- **Translation** — `mất slot glossary $lost ở segment ${chunkIndex + 1}/$chunkCount`
- **Translation** — `việt`
- **Translation** — `}). Wi-Fi rồi thử lại.`
- **Translation** — `}. Thử "Tải về" lại model rồi dịch lại.`
- **Translation** — `ìíỉĩịòóỏõọùúủũụ]`
- **Translation** — `Đã nhận diện ${widget.sourceLanguage.flag} ${widget.sourceLanguage.nativeName} • ${AppLanguageCatalog.languages.length} ngôn ngữ đích`
- **Translation** — `Đã tải gói $code`
- **Translation** — `ℹ️ LLM API: chưa cấu hình provider cho dịch LLM (màn Server & API) hoặc routing "Dịch" đang "Chỉ offline" — bỏ qua lớp LLM, dùng engine khác. (thông báo này chỉ in 1 lần)`
- **Translation** — `🧩 Hỗn hợp ngôn ngữ · ${engines.join(`
- **Understand** — `Dừng (${_formatDuration(shadowing.recordingDuration)})`
- **Understand** — `Đếm: ${shadowing.countdown}`
- **Video library** — `Quyền đọc thư mục đã mất (do gỡ hoặc cập nhật app). Chạm "Chọn thư mục khác" để cấp lại quyền.`
- **Web Reader** — `$draftCount batch nháp`
- **Web Reader** — `$noteCount ghi chú`
- **Web Reader** — `$pinnedArticleCount bài ghim`
- **Web Reader** — `$resumeCount tiếp tục`
- **Web Reader** — `$selectedCount đã chọn`
- **Web Reader** — `$statusCount theo bộ lọc`
- **Web Reader** — `${_candidates.length} ứng viên`
- **Web Reader** — `${analyzed!.encounterCount} lần gặp`
- **Web Reader** — `${collection.linkCount} liên kết`
- **Web Reader** — `${currentCollection.linkCount} liên kết`
- **Web Reader** — `${diff.inDays} ngày trước`
- **Web Reader** — `${diff.inHours} giờ trước`
- **Web Reader** — `${diff.inMinutes} phút trước`
- **Web Reader** — `${draft.candidates.length} mục`
- **Web Reader** — `).length} dòng`
- **Web Reader** — `Batch nháp · ${draftBatches.length}`
- **Web Reader** — `Bài có ghi chú · ${notedArticles.length}`
- **Web Reader** — `Bài đã ghim · ${pinnedArticles.length}`
- **Web Reader** — `Bộ sưu tập có sẵn · ${presetCollections.length}`
- **Web Reader** — `Cập nhật ${context.uiText(_HistoryTile._formatVisitedAt(draft.updatedAt))}`
- **Web Reader** — `Ghi chú · ${_controller.pageTitle.isEmpty ? _controller.currentUrl : _controller.pageTitle}`
- **Web Reader** — `Ghi chú · ${entry.title.isEmpty ? entry.url : entry.title}`
- **Web Reader** — `Mới $_newCount`
- **Web Reader** — `Mới mở · ${context.uiText(_HistoryTile._formatVisitedAt(entry.effectiveReadAt))}`
- **Web Reader** — `Nhóm "${collection.title}" sẽ bị xoá, nhưng các preset mặc định và lịch sử duyệt sẽ không bị ảnh hưởng.`
- **Web Reader** — `Nhóm của tôi · ${userCollections.length}`
- **Web Reader** — `Nhập $_selectedCount mục vào WordList`
- **Web Reader** — `Nhập $_selectedReadyCount mục sẵn sàng`
- **Web Reader** — `Ready đã chọn: $_selectedReadyCount`
- **Web Reader** — `Sẵn sàng $_readyCount`
- **Web Reader** — `Thiếu: ${missing.join(`
- **Web Reader** — `Tiến độ ~ ${entry.progressPercent}%`
- **Web Reader** — `Tiếp tục đọc · ${resumeEntries.length}`
- **Web Reader** — `Trang này đã có sẵn trong nhóm "${collection.title}"`
- **Web Reader** — `Trang này đã có sẵn trong nhóm "${currentCollection.title}"`
- **Web Reader** — `Trích đoạn · $sourceLabel`
- **Web Reader** — `Trích đoạn · ${_controller.pageTitle.isEmpty ? _controller.currentUrl : _controller.pageTitle}`
- **Web Reader** — `Xem tất cả ${collection.linkCount} link`
- **Web Reader** — `Đang lọc: “$queryLabel”`
- **Web Reader** — `Đang đọc ${entry.progressPercent}%`
- **Web Reader** — `Đã chọn $_selectedCount`
- **Web Reader** — `Đã chọn: $_selectedCount`
- **Web Reader** — `Đã có $_existingCount`
- **Web Reader** — `Đã enrich $_enrichedCount`
- **Web Reader** — `Đã lưu nhanh · ${bookmarks.length}`
- **Web Reader** — `Đã lưu trang hiện tại vào nhóm "${currentCollection.title}"`
- **Web Reader** — `Đã phân loại $_selectedClassifiedCount / $_selectedCount`
- **Web Reader** — `Đã đánh giá $_classifiedCount`
- **Web Reader** — `Độ khó đã lưu: ${context.uiText(analyzed!.userDifficulty!.label)}`
- **Web Reader** — `Ưu tiên $_priorityCount`
- **Web Reader** — `✅ Đã load vào Text Studio — ${text.split(`
- **Web Reader** — `✅ Đã lưu "$cleanWord" vào Vườn Nhớ`
- **Web Reader** — `✅ Đã lưu vào nhóm "${collection.title}"`
- **Web Reader** — `📚 Đã bổ sung ngữ cảnh cho "$cleanWord" trong WordList`
- **Web Reader** — `📚 Đã thêm "$cleanWord" vào WordList`
- **Web Reader** — `🛠️ Đã áp dụng bulk fields cho ${targets.length} mục`
- **YouTube** — `$ext · ${kbps}kbps (chọn thủ công)`
- **YouTube** — `$v lượt xem`
- **YouTube** — `${(v / 1000).toStringAsFixed(0)}K lượt xem`
- **YouTube** — `${(v / 1000000).toStringAsFixed(1)}M lượt xem`
- **YouTube** — `${_captions.length} dòng`
- **YouTube** — `${d.inDays ~/ 365} năm trước`
- **YouTube** — `${d.inDays} ngày trước`
- **YouTube** — `Chuẩn bị · ${kbps}kbps · ${_sizeLabel(totalBytes)}`
- **YouTube** — `Không có captions cho "$_lang".
Thử ngôn ngữ khác.`
- **YouTube** — `Lấy captions ($_lang)`
- **YouTube** — `Lỗi tải phụ đề: $e`
- **YouTube** — `Tải thất bại: ${event.message}`
- **YouTube** — `YouTube từ chối phát video này (lỗi cấu hình trình phát, mã $code). Bấm Thử lại, hoặc Mở ngoài để xem trong trình duyệt.`
- **YouTube** — `yt-dlp lỗi: $e`
- **YouTube** — `Đã chờ ${_waitedSec}s. AI chạy trên máy nên có thể mất 30–90 giây.`
- **YouTube** — `Đã lưu phụ đề (${lines.length} dòng): ${path ?? "?"}`
- **YouTube** — `Đã lưu phụ đề vào: $folder`
- **YouTube** — `Đã tải xong (${event.quality})`
- **YouTube** — `✅ [in4up-yt] tải xong $received / $totalBytes bytes (số lần nối: $attempt)`
- **YouTube** — `❌ [in4up-yt] tải chưa hoàn tất: $got / $totalBytes bytes sau $_maxAttempts lần thử.`

### `si`

- **AI Chat** — `⚡ ${usage.promptTokens} token vào · ${usage.completionTokens} token ra`
- **Cabin** — `App chưa hỗ trợ nhận diện offline cho $language — chọn Tiếng Việt/English hoặc dùng Engine "Hệ thống".`
- **Cabin** — `Cabin chỉ nhận diện $language khi model đã có trên máy. Thiếu model, app KHÔNG tự nhận $language bằng model ngôn ngữ khác.`
- **Cabin** — `Dịch: ${pref == HyMtOfflinePreference.hymt ? "Hy-MT" : pref == HyMtOfflinePreference.mlkit ? "ML Kit" : "Offline"}`
- **Cabin** — `Lỗi khởi động Sherpa STT: $e`
- **Cabin** — `Máy đang có $languageNote — cần bạn xác nhận mới dùng thay.`
- **Cabin** — `}.Máy có thể KHÔNG có sẵn dịch vụ Speech Recognition. Bạn có thể chuyển sang Engine "Offline (sherpa)" để nhận diện không cần dịch vụ hệ thống.`
- **Grammar / Understand** — `Không`
- **Grammar / Understand** — `Preset cá nhân gồm ${categories.length} nhóm từ loại được chọn thủ công.`
- **Grammar / Understand** — `Preset hiện tại: $activePresetName`
- **Grammar / Understand** — `^Preset cá nhân gồm \d+ nhóm từ loại được chọn thủ công\.$`
- **Grammar / Understand** — `Đang chỉnh tay từ preset gần nhất: $previousPresetName`
- **Grammar / Understand** — `Đang ẩn ${hiddenCategories.length} nhóm từ loại. Chúng chưa bị mất — bạn có thể bật lại từng nhóm, bật lại tất cả, hoặc quay về preset gần nhất $previousPresetName.`
- **Home** — `Speech recognition của hệ thống không khả dụng`
- **Learn by heart** — `$diff ngày`
- **Learn by heart** — `$value lần`
- **Learn by heart** — `${math.max(1, (base * 0.8).round())} ngày`
- **Learn by heart** — `${math.max(1, (s * 1.1).round())} ngày`
- **Learn by heart** — `${math.max(1, base)} ngày`
- **Learn by heart** — `${math.max(2, (base * 1.3).round())} ngày`
- **Learn by heart** — `${math.max(2, (s * 1.25).round())} ngày`
- **Learn by heart** — `${math.max(4, (s * 1.5).round())} ngày`
- **Learn by heart** — `1 ngày`
- **Learn by heart** — `Bản dịch (${RecitationLanguage.fromCode(_targetLang).displayName(`
- **Learn by heart** — `Bản dịch (${item.targetLanguage.displayName(`
- **Learn by heart** — `Chưa đặt tên`
- **Learn by heart** — `Chạm mở các từ ẩn để tự kiểm tra`
- **Learn by heart** — `Cần củng cố`
- **Learn by heart** — `Cẩn trọng trong từng suy nghĩ và lời nói hàng ngày.`
- **Learn by heart** — `Ghép đoạn (Chunk 1 → ${chunk.index})`
- **Learn by heart** — `Gần đúng`
- **Learn by heart** — `Hành động từ tâm ô nhiễm đem lại khổ đau.`
- **Learn by heart** — `Học ${chunk.label}`
- **Learn by heart** — `Học lại`
- **Learn by heart** — `Hợp nhất các đoạn đã học trước khi sang phần tiếp theo`
- **Learn by heart** — `Không được để trống`
- **Learn by heart** — `Kinh Pháp Cú`
- **Learn by heart** — `Kinh Tụng & Chân Ngôn`
- **Learn by heart** — `Kệ Ngôn & Thơ Thiền`
- **Learn by heart** — `Lắng nghe và đọc theo nhịp`
- **Learn by heart** — `Nguyên văn (${RecitationLanguage.fromCode(_sourceLang).displayName(`
- **Learn by heart** — `Nguyên văn (${item.sourceLanguage.displayName(`
- **Learn by heart** — `Rất tốt! Giữ vững tiến độ để đạt chuẩn thuộc lòng 100%.`
- **Learn by heart** — `Sai nhiều`
- **Learn by heart** — `Thử thách: ${chunk.label}`
- **Learn by heart** — `Tự Tạo & Ghi Chú`
- **Learn by heart** — `Ví dụ: Kệ Pháp Cú 01, Từ Bi Kinh...`
- **Learn by heart** — `Ví dụ: Tâm dẫn đầu các pháp...`
- **Learn by heart** — `Xuất sắc! Trí nhớ bền vững được tăng gấp đôi (2x FSRS Weight).`
- **Learn by heart** — `hôm nay`
- **Learn by heart** — `Ý dẫn đầu các pháp,
Ý làm chủ, ý tạo...`
- **Learn by heart** — `Ý dẫn đầu, Ý ô nhiễm, Khổ não`
- **Learn by heart** — `Đang ôn`
- **Learn by heart** — `Đã ghi nhận củng cố lại. FSRS sẽ đưa vào lịch ôn tập sớm.`
- **Learn by heart** — `Đúng hoàn toàn`
- **Learn by heart** — `Được`
- **Learn by heart** — `Đọc theo nhịp 2 dòng`
- **Learn by heart** — `Đọc trọn vẹn bài kinh và đánh giá chu kỳ ôn tập`
- **Learn by heart** — `✅ LHB sync (REST): kéo ${records.length} doc, áp dụng $applied thay đổi`
- **Learn by heart** — `✅ LHB sync (REST): đẩy ${ids.length} thay đổi`
- **Learn by heart** — `✅ LHB sync: kéo ${records.length} doc, áp dụng $applied thay đổi`
- **Learn by heart** — `✅ LHB sync: đẩy ${ids.length} thay đổi`
- **Listen** — `  Âm cần chú ý: ${word.phonemeIssues.join(`
- **Listen** — `Chưa có bản ghi nội dung (transcript).

Chạy "⚡ Tự tạo mục lục" (VAD + Whisper)
hoặc tạo LRC trong tab AI —
sau đó tìm chữ là nhảy tới đúng chỗ.`
- **Listen** — `Chưa có mục lục.
Nhấn "⚡ Tự tạo mục lục" phía trên để app
tự tách đoạn theo khoảng lặng (VAD)
và đặt tên chương (Whisper).

Hoặc nhấn "＋ Chương" để tạo thủ công
(tự neo vào vị trí đang nghe).`
- **Listen** — `Âm cần chú ý: ${word.phonemeIssues.join(`
- **Memory** — `${(stats.averageAccuracy * 100).round()}% chính xác`
- **Memory** — `${absDiff.inDays} ngày trước`
- **Memory** — `${absDiff.inHours} giờ trước`
- **Memory** — `${absDiff.inMinutes} phút trước`
- **Memory** — `${item.overdueHours.toStringAsFixed(1)}h trước`
- **Memory** — `${item.totalReviews}x ôn`
- **Memory** — `${stats.reviewedToday}/${stats.dueToday} hôm nay`
- **Memory** — `Chưa có từ nào ở giai đoạn "${context.uiText(stage.label)}"`
- **Memory** — `Xóa "${item.word}" khỏi vườn nhớ?
Dữ liệu ôn tập sẽ mất.`
- **Memory** — `sau ${diff.inDays} ngày`
- **Memory** — `sau ${diff.inHours} giờ`
- **Memory** — `Đã ôn ${stats.reviewedToday} từ
Đúng ${stats.correctToday}/${stats.reviewedToday}`
- **OCR** — `Dữ liệu ảnh ${pixels.length} byte không khớp ${width}x$height BGRA`
- **OCR** — `Không tìm thấy ảnh: $imagePath`
- **OCR** — `Lỗi nhận dạng chữ: $e`
- **Other** — `Chưa cấu hình GOOGLE_DESKTOP_CLIENT_SECRET.
Lấy secret từ Google Cloud Console và truyền qua --dart-define hoặc env.
Ví dụ: flutter run -d windows --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=GOCSPX-...`
- **Other** — `Chưa cấu hình Google Sign In cho Desktop.
Tạo OAuth client ID loại Desktop app trong Google Cloud Console > APIs & Services > Credentials.
Truyền qua --dart-define=GOOGLE_DESKTOP_CLIENT_ID=xxx --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=yyy hoặc đặt env var GOOGLE_DESKTOP_CLIENT_ID/SECRET.`
- **Other** — `Chương ${i + 1}`
- **Other** — `Không khởi tạo được Google Sign-In ($e). Khởi động lại app rồi thử lại.`
- **Other** — `Không lấy được ID token từ Google. Kiểm tra:
1. SHA-1/SHA-256 của BẢN ĐANG CÀI có trong Firebase Console chưa? (Project Settings > Your apps > SHA certificate fingerprints)
2. Google Sign-In provider đã bật trong Authentication > Sign-in method chưa?
3. serverClientId=$_webClientId có đúng Web client không?`
- **Other** — `Lỗi tải danh sách: $e`
- **Other** — `Lỗi đăng nhập: $e`
- **Other** — `cuộn ${(scrollProgressHint! * 100).round()}%`
- **Other** — `có`
- **Other** — `dòng ${lineIndex + 1}`
- **Other** — `dòng ${lineIndexHint! + 1}`
- **Other** — `không tách được đoạn theo khoảng lặng — file quá ngắn (< 2× độ dài đoạn tối thiểu) hoặc máy không đọc được waveform/thời lượng của file này. Thử: mở bài audio trong trình phát rồi chạy lại, hoặc giảm "đoạn tối thiểu" trong preset Tách nhiều.`
- **Other** — `Đang bóc băng qua API (whisper-large-v3)…
File dài sẽ tự chia chunk — có thể tắt mạng giữa chừng để dừng.`
- **Other** — `Đang nhận diện giọng nói (Whisper)…
File dài có thể mất vài phút.`
- **Other features** — ` (dòng ${context.focusLineIndex! + 1})`
- **Other features** — `${(compressionRatio * 100).round()}% độ dài nguồn`
- **Other features** — `${(copiedPhraseRatio * 100).round()}% cụm 3 từ trùng nguồn`
- **Other features** — `${(keywordPresenceRatio * 100).round()}% từ khóa quan sát được`
- **Other features** — `${shadowing.sessionResults.length} lần`
- **Other features** — `Cho mình MỘT gợi ý ngắn giúp hiểu tốt hơn đoạn này: chỉ gợi ý mở (từ khoá, cấu trúc cần chú ý), chưa giải thích trọn vẹn, để mình tự suy ra.`
- **Other features** — `Chưa có câu nào đang phát. Cho mình một gợi ý luyện tập tiếp theo phù hợp với chế độ mình đang chọn nhé.`
- **Other features** — `Câu mình đang hỏi$lineLabel:
`
- **Other features** — `File audio không tồn tại (existsSync false): $audioPath`
- **Other features** — `Giải thích câu trong dấu « » giúp mình: dịch nghĩa tiếng Việt, chỉ ra các từ/cụm từ khó và cấu trúc ngữ pháp đáng chú ý. Viết ngắn gọn, dễ hiểu.`
- **Other features** — `Hoàn tất! ${allSegments.length} segments trong ${totalSw.elapsed.inSeconds}s`
- **Other features** — `Kiểm tra hiểu bài của mình về đoạn vừa rồi: đặt 3 câu hỏi từ dễ đến khó, đợi mình tự trả lời, rồi mới đưa đáp án ngắn ở cuối.`
- **Other features** — `Mình đang học ở tab Hiểu (${parts.join(`
- **Other features** — `Tóm tắt đoạn trong « Đoạn vừa nghe » bằng 3–5 câu tiếng Việt: nêu ý chính và 3–5 từ vựng đáng nhớ kèm nghĩa ngắn.`
- **Other features** — `Tối đa: ${shadowing.settings.maxRecordDuration.inSeconds}s`
- **Other features** — `VAD lỗi: $e`
- **Other features** — `bài: « ${context.sourceTitle} »`
- **Other features** — `Đang bóc băng chunk ${i + 1}/$totalChunks...`
- **Other features** — `Đang cắt chunk ${i + 1}/$totalChunks (${seg.startTime.toStringAsFixed(1)}s->${seg.endTime.toStringAsFixed(1)}s)...`
- **Other features** — `Đang dịch $done/$total khối chữ…`
- **Other features** — `Đang quét VAD… ${(f * 100).toStringAsFixed(0)}%`
- **Other features** — `Đã tìm ${speechSegments.length} đoạn speech, bỏ $skipped đoạn silence`
- **Other features** — `ℹ️ screen translate: vùng chọn $requestedRegion quá bé/ngoài màn hình ⇒ dịch cả màn hình`
- **Other features** — `⚠️ Segment $i: không cắt được chunk (FFmpeg lỗi?) — bỏ qua THAY VÌ re-transcribe toàn bộ file gốc`
- **Other screens** — `"${entry.title}" sẽ bị xoá khỏi thư viện cloud.`
- **Other screens** — `${tp.lines.length} dòng`
- **Other screens** — `Cài từ điển có sẵn bằng một chạm (offline)`
- **Other screens** — `Đã cập nhật "${updated.title}" từ văn bản hiện tại`
- **Other screens** — `Đã cập nhật file cloud "${updatedEntry.title}"`
- **Other screens** — `Đã cập nhật trực tiếp file cloud "${updated.title}"`
- **Other screens** — `Đã lưu "${entry.title}" lên cloud`
- **PDF Reader** — `    <!-- không có highlight/ghi chú nào để xuất -->
`
- **PDF Reader** — `${annotations.length} ghi chú đã lưu`
- **PDF Reader** — `${controller.annotations.length} ghi chú`
- **PDF Reader** — `${entry.encounterCount} lần gặp`
- **PDF Reader** — `${entry.sourceFiles.length} nguồn`
- **PDF Reader** — `PDF đoạn chọn · ${_title.replaceAll(`
- **PDF Reader** — `aàáảãạăằắẳẵặâầấẩẫậ`
- **PDF Reader** — `dđ`
- **PDF Reader** — `eèéẻẽẹêềếểễệ`
- **PDF Reader** — `iìíỉĩị`
- **PDF Reader** — `oòóỏõọôồốổỗộơờớởỡợ`
- **PDF Reader** — `uùúủũụưừứửữự`
- **PDF Reader** — `yỳýỷỹỵ`
- **PDF Reader** — `✅ Đã load "$_title" vào Text Studio`
- **PDF Reader** — `✅ Đã lưu "$_displayWord" vào Vườn Nhớ`
- **Read** — ` : selectedText}" → Đã lưu nhanh`
- **Read** — `${sourceLanguage.translationCode}×3 chậm 0.75x`
- **Read** — `Bạn bỏ sót một số từ khóa quan trọng: ${result.missingWords.join(`
- **Read** — `Đáp án: ${_blankPrompts.map((e) => `
- **Settings** — `Ngôn ngữ: ${lang.isEmpty ? `
- **Settings** — `Xoá (${level.sizeInMB}MB)`
- **Settings** — `Xoá (${profile.approxSizeMB}MB)`
- **Shared widgets** — `$displayLabel chưa chắc`
- **Shared widgets** — `$displayLabel ổn`
- **Shared widgets** — `${_getRepeatCount(level)}x lặp`
- **Shared widgets** — `${_lines!.length} dòng · Nhấn để mở rộng`
- **Shared widgets** — `${diff.inDays} ngày`
- **Shared widgets** — `${diff.inHours}h trước`
- **Shared widgets** — `${widget.title} (${_lines!.length} dòng)`
- **Shared widgets** — `Ví dụ: ${word.example!.trim()}`
- **Shared widgets** — `Ôn tiếp sau ${word.daysUntilDue} ngày`
- **Shared widgets** — `Đang chờ... ${player.gapDuration.toStringAsFixed(1)}s`
- **Shared widgets** — `Đã lưu $relativeTime`
- **Shared widgets** — `Đã lưu: ${segment.title}`
- **Shared widgets** — `Đã phân loại $_classifiedCount / ${_candidates.length}`
- **TTS** — `"${provider.label}" lỗi: ${e.message}`
- **TTS** — `"${provider.label}" phản hồi quá chậm (timeout)`
- **TTS** — `"${provider.label}" đang rate-limit (429) — thử giảm tốc độ gọi`
- **TTS** — `${_friendlyError(e)} (đoạn ${i + 1}/${chunks.length})`
- **TTS** — `${_preview!.originalLineCount} dòng → ${_preview!.totalLines} dòng (~${_preview!.avgWordsPerLine.toStringAsFixed(1)} từ/dòng)`
- **TTS** — `API key sai/thiếu quyền tại "${provider.label}"`
- **TTS** — `Chưa có giọng Piper cho $language`
- **TTS** — `Dữ liệu trả về không phải audio hợp lệ: ${e.message}`
- **TTS** — `Edge TTS lỗi: $error`
- **TTS** — `Edge TTS từ chối kết nối WebSocket: ${error.message}`
- **TTS** — `Không có engine TTS nào phát được văn bản này ($lang).`
- **TTS** — `Không kết nối được "${provider.label}" (mất mạng/sai địa chỉ server)`
- **TTS** — `Không nạp được giọng Piper $name (thiếu espeak-ng-data?)`
- **TTS** — `Lỗi phát: $e`
- **TTS** — `Lỗi stream: $e`
- **TTS** — `Provider "${provider.label}" chưa chọn model TTS — cấu hình ở Server & API`
- **TTS** — `Provider "${provider.label}" thiếu baseUrl`
- **TTS** — `Tối thiểu $_minWords từ trước khi tách`
- **TTS** — `Tối đa $_maxWords từ/dòng`
- **TTS** — `Áp dụng (${_preview!.totalLines} dòng)`
- **Tipiṭaka** — `Tuyển tập chính văn ${orderIndex + 1}`
- **Tipiṭaka** — `diệu`
- **Tipiṭaka** — `luật`
- **Tools / WordList** — `"$documentTitle" — ${tp.lines.length} dòng`
- **Tools / WordList** — `$_correct / $_total đúng`
- **Tools / WordList** — `$pct% đã ôn tập`
- **Tools / WordList** — `$value ký tự`
- **Tools / WordList** — `${_selectedIds.length} đã chọn`
- **Tools / WordList** — `${provider.blindSpots} điểm mù`
- **Tools / WordList** — `${provider.masteredCount} thành thạo`
- **Tools / WordList** — `${w.sourceFiles.length} nguồn`
- **Tools / WordList** — `${widget.tools.where((t) => t.isAvailable).length} tính năng`
- **Tools / WordList** — `${words.length} từ tìm thấy · $selectedCount được chọn`
- **Tools / WordList** — `(${displayWords.length} từ)`
- **Tools / WordList** — `Chọn từ/cụm muốn lưu riêng từ "${parent.word}"`
- **Tools / WordList** — `Gặp lần $encounterCount!`
- **Tools / WordList** — `Import $count từ vào danh sách`
- **Tools / WordList** — `Không có từ nào cần ôn ${context.uiText(_skillName(_currentSkill!))}!`
- **Tools / WordList** — `Lưu ${selWords.length + selPhrases.length} mục`
- **Tools / WordList** — `Lưu từ: "$word"`
- **Tools / WordList** — `Lỗi đọc file: $e`
- **Tools / WordList** — `Ngữ cảnh (${entry.contexts.length})`
- **Tools / WordList** — `Thuần thục: ${(word.mastery * 100).toInt()}%`
- **Tools / WordList** — `Tất cả (${displayWords.length} từ)`
- **Tools / WordList** — `Tối thiểu $_minLength ký tự`
- **Tools / WordList** — `Ví dụ phức: ${data[`
- **Tools / WordList** — `Ví dụ đơn: ${data[`
- **Tools / WordList** — `Vòng ${_playbackService.listRepeatCurrent}/${_playbackService.listRepeatCount}`
- **Tools / WordList** — `Vòng ${_playbackService.listRepeatCurrent}/∞`
- **Tools / WordList** — `hình`
- **Tools / WordList** — `hình ảnh`
- **Tools / WordList** — `minh họa`
- **Tools / WordList** — `sai $wrong/${w.totalReviews} lần`
- **Tools / WordList** — `Ôn tập: ${context.uiText(_skillName(skill)).toUpperCase()}`
- **Tools / WordList** — `Đánh giá: ${context.uiText(_skillName(skill))}`
- **Tools / WordList** — `Đã lưu "$word" vào Tools`
- **Tools / WordList** — `Đã lưu ${ui.uiText(typeLabel)}: $text`
- **Tools / WordList** — `ảnh`
- **Tools / WordList** — `ảnh minh họa`
- **Tools / WordList** — `✅ Đã tạo ${selWords.length + selPhrases.length} entry con`
- **Tools / WordList** — `🌱 "${entry.word}" đã được gieo trong vườn nhớ rồi!`
- **Tools / WordList** — `🌱 Đã gieo mầm "${entry.word}" vào vườn trí nhớ!`
- **Tools / WordList** — `📅 Lần tới: ${entry.daysUntilDue} ngày nữa`
- **Tools / WordList** — `📌 Gặp nhiều lần (${frequent.length})`
- **Translation** — `$base (cặp nguồn đã chọn)`
- **Translation** — `$base (nguồn tự nhận diện — kiểm tra lại ngôn ngữ nguồn)`
- **Translation** — `${language.flag} Đã đổi bản dịch và giọng đọc sang ${language.nativeName}`
- **Translation** — `${language.nativeName} • ngôn ngữ nguồn`
- **Translation** — `File Hy-MT $issue: $path — bấm "Tải về" để tải lại file đầy đủ hoặc chọn đúng model Hy-MT GGUF.`
- **Translation** — `Hy-MT không hỗ trợ cặp $sourceLang → $targetLang`
- **Translation** — `Hy-MT trả về rỗng cho segment ${chunkIndex + 1}/$chunkCount`
- **Translation** — `Isolate Hy-MT không còn sống: ${_deathError ?? `
- **Translation** — `Isolate Hy-MT đã chết: ${error == null ? `
- **Translation** — `Không có heartbeat trong ${_pingTimeout.inSeconds}s`
- **Translation** — `Không tải được Hy-MT (HTTP ${e.response?.statusCode ?? `
- **Translation** — `Lỗi ML Kit: $e`
- **Translation** — `Lỗi tải Hy-MT: $e`
- **Translation** — `Lỗi tải gói $code`
- **Translation** — `ML Kit không hỗ trợ cặp $source → $target`
- **Translation** — `Model Hy-MT tải về $issue`
- **Translation** — `Rate limited (429) tại $server`
- **Translation** — `Server $server yêu cầu API key`
- **Translation** — `Timeout ML Kit sau 30 giây`
- **Translation** — `Timeout sau 12 giây`
- **Translation** — `Tự nhận diện ${sourceLanguage.nativeName} → ${targetLanguage.nativeName}`
- **Translation** — `[đĐơƠưƯạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹýàáảãạèéẻẽẹ`
- **Translation** — `bị cắt ($mb MB; cần khoảng 601 MB)`
- **Translation** — `không đọc được file ($e)`
- **Translation** — `không đọc được file (${e.osError?.message ?? e.message})`
- **Translation** — `model trả rỗng cho segment ${chunkIndex + 1}/$chunkCount`
- **Translation** — `mất slot glossary $lost ở segment ${chunkIndex + 1}/$chunkCount`
- **Translation** — `việt`
- **Translation** — `}). Wi-Fi rồi thử lại.`
- **Translation** — `}. Thử "Tải về" lại model rồi dịch lại.`
- **Translation** — `ìíỉĩịòóỏõọùúủũụ]`
- **Translation** — `Đã nhận diện ${widget.sourceLanguage.flag} ${widget.sourceLanguage.nativeName} • ${AppLanguageCatalog.languages.length} ngôn ngữ đích`
- **Translation** — `Đã tải gói $code`
- **Translation** — `ℹ️ LLM API: chưa cấu hình provider cho dịch LLM (màn Server & API) hoặc routing "Dịch" đang "Chỉ offline" — bỏ qua lớp LLM, dùng engine khác. (thông báo này chỉ in 1 lần)`
- **Translation** — `🧩 Hỗn hợp ngôn ngữ · ${engines.join(`
- **Understand** — `Dừng (${_formatDuration(shadowing.recordingDuration)})`
- **Understand** — `Đếm: ${shadowing.countdown}`
- **Video library** — `Quyền đọc thư mục đã mất (do gỡ hoặc cập nhật app). Chạm "Chọn thư mục khác" để cấp lại quyền.`
- **Web Reader** — `$draftCount batch nháp`
- **Web Reader** — `$noteCount ghi chú`
- **Web Reader** — `$pinnedArticleCount bài ghim`
- **Web Reader** — `$resumeCount tiếp tục`
- **Web Reader** — `$selectedCount đã chọn`
- **Web Reader** — `$statusCount theo bộ lọc`
- **Web Reader** — `${_candidates.length} ứng viên`
- **Web Reader** — `${analyzed!.encounterCount} lần gặp`
- **Web Reader** — `${collection.linkCount} liên kết`
- **Web Reader** — `${currentCollection.linkCount} liên kết`
- **Web Reader** — `${diff.inDays} ngày trước`
- **Web Reader** — `${diff.inHours} giờ trước`
- **Web Reader** — `${diff.inMinutes} phút trước`
- **Web Reader** — `${draft.candidates.length} mục`
- **Web Reader** — `).length} dòng`
- **Web Reader** — `Batch nháp · ${draftBatches.length}`
- **Web Reader** — `Bài có ghi chú · ${notedArticles.length}`
- **Web Reader** — `Bài đã ghim · ${pinnedArticles.length}`
- **Web Reader** — `Bộ sưu tập có sẵn · ${presetCollections.length}`
- **Web Reader** — `Cập nhật ${context.uiText(_HistoryTile._formatVisitedAt(draft.updatedAt))}`
- **Web Reader** — `Ghi chú · ${_controller.pageTitle.isEmpty ? _controller.currentUrl : _controller.pageTitle}`
- **Web Reader** — `Ghi chú · ${entry.title.isEmpty ? entry.url : entry.title}`
- **Web Reader** — `Mới $_newCount`
- **Web Reader** — `Mới mở · ${context.uiText(_HistoryTile._formatVisitedAt(entry.effectiveReadAt))}`
- **Web Reader** — `Nhóm "${collection.title}" sẽ bị xoá, nhưng các preset mặc định và lịch sử duyệt sẽ không bị ảnh hưởng.`
- **Web Reader** — `Nhóm của tôi · ${userCollections.length}`
- **Web Reader** — `Nhập $_selectedCount mục vào WordList`
- **Web Reader** — `Nhập $_selectedReadyCount mục sẵn sàng`
- **Web Reader** — `Ready đã chọn: $_selectedReadyCount`
- **Web Reader** — `Sẵn sàng $_readyCount`
- **Web Reader** — `Thiếu: ${missing.join(`
- **Web Reader** — `Tiến độ ~ ${entry.progressPercent}%`
- **Web Reader** — `Tiếp tục đọc · ${resumeEntries.length}`
- **Web Reader** — `Trang này đã có sẵn trong nhóm "${collection.title}"`
- **Web Reader** — `Trang này đã có sẵn trong nhóm "${currentCollection.title}"`
- **Web Reader** — `Trích đoạn · $sourceLabel`
- **Web Reader** — `Trích đoạn · ${_controller.pageTitle.isEmpty ? _controller.currentUrl : _controller.pageTitle}`
- **Web Reader** — `Xem tất cả ${collection.linkCount} link`
- **Web Reader** — `Đang lọc: “$queryLabel”`
- **Web Reader** — `Đang đọc ${entry.progressPercent}%`
- **Web Reader** — `Đã chọn $_selectedCount`
- **Web Reader** — `Đã chọn: $_selectedCount`
- **Web Reader** — `Đã có $_existingCount`
- **Web Reader** — `Đã enrich $_enrichedCount`
- **Web Reader** — `Đã lưu nhanh · ${bookmarks.length}`
- **Web Reader** — `Đã lưu trang hiện tại vào nhóm "${currentCollection.title}"`
- **Web Reader** — `Đã phân loại $_selectedClassifiedCount / $_selectedCount`
- **Web Reader** — `Đã đánh giá $_classifiedCount`
- **Web Reader** — `Độ khó đã lưu: ${context.uiText(analyzed!.userDifficulty!.label)}`
- **Web Reader** — `Ưu tiên $_priorityCount`
- **Web Reader** — `✅ Đã load vào Text Studio — ${text.split(`
- **Web Reader** — `✅ Đã lưu "$cleanWord" vào Vườn Nhớ`
- **Web Reader** — `✅ Đã lưu vào nhóm "${collection.title}"`
- **Web Reader** — `📚 Đã bổ sung ngữ cảnh cho "$cleanWord" trong WordList`
- **Web Reader** — `📚 Đã thêm "$cleanWord" vào WordList`
- **Web Reader** — `🛠️ Đã áp dụng bulk fields cho ${targets.length} mục`
- **YouTube** — `$ext · ${kbps}kbps (chọn thủ công)`
- **YouTube** — `$v lượt xem`
- **YouTube** — `${(v / 1000).toStringAsFixed(0)}K lượt xem`
- **YouTube** — `${(v / 1000000).toStringAsFixed(1)}M lượt xem`
- **YouTube** — `${_captions.length} dòng`
- **YouTube** — `${d.inDays ~/ 365} năm trước`
- **YouTube** — `${d.inDays} ngày trước`
- **YouTube** — `Chuẩn bị · ${kbps}kbps · ${_sizeLabel(totalBytes)}`
- **YouTube** — `Không có captions cho "$_lang".
Thử ngôn ngữ khác.`
- **YouTube** — `Lấy captions ($_lang)`
- **YouTube** — `Lỗi tải phụ đề: $e`
- **YouTube** — `Tải thất bại: ${event.message}`
- **YouTube** — `YouTube từ chối phát video này (lỗi cấu hình trình phát, mã $code). Bấm Thử lại, hoặc Mở ngoài để xem trong trình duyệt.`
- **YouTube** — `yt-dlp lỗi: $e`
- **YouTube** — `Đã chờ ${_waitedSec}s. AI chạy trên máy nên có thể mất 30–90 giây.`
- **YouTube** — `Đã lưu phụ đề (${lines.length} dòng): ${path ?? "?"}`
- **YouTube** — `Đã lưu phụ đề vào: $folder`
- **YouTube** — `Đã tải xong (${event.quality})`
- **YouTube** — `✅ [in4up-yt] tải xong $received / $totalBytes bytes (số lần nối: $attempt)`
- **YouTube** — `❌ [in4up-yt] tải chưa hoàn tất: $got / $totalBytes bytes sau $_maxAttempts lần thử.`

### `my`

- **AI Chat** — `⚡ ${usage.promptTokens} token vào · ${usage.completionTokens} token ra`
- **Cabin** — `App chưa hỗ trợ nhận diện offline cho $language — chọn Tiếng Việt/English hoặc dùng Engine "Hệ thống".`
- **Cabin** — `Cabin chỉ nhận diện $language khi model đã có trên máy. Thiếu model, app KHÔNG tự nhận $language bằng model ngôn ngữ khác.`
- **Cabin** — `Dịch: ${pref == HyMtOfflinePreference.hymt ? "Hy-MT" : pref == HyMtOfflinePreference.mlkit ? "ML Kit" : "Offline"}`
- **Cabin** — `Lỗi khởi động Sherpa STT: $e`
- **Cabin** — `Máy đang có $languageNote — cần bạn xác nhận mới dùng thay.`
- **Cabin** — `}.Máy có thể KHÔNG có sẵn dịch vụ Speech Recognition. Bạn có thể chuyển sang Engine "Offline (sherpa)" để nhận diện không cần dịch vụ hệ thống.`
- **Grammar / Understand** — `Không`
- **Grammar / Understand** — `Preset cá nhân gồm ${categories.length} nhóm từ loại được chọn thủ công.`
- **Grammar / Understand** — `Preset hiện tại: $activePresetName`
- **Grammar / Understand** — `^Preset cá nhân gồm \d+ nhóm từ loại được chọn thủ công\.$`
- **Grammar / Understand** — `Đang chỉnh tay từ preset gần nhất: $previousPresetName`
- **Grammar / Understand** — `Đang ẩn ${hiddenCategories.length} nhóm từ loại. Chúng chưa bị mất — bạn có thể bật lại từng nhóm, bật lại tất cả, hoặc quay về preset gần nhất $previousPresetName.`
- **Home** — `Speech recognition của hệ thống không khả dụng`
- **Learn by heart** — `$diff ngày`
- **Learn by heart** — `$value lần`
- **Learn by heart** — `${math.max(1, (base * 0.8).round())} ngày`
- **Learn by heart** — `${math.max(1, (s * 1.1).round())} ngày`
- **Learn by heart** — `${math.max(1, base)} ngày`
- **Learn by heart** — `${math.max(2, (base * 1.3).round())} ngày`
- **Learn by heart** — `${math.max(2, (s * 1.25).round())} ngày`
- **Learn by heart** — `${math.max(4, (s * 1.5).round())} ngày`
- **Learn by heart** — `1 ngày`
- **Learn by heart** — `Bản dịch (${RecitationLanguage.fromCode(_targetLang).displayName(`
- **Learn by heart** — `Bản dịch (${item.targetLanguage.displayName(`
- **Learn by heart** — `Chưa đặt tên`
- **Learn by heart** — `Chạm mở các từ ẩn để tự kiểm tra`
- **Learn by heart** — `Cần củng cố`
- **Learn by heart** — `Cẩn trọng trong từng suy nghĩ và lời nói hàng ngày.`
- **Learn by heart** — `Ghép đoạn (Chunk 1 → ${chunk.index})`
- **Learn by heart** — `Gần đúng`
- **Learn by heart** — `Hành động từ tâm ô nhiễm đem lại khổ đau.`
- **Learn by heart** — `Học ${chunk.label}`
- **Learn by heart** — `Học lại`
- **Learn by heart** — `Hợp nhất các đoạn đã học trước khi sang phần tiếp theo`
- **Learn by heart** — `Không được để trống`
- **Learn by heart** — `Kinh Pháp Cú`
- **Learn by heart** — `Kinh Tụng & Chân Ngôn`
- **Learn by heart** — `Kệ Ngôn & Thơ Thiền`
- **Learn by heart** — `Lắng nghe và đọc theo nhịp`
- **Learn by heart** — `Nguyên văn (${RecitationLanguage.fromCode(_sourceLang).displayName(`
- **Learn by heart** — `Nguyên văn (${item.sourceLanguage.displayName(`
- **Learn by heart** — `Rất tốt! Giữ vững tiến độ để đạt chuẩn thuộc lòng 100%.`
- **Learn by heart** — `Sai nhiều`
- **Learn by heart** — `Thử thách: ${chunk.label}`
- **Learn by heart** — `Tự Tạo & Ghi Chú`
- **Learn by heart** — `Ví dụ: Kệ Pháp Cú 01, Từ Bi Kinh...`
- **Learn by heart** — `Ví dụ: Tâm dẫn đầu các pháp...`
- **Learn by heart** — `Xuất sắc! Trí nhớ bền vững được tăng gấp đôi (2x FSRS Weight).`
- **Learn by heart** — `hôm nay`
- **Learn by heart** — `Ý dẫn đầu các pháp,
Ý làm chủ, ý tạo...`
- **Learn by heart** — `Ý dẫn đầu, Ý ô nhiễm, Khổ não`
- **Learn by heart** — `Đang ôn`
- **Learn by heart** — `Đã ghi nhận củng cố lại. FSRS sẽ đưa vào lịch ôn tập sớm.`
- **Learn by heart** — `Đúng hoàn toàn`
- **Learn by heart** — `Được`
- **Learn by heart** — `Đọc theo nhịp 2 dòng`
- **Learn by heart** — `Đọc trọn vẹn bài kinh và đánh giá chu kỳ ôn tập`
- **Learn by heart** — `✅ LHB sync (REST): kéo ${records.length} doc, áp dụng $applied thay đổi`
- **Learn by heart** — `✅ LHB sync (REST): đẩy ${ids.length} thay đổi`
- **Learn by heart** — `✅ LHB sync: kéo ${records.length} doc, áp dụng $applied thay đổi`
- **Learn by heart** — `✅ LHB sync: đẩy ${ids.length} thay đổi`
- **Listen** — `  Âm cần chú ý: ${word.phonemeIssues.join(`
- **Listen** — `Chưa có bản ghi nội dung (transcript).

Chạy "⚡ Tự tạo mục lục" (VAD + Whisper)
hoặc tạo LRC trong tab AI —
sau đó tìm chữ là nhảy tới đúng chỗ.`
- **Listen** — `Chưa có mục lục.
Nhấn "⚡ Tự tạo mục lục" phía trên để app
tự tách đoạn theo khoảng lặng (VAD)
và đặt tên chương (Whisper).

Hoặc nhấn "＋ Chương" để tạo thủ công
(tự neo vào vị trí đang nghe).`
- **Listen** — `Âm cần chú ý: ${word.phonemeIssues.join(`
- **Memory** — `${(stats.averageAccuracy * 100).round()}% chính xác`
- **Memory** — `${absDiff.inDays} ngày trước`
- **Memory** — `${absDiff.inHours} giờ trước`
- **Memory** — `${absDiff.inMinutes} phút trước`
- **Memory** — `${item.overdueHours.toStringAsFixed(1)}h trước`
- **Memory** — `${item.totalReviews}x ôn`
- **Memory** — `${stats.reviewedToday}/${stats.dueToday} hôm nay`
- **Memory** — `Chưa có từ nào ở giai đoạn "${context.uiText(stage.label)}"`
- **Memory** — `Xóa "${item.word}" khỏi vườn nhớ?
Dữ liệu ôn tập sẽ mất.`
- **Memory** — `sau ${diff.inDays} ngày`
- **Memory** — `sau ${diff.inHours} giờ`
- **Memory** — `Đã ôn ${stats.reviewedToday} từ
Đúng ${stats.correctToday}/${stats.reviewedToday}`
- **OCR** — `Dữ liệu ảnh ${pixels.length} byte không khớp ${width}x$height BGRA`
- **OCR** — `Không tìm thấy ảnh: $imagePath`
- **OCR** — `Lỗi nhận dạng chữ: $e`
- **Other** — `Chưa cấu hình GOOGLE_DESKTOP_CLIENT_SECRET.
Lấy secret từ Google Cloud Console và truyền qua --dart-define hoặc env.
Ví dụ: flutter run -d windows --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=GOCSPX-...`
- **Other** — `Chưa cấu hình Google Sign In cho Desktop.
Tạo OAuth client ID loại Desktop app trong Google Cloud Console > APIs & Services > Credentials.
Truyền qua --dart-define=GOOGLE_DESKTOP_CLIENT_ID=xxx --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=yyy hoặc đặt env var GOOGLE_DESKTOP_CLIENT_ID/SECRET.`
- **Other** — `Chương ${i + 1}`
- **Other** — `Không khởi tạo được Google Sign-In ($e). Khởi động lại app rồi thử lại.`
- **Other** — `Không lấy được ID token từ Google. Kiểm tra:
1. SHA-1/SHA-256 của BẢN ĐANG CÀI có trong Firebase Console chưa? (Project Settings > Your apps > SHA certificate fingerprints)
2. Google Sign-In provider đã bật trong Authentication > Sign-in method chưa?
3. serverClientId=$_webClientId có đúng Web client không?`
- **Other** — `Lỗi tải danh sách: $e`
- **Other** — `Lỗi đăng nhập: $e`
- **Other** — `cuộn ${(scrollProgressHint! * 100).round()}%`
- **Other** — `có`
- **Other** — `dòng ${lineIndex + 1}`
- **Other** — `dòng ${lineIndexHint! + 1}`
- **Other** — `không tách được đoạn theo khoảng lặng — file quá ngắn (< 2× độ dài đoạn tối thiểu) hoặc máy không đọc được waveform/thời lượng của file này. Thử: mở bài audio trong trình phát rồi chạy lại, hoặc giảm "đoạn tối thiểu" trong preset Tách nhiều.`
- **Other** — `Đang bóc băng qua API (whisper-large-v3)…
File dài sẽ tự chia chunk — có thể tắt mạng giữa chừng để dừng.`
- **Other** — `Đang nhận diện giọng nói (Whisper)…
File dài có thể mất vài phút.`
- **Other features** — ` (dòng ${context.focusLineIndex! + 1})`
- **Other features** — `${(compressionRatio * 100).round()}% độ dài nguồn`
- **Other features** — `${(copiedPhraseRatio * 100).round()}% cụm 3 từ trùng nguồn`
- **Other features** — `${(keywordPresenceRatio * 100).round()}% từ khóa quan sát được`
- **Other features** — `${shadowing.sessionResults.length} lần`
- **Other features** — `Cho mình MỘT gợi ý ngắn giúp hiểu tốt hơn đoạn này: chỉ gợi ý mở (từ khoá, cấu trúc cần chú ý), chưa giải thích trọn vẹn, để mình tự suy ra.`
- **Other features** — `Chưa có câu nào đang phát. Cho mình một gợi ý luyện tập tiếp theo phù hợp với chế độ mình đang chọn nhé.`
- **Other features** — `Câu mình đang hỏi$lineLabel:
`
- **Other features** — `File audio không tồn tại (existsSync false): $audioPath`
- **Other features** — `Giải thích câu trong dấu « » giúp mình: dịch nghĩa tiếng Việt, chỉ ra các từ/cụm từ khó và cấu trúc ngữ pháp đáng chú ý. Viết ngắn gọn, dễ hiểu.`
- **Other features** — `Hoàn tất! ${allSegments.length} segments trong ${totalSw.elapsed.inSeconds}s`
- **Other features** — `Kiểm tra hiểu bài của mình về đoạn vừa rồi: đặt 3 câu hỏi từ dễ đến khó, đợi mình tự trả lời, rồi mới đưa đáp án ngắn ở cuối.`
- **Other features** — `Mình đang học ở tab Hiểu (${parts.join(`
- **Other features** — `Tóm tắt đoạn trong « Đoạn vừa nghe » bằng 3–5 câu tiếng Việt: nêu ý chính và 3–5 từ vựng đáng nhớ kèm nghĩa ngắn.`
- **Other features** — `Tối đa: ${shadowing.settings.maxRecordDuration.inSeconds}s`
- **Other features** — `VAD lỗi: $e`
- **Other features** — `bài: « ${context.sourceTitle} »`
- **Other features** — `Đang bóc băng chunk ${i + 1}/$totalChunks...`
- **Other features** — `Đang cắt chunk ${i + 1}/$totalChunks (${seg.startTime.toStringAsFixed(1)}s->${seg.endTime.toStringAsFixed(1)}s)...`
- **Other features** — `Đang dịch $done/$total khối chữ…`
- **Other features** — `Đang quét VAD… ${(f * 100).toStringAsFixed(0)}%`
- **Other features** — `Đã tìm ${speechSegments.length} đoạn speech, bỏ $skipped đoạn silence`
- **Other features** — `ℹ️ screen translate: vùng chọn $requestedRegion quá bé/ngoài màn hình ⇒ dịch cả màn hình`
- **Other features** — `⚠️ Segment $i: không cắt được chunk (FFmpeg lỗi?) — bỏ qua THAY VÌ re-transcribe toàn bộ file gốc`
- **Other screens** — `"${entry.title}" sẽ bị xoá khỏi thư viện cloud.`
- **Other screens** — `${tp.lines.length} dòng`
- **Other screens** — `Cài từ điển có sẵn bằng một chạm (offline)`
- **Other screens** — `Đã cập nhật "${updated.title}" từ văn bản hiện tại`
- **Other screens** — `Đã cập nhật file cloud "${updatedEntry.title}"`
- **Other screens** — `Đã cập nhật trực tiếp file cloud "${updated.title}"`
- **Other screens** — `Đã lưu "${entry.title}" lên cloud`
- **PDF Reader** — `    <!-- không có highlight/ghi chú nào để xuất -->
`
- **PDF Reader** — `${annotations.length} ghi chú đã lưu`
- **PDF Reader** — `${controller.annotations.length} ghi chú`
- **PDF Reader** — `${entry.encounterCount} lần gặp`
- **PDF Reader** — `${entry.sourceFiles.length} nguồn`
- **PDF Reader** — `PDF đoạn chọn · ${_title.replaceAll(`
- **PDF Reader** — `aàáảãạăằắẳẵặâầấẩẫậ`
- **PDF Reader** — `dđ`
- **PDF Reader** — `eèéẻẽẹêềếểễệ`
- **PDF Reader** — `iìíỉĩị`
- **PDF Reader** — `oòóỏõọôồốổỗộơờớởỡợ`
- **PDF Reader** — `uùúủũụưừứửữự`
- **PDF Reader** — `yỳýỷỹỵ`
- **PDF Reader** — `✅ Đã load "$_title" vào Text Studio`
- **PDF Reader** — `✅ Đã lưu "$_displayWord" vào Vườn Nhớ`
- **Read** — ` : selectedText}" → Đã lưu nhanh`
- **Read** — `${sourceLanguage.translationCode}×3 chậm 0.75x`
- **Read** — `Bạn bỏ sót một số từ khóa quan trọng: ${result.missingWords.join(`
- **Read** — `Đáp án: ${_blankPrompts.map((e) => `
- **Settings** — `Ngôn ngữ: ${lang.isEmpty ? `
- **Settings** — `Xoá (${level.sizeInMB}MB)`
- **Settings** — `Xoá (${profile.approxSizeMB}MB)`
- **Shared widgets** — `$displayLabel chưa chắc`
- **Shared widgets** — `$displayLabel ổn`
- **Shared widgets** — `${_getRepeatCount(level)}x lặp`
- **Shared widgets** — `${_lines!.length} dòng · Nhấn để mở rộng`
- **Shared widgets** — `${diff.inDays} ngày`
- **Shared widgets** — `${diff.inHours}h trước`
- **Shared widgets** — `${widget.title} (${_lines!.length} dòng)`
- **Shared widgets** — `Ví dụ: ${word.example!.trim()}`
- **Shared widgets** — `Ôn tiếp sau ${word.daysUntilDue} ngày`
- **Shared widgets** — `Đang chờ... ${player.gapDuration.toStringAsFixed(1)}s`
- **Shared widgets** — `Đã lưu $relativeTime`
- **Shared widgets** — `Đã lưu: ${segment.title}`
- **Shared widgets** — `Đã phân loại $_classifiedCount / ${_candidates.length}`
- **TTS** — `"${provider.label}" lỗi: ${e.message}`
- **TTS** — `"${provider.label}" phản hồi quá chậm (timeout)`
- **TTS** — `"${provider.label}" đang rate-limit (429) — thử giảm tốc độ gọi`
- **TTS** — `${_friendlyError(e)} (đoạn ${i + 1}/${chunks.length})`
- **TTS** — `${_preview!.originalLineCount} dòng → ${_preview!.totalLines} dòng (~${_preview!.avgWordsPerLine.toStringAsFixed(1)} từ/dòng)`
- **TTS** — `API key sai/thiếu quyền tại "${provider.label}"`
- **TTS** — `Chưa có giọng Piper cho $language`
- **TTS** — `Dữ liệu trả về không phải audio hợp lệ: ${e.message}`
- **TTS** — `Edge TTS lỗi: $error`
- **TTS** — `Edge TTS từ chối kết nối WebSocket: ${error.message}`
- **TTS** — `Không có engine TTS nào phát được văn bản này ($lang).`
- **TTS** — `Không kết nối được "${provider.label}" (mất mạng/sai địa chỉ server)`
- **TTS** — `Không nạp được giọng Piper $name (thiếu espeak-ng-data?)`
- **TTS** — `Lỗi phát: $e`
- **TTS** — `Lỗi stream: $e`
- **TTS** — `Provider "${provider.label}" chưa chọn model TTS — cấu hình ở Server & API`
- **TTS** — `Provider "${provider.label}" thiếu baseUrl`
- **TTS** — `Tối thiểu $_minWords từ trước khi tách`
- **TTS** — `Tối đa $_maxWords từ/dòng`
- **TTS** — `Áp dụng (${_preview!.totalLines} dòng)`
- **Tipiṭaka** — `Tuyển tập chính văn ${orderIndex + 1}`
- **Tipiṭaka** — `diệu`
- **Tipiṭaka** — `luật`
- **Tools / WordList** — `"$documentTitle" — ${tp.lines.length} dòng`
- **Tools / WordList** — `$_correct / $_total đúng`
- **Tools / WordList** — `$pct% đã ôn tập`
- **Tools / WordList** — `$value ký tự`
- **Tools / WordList** — `${_selectedIds.length} đã chọn`
- **Tools / WordList** — `${provider.blindSpots} điểm mù`
- **Tools / WordList** — `${provider.masteredCount} thành thạo`
- **Tools / WordList** — `${w.sourceFiles.length} nguồn`
- **Tools / WordList** — `${widget.tools.where((t) => t.isAvailable).length} tính năng`
- **Tools / WordList** — `${words.length} từ tìm thấy · $selectedCount được chọn`
- **Tools / WordList** — `(${displayWords.length} từ)`
- **Tools / WordList** — `Chọn từ/cụm muốn lưu riêng từ "${parent.word}"`
- **Tools / WordList** — `Gặp lần $encounterCount!`
- **Tools / WordList** — `Import $count từ vào danh sách`
- **Tools / WordList** — `Không có từ nào cần ôn ${context.uiText(_skillName(_currentSkill!))}!`
- **Tools / WordList** — `Lưu ${selWords.length + selPhrases.length} mục`
- **Tools / WordList** — `Lưu từ: "$word"`
- **Tools / WordList** — `Lỗi đọc file: $e`
- **Tools / WordList** — `Ngữ cảnh (${entry.contexts.length})`
- **Tools / WordList** — `Thuần thục: ${(word.mastery * 100).toInt()}%`
- **Tools / WordList** — `Tất cả (${displayWords.length} từ)`
- **Tools / WordList** — `Tối thiểu $_minLength ký tự`
- **Tools / WordList** — `Ví dụ phức: ${data[`
- **Tools / WordList** — `Ví dụ đơn: ${data[`
- **Tools / WordList** — `Vòng ${_playbackService.listRepeatCurrent}/${_playbackService.listRepeatCount}`
- **Tools / WordList** — `Vòng ${_playbackService.listRepeatCurrent}/∞`
- **Tools / WordList** — `hình`
- **Tools / WordList** — `hình ảnh`
- **Tools / WordList** — `minh họa`
- **Tools / WordList** — `sai $wrong/${w.totalReviews} lần`
- **Tools / WordList** — `Ôn tập: ${context.uiText(_skillName(skill)).toUpperCase()}`
- **Tools / WordList** — `Đánh giá: ${context.uiText(_skillName(skill))}`
- **Tools / WordList** — `Đã lưu "$word" vào Tools`
- **Tools / WordList** — `Đã lưu ${ui.uiText(typeLabel)}: $text`
- **Tools / WordList** — `ảnh`
- **Tools / WordList** — `ảnh minh họa`
- **Tools / WordList** — `✅ Đã tạo ${selWords.length + selPhrases.length} entry con`
- **Tools / WordList** — `🌱 "${entry.word}" đã được gieo trong vườn nhớ rồi!`
- **Tools / WordList** — `🌱 Đã gieo mầm "${entry.word}" vào vườn trí nhớ!`
- **Tools / WordList** — `📅 Lần tới: ${entry.daysUntilDue} ngày nữa`
- **Tools / WordList** — `📌 Gặp nhiều lần (${frequent.length})`
- **Translation** — `$base (cặp nguồn đã chọn)`
- **Translation** — `$base (nguồn tự nhận diện — kiểm tra lại ngôn ngữ nguồn)`
- **Translation** — `${language.flag} Đã đổi bản dịch và giọng đọc sang ${language.nativeName}`
- **Translation** — `${language.nativeName} • ngôn ngữ nguồn`
- **Translation** — `File Hy-MT $issue: $path — bấm "Tải về" để tải lại file đầy đủ hoặc chọn đúng model Hy-MT GGUF.`
- **Translation** — `Hy-MT không hỗ trợ cặp $sourceLang → $targetLang`
- **Translation** — `Hy-MT trả về rỗng cho segment ${chunkIndex + 1}/$chunkCount`
- **Translation** — `Isolate Hy-MT không còn sống: ${_deathError ?? `
- **Translation** — `Isolate Hy-MT đã chết: ${error == null ? `
- **Translation** — `Không có heartbeat trong ${_pingTimeout.inSeconds}s`
- **Translation** — `Không tải được Hy-MT (HTTP ${e.response?.statusCode ?? `
- **Translation** — `Lỗi ML Kit: $e`
- **Translation** — `Lỗi tải Hy-MT: $e`
- **Translation** — `Lỗi tải gói $code`
- **Translation** — `ML Kit không hỗ trợ cặp $source → $target`
- **Translation** — `Model Hy-MT tải về $issue`
- **Translation** — `Rate limited (429) tại $server`
- **Translation** — `Server $server yêu cầu API key`
- **Translation** — `Timeout ML Kit sau 30 giây`
- **Translation** — `Timeout sau 12 giây`
- **Translation** — `Tự nhận diện ${sourceLanguage.nativeName} → ${targetLanguage.nativeName}`
- **Translation** — `[đĐơƠưƯạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹýàáảãạèéẻẽẹ`
- **Translation** — `bị cắt ($mb MB; cần khoảng 601 MB)`
- **Translation** — `không đọc được file ($e)`
- **Translation** — `không đọc được file (${e.osError?.message ?? e.message})`
- **Translation** — `model trả rỗng cho segment ${chunkIndex + 1}/$chunkCount`
- **Translation** — `mất slot glossary $lost ở segment ${chunkIndex + 1}/$chunkCount`
- **Translation** — `việt`
- **Translation** — `}). Wi-Fi rồi thử lại.`
- **Translation** — `}. Thử "Tải về" lại model rồi dịch lại.`
- **Translation** — `ìíỉĩịòóỏõọùúủũụ]`
- **Translation** — `Đã nhận diện ${widget.sourceLanguage.flag} ${widget.sourceLanguage.nativeName} • ${AppLanguageCatalog.languages.length} ngôn ngữ đích`
- **Translation** — `Đã tải gói $code`
- **Translation** — `ℹ️ LLM API: chưa cấu hình provider cho dịch LLM (màn Server & API) hoặc routing "Dịch" đang "Chỉ offline" — bỏ qua lớp LLM, dùng engine khác. (thông báo này chỉ in 1 lần)`
- **Translation** — `🧩 Hỗn hợp ngôn ngữ · ${engines.join(`
- **Understand** — `Dừng (${_formatDuration(shadowing.recordingDuration)})`
- **Understand** — `Đếm: ${shadowing.countdown}`
- **Video library** — `Quyền đọc thư mục đã mất (do gỡ hoặc cập nhật app). Chạm "Chọn thư mục khác" để cấp lại quyền.`
- **Web Reader** — `$draftCount batch nháp`
- **Web Reader** — `$noteCount ghi chú`
- **Web Reader** — `$pinnedArticleCount bài ghim`
- **Web Reader** — `$resumeCount tiếp tục`
- **Web Reader** — `$selectedCount đã chọn`
- **Web Reader** — `$statusCount theo bộ lọc`
- **Web Reader** — `${_candidates.length} ứng viên`
- **Web Reader** — `${analyzed!.encounterCount} lần gặp`
- **Web Reader** — `${collection.linkCount} liên kết`
- **Web Reader** — `${currentCollection.linkCount} liên kết`
- **Web Reader** — `${diff.inDays} ngày trước`
- **Web Reader** — `${diff.inHours} giờ trước`
- **Web Reader** — `${diff.inMinutes} phút trước`
- **Web Reader** — `${draft.candidates.length} mục`
- **Web Reader** — `).length} dòng`
- **Web Reader** — `Batch nháp · ${draftBatches.length}`
- **Web Reader** — `Bài có ghi chú · ${notedArticles.length}`
- **Web Reader** — `Bài đã ghim · ${pinnedArticles.length}`
- **Web Reader** — `Bộ sưu tập có sẵn · ${presetCollections.length}`
- **Web Reader** — `Cập nhật ${context.uiText(_HistoryTile._formatVisitedAt(draft.updatedAt))}`
- **Web Reader** — `Ghi chú · ${_controller.pageTitle.isEmpty ? _controller.currentUrl : _controller.pageTitle}`
- **Web Reader** — `Ghi chú · ${entry.title.isEmpty ? entry.url : entry.title}`
- **Web Reader** — `Mới $_newCount`
- **Web Reader** — `Mới mở · ${context.uiText(_HistoryTile._formatVisitedAt(entry.effectiveReadAt))}`
- **Web Reader** — `Nhóm "${collection.title}" sẽ bị xoá, nhưng các preset mặc định và lịch sử duyệt sẽ không bị ảnh hưởng.`
- **Web Reader** — `Nhóm của tôi · ${userCollections.length}`
- **Web Reader** — `Nhập $_selectedCount mục vào WordList`
- **Web Reader** — `Nhập $_selectedReadyCount mục sẵn sàng`
- **Web Reader** — `Ready đã chọn: $_selectedReadyCount`
- **Web Reader** — `Sẵn sàng $_readyCount`
- **Web Reader** — `Thiếu: ${missing.join(`
- **Web Reader** — `Tiến độ ~ ${entry.progressPercent}%`
- **Web Reader** — `Tiếp tục đọc · ${resumeEntries.length}`
- **Web Reader** — `Trang này đã có sẵn trong nhóm "${collection.title}"`
- **Web Reader** — `Trang này đã có sẵn trong nhóm "${currentCollection.title}"`
- **Web Reader** — `Trích đoạn · $sourceLabel`
- **Web Reader** — `Trích đoạn · ${_controller.pageTitle.isEmpty ? _controller.currentUrl : _controller.pageTitle}`
- **Web Reader** — `Xem tất cả ${collection.linkCount} link`
- **Web Reader** — `Đang lọc: “$queryLabel”`
- **Web Reader** — `Đang đọc ${entry.progressPercent}%`
- **Web Reader** — `Đã chọn $_selectedCount`
- **Web Reader** — `Đã chọn: $_selectedCount`
- **Web Reader** — `Đã có $_existingCount`
- **Web Reader** — `Đã enrich $_enrichedCount`
- **Web Reader** — `Đã lưu nhanh · ${bookmarks.length}`
- **Web Reader** — `Đã lưu trang hiện tại vào nhóm "${currentCollection.title}"`
- **Web Reader** — `Đã phân loại $_selectedClassifiedCount / $_selectedCount`
- **Web Reader** — `Đã đánh giá $_classifiedCount`
- **Web Reader** — `Độ khó đã lưu: ${context.uiText(analyzed!.userDifficulty!.label)}`
- **Web Reader** — `Ưu tiên $_priorityCount`
- **Web Reader** — `✅ Đã load vào Text Studio — ${text.split(`
- **Web Reader** — `✅ Đã lưu "$cleanWord" vào Vườn Nhớ`
- **Web Reader** — `✅ Đã lưu vào nhóm "${collection.title}"`
- **Web Reader** — `📚 Đã bổ sung ngữ cảnh cho "$cleanWord" trong WordList`
- **Web Reader** — `📚 Đã thêm "$cleanWord" vào WordList`
- **Web Reader** — `🛠️ Đã áp dụng bulk fields cho ${targets.length} mục`
- **YouTube** — `$ext · ${kbps}kbps (chọn thủ công)`
- **YouTube** — `$v lượt xem`
- **YouTube** — `${(v / 1000).toStringAsFixed(0)}K lượt xem`
- **YouTube** — `${(v / 1000000).toStringAsFixed(1)}M lượt xem`
- **YouTube** — `${_captions.length} dòng`
- **YouTube** — `${d.inDays ~/ 365} năm trước`
- **YouTube** — `${d.inDays} ngày trước`
- **YouTube** — `Chuẩn bị · ${kbps}kbps · ${_sizeLabel(totalBytes)}`
- **YouTube** — `Không có captions cho "$_lang".
Thử ngôn ngữ khác.`
- **YouTube** — `Lấy captions ($_lang)`
- **YouTube** — `Lỗi tải phụ đề: $e`
- **YouTube** — `Tải thất bại: ${event.message}`
- **YouTube** — `YouTube từ chối phát video này (lỗi cấu hình trình phát, mã $code). Bấm Thử lại, hoặc Mở ngoài để xem trong trình duyệt.`
- **YouTube** — `yt-dlp lỗi: $e`
- **YouTube** — `Đã chờ ${_waitedSec}s. AI chạy trên máy nên có thể mất 30–90 giây.`
- **YouTube** — `Đã lưu phụ đề (${lines.length} dòng): ${path ?? "?"}`
- **YouTube** — `Đã lưu phụ đề vào: $folder`
- **YouTube** — `Đã tải xong (${event.quality})`
- **YouTube** — `✅ [in4up-yt] tải xong $received / $totalBytes bytes (số lần nối: $attempt)`
- **YouTube** — `❌ [in4up-yt] tải chưa hoàn tất: $got / $totalBytes bytes sau $_maxAttempts lần thử.`

### `th`

- **AI Chat** — `⚡ ${usage.promptTokens} token vào · ${usage.completionTokens} token ra`
- **Cabin** — `App chưa hỗ trợ nhận diện offline cho $language — chọn Tiếng Việt/English hoặc dùng Engine "Hệ thống".`
- **Cabin** — `Cabin chỉ nhận diện $language khi model đã có trên máy. Thiếu model, app KHÔNG tự nhận $language bằng model ngôn ngữ khác.`
- **Cabin** — `Dịch: ${pref == HyMtOfflinePreference.hymt ? "Hy-MT" : pref == HyMtOfflinePreference.mlkit ? "ML Kit" : "Offline"}`
- **Cabin** — `Lỗi khởi động Sherpa STT: $e`
- **Cabin** — `Máy đang có $languageNote — cần bạn xác nhận mới dùng thay.`
- **Cabin** — `}.Máy có thể KHÔNG có sẵn dịch vụ Speech Recognition. Bạn có thể chuyển sang Engine "Offline (sherpa)" để nhận diện không cần dịch vụ hệ thống.`
- **Grammar / Understand** — `Không`
- **Grammar / Understand** — `Preset cá nhân gồm ${categories.length} nhóm từ loại được chọn thủ công.`
- **Grammar / Understand** — `Preset hiện tại: $activePresetName`
- **Grammar / Understand** — `^Preset cá nhân gồm \d+ nhóm từ loại được chọn thủ công\.$`
- **Grammar / Understand** — `Đang chỉnh tay từ preset gần nhất: $previousPresetName`
- **Grammar / Understand** — `Đang ẩn ${hiddenCategories.length} nhóm từ loại. Chúng chưa bị mất — bạn có thể bật lại từng nhóm, bật lại tất cả, hoặc quay về preset gần nhất $previousPresetName.`
- **Home** — `Speech recognition của hệ thống không khả dụng`
- **Learn by heart** — `$diff ngày`
- **Learn by heart** — `$value lần`
- **Learn by heart** — `${math.max(1, (base * 0.8).round())} ngày`
- **Learn by heart** — `${math.max(1, (s * 1.1).round())} ngày`
- **Learn by heart** — `${math.max(1, base)} ngày`
- **Learn by heart** — `${math.max(2, (base * 1.3).round())} ngày`
- **Learn by heart** — `${math.max(2, (s * 1.25).round())} ngày`
- **Learn by heart** — `${math.max(4, (s * 1.5).round())} ngày`
- **Learn by heart** — `1 ngày`
- **Learn by heart** — `Bản dịch (${RecitationLanguage.fromCode(_targetLang).displayName(`
- **Learn by heart** — `Bản dịch (${item.targetLanguage.displayName(`
- **Learn by heart** — `Chưa đặt tên`
- **Learn by heart** — `Chạm mở các từ ẩn để tự kiểm tra`
- **Learn by heart** — `Cần củng cố`
- **Learn by heart** — `Cẩn trọng trong từng suy nghĩ và lời nói hàng ngày.`
- **Learn by heart** — `Ghép đoạn (Chunk 1 → ${chunk.index})`
- **Learn by heart** — `Gần đúng`
- **Learn by heart** — `Hành động từ tâm ô nhiễm đem lại khổ đau.`
- **Learn by heart** — `Học ${chunk.label}`
- **Learn by heart** — `Học lại`
- **Learn by heart** — `Hợp nhất các đoạn đã học trước khi sang phần tiếp theo`
- **Learn by heart** — `Không được để trống`
- **Learn by heart** — `Kinh Pháp Cú`
- **Learn by heart** — `Kinh Tụng & Chân Ngôn`
- **Learn by heart** — `Kệ Ngôn & Thơ Thiền`
- **Learn by heart** — `Lắng nghe và đọc theo nhịp`
- **Learn by heart** — `Nguyên văn (${RecitationLanguage.fromCode(_sourceLang).displayName(`
- **Learn by heart** — `Nguyên văn (${item.sourceLanguage.displayName(`
- **Learn by heart** — `Rất tốt! Giữ vững tiến độ để đạt chuẩn thuộc lòng 100%.`
- **Learn by heart** — `Sai nhiều`
- **Learn by heart** — `Thử thách: ${chunk.label}`
- **Learn by heart** — `Tự Tạo & Ghi Chú`
- **Learn by heart** — `Ví dụ: Kệ Pháp Cú 01, Từ Bi Kinh...`
- **Learn by heart** — `Ví dụ: Tâm dẫn đầu các pháp...`
- **Learn by heart** — `Xuất sắc! Trí nhớ bền vững được tăng gấp đôi (2x FSRS Weight).`
- **Learn by heart** — `hôm nay`
- **Learn by heart** — `Ý dẫn đầu các pháp,
Ý làm chủ, ý tạo...`
- **Learn by heart** — `Ý dẫn đầu, Ý ô nhiễm, Khổ não`
- **Learn by heart** — `Đang ôn`
- **Learn by heart** — `Đã ghi nhận củng cố lại. FSRS sẽ đưa vào lịch ôn tập sớm.`
- **Learn by heart** — `Đúng hoàn toàn`
- **Learn by heart** — `Được`
- **Learn by heart** — `Đọc theo nhịp 2 dòng`
- **Learn by heart** — `Đọc trọn vẹn bài kinh và đánh giá chu kỳ ôn tập`
- **Learn by heart** — `✅ LHB sync (REST): kéo ${records.length} doc, áp dụng $applied thay đổi`
- **Learn by heart** — `✅ LHB sync (REST): đẩy ${ids.length} thay đổi`
- **Learn by heart** — `✅ LHB sync: kéo ${records.length} doc, áp dụng $applied thay đổi`
- **Learn by heart** — `✅ LHB sync: đẩy ${ids.length} thay đổi`
- **Listen** — `  Âm cần chú ý: ${word.phonemeIssues.join(`
- **Listen** — `Chưa có bản ghi nội dung (transcript).

Chạy "⚡ Tự tạo mục lục" (VAD + Whisper)
hoặc tạo LRC trong tab AI —
sau đó tìm chữ là nhảy tới đúng chỗ.`
- **Listen** — `Chưa có mục lục.
Nhấn "⚡ Tự tạo mục lục" phía trên để app
tự tách đoạn theo khoảng lặng (VAD)
và đặt tên chương (Whisper).

Hoặc nhấn "＋ Chương" để tạo thủ công
(tự neo vào vị trí đang nghe).`
- **Listen** — `Âm cần chú ý: ${word.phonemeIssues.join(`
- **Memory** — `${(stats.averageAccuracy * 100).round()}% chính xác`
- **Memory** — `${absDiff.inDays} ngày trước`
- **Memory** — `${absDiff.inHours} giờ trước`
- **Memory** — `${absDiff.inMinutes} phút trước`
- **Memory** — `${item.overdueHours.toStringAsFixed(1)}h trước`
- **Memory** — `${item.totalReviews}x ôn`
- **Memory** — `${stats.reviewedToday}/${stats.dueToday} hôm nay`
- **Memory** — `Chưa có từ nào ở giai đoạn "${context.uiText(stage.label)}"`
- **Memory** — `Xóa "${item.word}" khỏi vườn nhớ?
Dữ liệu ôn tập sẽ mất.`
- **Memory** — `sau ${diff.inDays} ngày`
- **Memory** — `sau ${diff.inHours} giờ`
- **Memory** — `Đã ôn ${stats.reviewedToday} từ
Đúng ${stats.correctToday}/${stats.reviewedToday}`
- **OCR** — `Dữ liệu ảnh ${pixels.length} byte không khớp ${width}x$height BGRA`
- **OCR** — `Không tìm thấy ảnh: $imagePath`
- **OCR** — `Lỗi nhận dạng chữ: $e`
- **Other** — `Chưa cấu hình GOOGLE_DESKTOP_CLIENT_SECRET.
Lấy secret từ Google Cloud Console và truyền qua --dart-define hoặc env.
Ví dụ: flutter run -d windows --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=GOCSPX-...`
- **Other** — `Chưa cấu hình Google Sign In cho Desktop.
Tạo OAuth client ID loại Desktop app trong Google Cloud Console > APIs & Services > Credentials.
Truyền qua --dart-define=GOOGLE_DESKTOP_CLIENT_ID=xxx --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=yyy hoặc đặt env var GOOGLE_DESKTOP_CLIENT_ID/SECRET.`
- **Other** — `Chương ${i + 1}`
- **Other** — `Không khởi tạo được Google Sign-In ($e). Khởi động lại app rồi thử lại.`
- **Other** — `Không lấy được ID token từ Google. Kiểm tra:
1. SHA-1/SHA-256 của BẢN ĐANG CÀI có trong Firebase Console chưa? (Project Settings > Your apps > SHA certificate fingerprints)
2. Google Sign-In provider đã bật trong Authentication > Sign-in method chưa?
3. serverClientId=$_webClientId có đúng Web client không?`
- **Other** — `Lỗi tải danh sách: $e`
- **Other** — `Lỗi đăng nhập: $e`
- **Other** — `cuộn ${(scrollProgressHint! * 100).round()}%`
- **Other** — `có`
- **Other** — `dòng ${lineIndex + 1}`
- **Other** — `dòng ${lineIndexHint! + 1}`
- **Other** — `không tách được đoạn theo khoảng lặng — file quá ngắn (< 2× độ dài đoạn tối thiểu) hoặc máy không đọc được waveform/thời lượng của file này. Thử: mở bài audio trong trình phát rồi chạy lại, hoặc giảm "đoạn tối thiểu" trong preset Tách nhiều.`
- **Other** — `Đang bóc băng qua API (whisper-large-v3)…
File dài sẽ tự chia chunk — có thể tắt mạng giữa chừng để dừng.`
- **Other** — `Đang nhận diện giọng nói (Whisper)…
File dài có thể mất vài phút.`
- **Other features** — ` (dòng ${context.focusLineIndex! + 1})`
- **Other features** — `${(compressionRatio * 100).round()}% độ dài nguồn`
- **Other features** — `${(copiedPhraseRatio * 100).round()}% cụm 3 từ trùng nguồn`
- **Other features** — `${(keywordPresenceRatio * 100).round()}% từ khóa quan sát được`
- **Other features** — `${shadowing.sessionResults.length} lần`
- **Other features** — `Cho mình MỘT gợi ý ngắn giúp hiểu tốt hơn đoạn này: chỉ gợi ý mở (từ khoá, cấu trúc cần chú ý), chưa giải thích trọn vẹn, để mình tự suy ra.`
- **Other features** — `Chưa có câu nào đang phát. Cho mình một gợi ý luyện tập tiếp theo phù hợp với chế độ mình đang chọn nhé.`
- **Other features** — `Câu mình đang hỏi$lineLabel:
`
- **Other features** — `File audio không tồn tại (existsSync false): $audioPath`
- **Other features** — `Giải thích câu trong dấu « » giúp mình: dịch nghĩa tiếng Việt, chỉ ra các từ/cụm từ khó và cấu trúc ngữ pháp đáng chú ý. Viết ngắn gọn, dễ hiểu.`
- **Other features** — `Hoàn tất! ${allSegments.length} segments trong ${totalSw.elapsed.inSeconds}s`
- **Other features** — `Kiểm tra hiểu bài của mình về đoạn vừa rồi: đặt 3 câu hỏi từ dễ đến khó, đợi mình tự trả lời, rồi mới đưa đáp án ngắn ở cuối.`
- **Other features** — `Mình đang học ở tab Hiểu (${parts.join(`
- **Other features** — `Tóm tắt đoạn trong « Đoạn vừa nghe » bằng 3–5 câu tiếng Việt: nêu ý chính và 3–5 từ vựng đáng nhớ kèm nghĩa ngắn.`
- **Other features** — `Tối đa: ${shadowing.settings.maxRecordDuration.inSeconds}s`
- **Other features** — `VAD lỗi: $e`
- **Other features** — `bài: « ${context.sourceTitle} »`
- **Other features** — `Đang bóc băng chunk ${i + 1}/$totalChunks...`
- **Other features** — `Đang cắt chunk ${i + 1}/$totalChunks (${seg.startTime.toStringAsFixed(1)}s->${seg.endTime.toStringAsFixed(1)}s)...`
- **Other features** — `Đang dịch $done/$total khối chữ…`
- **Other features** — `Đang quét VAD… ${(f * 100).toStringAsFixed(0)}%`
- **Other features** — `Đã tìm ${speechSegments.length} đoạn speech, bỏ $skipped đoạn silence`
- **Other features** — `ℹ️ screen translate: vùng chọn $requestedRegion quá bé/ngoài màn hình ⇒ dịch cả màn hình`
- **Other features** — `⚠️ Segment $i: không cắt được chunk (FFmpeg lỗi?) — bỏ qua THAY VÌ re-transcribe toàn bộ file gốc`
- **Other screens** — `"${entry.title}" sẽ bị xoá khỏi thư viện cloud.`
- **Other screens** — `${tp.lines.length} dòng`
- **Other screens** — `Cài từ điển có sẵn bằng một chạm (offline)`
- **Other screens** — `Đã cập nhật "${updated.title}" từ văn bản hiện tại`
- **Other screens** — `Đã cập nhật file cloud "${updatedEntry.title}"`
- **Other screens** — `Đã cập nhật trực tiếp file cloud "${updated.title}"`
- **Other screens** — `Đã lưu "${entry.title}" lên cloud`
- **PDF Reader** — `    <!-- không có highlight/ghi chú nào để xuất -->
`
- **PDF Reader** — `${annotations.length} ghi chú đã lưu`
- **PDF Reader** — `${controller.annotations.length} ghi chú`
- **PDF Reader** — `${entry.encounterCount} lần gặp`
- **PDF Reader** — `${entry.sourceFiles.length} nguồn`
- **PDF Reader** — `PDF đoạn chọn · ${_title.replaceAll(`
- **PDF Reader** — `aàáảãạăằắẳẵặâầấẩẫậ`
- **PDF Reader** — `dđ`
- **PDF Reader** — `eèéẻẽẹêềếểễệ`
- **PDF Reader** — `iìíỉĩị`
- **PDF Reader** — `oòóỏõọôồốổỗộơờớởỡợ`
- **PDF Reader** — `uùúủũụưừứửữự`
- **PDF Reader** — `yỳýỷỹỵ`
- **PDF Reader** — `✅ Đã load "$_title" vào Text Studio`
- **PDF Reader** — `✅ Đã lưu "$_displayWord" vào Vườn Nhớ`
- **Read** — ` : selectedText}" → Đã lưu nhanh`
- **Read** — `${sourceLanguage.translationCode}×3 chậm 0.75x`
- **Read** — `Bạn bỏ sót một số từ khóa quan trọng: ${result.missingWords.join(`
- **Read** — `Đáp án: ${_blankPrompts.map((e) => `
- **Settings** — `Ngôn ngữ: ${lang.isEmpty ? `
- **Settings** — `Xoá (${level.sizeInMB}MB)`
- **Settings** — `Xoá (${profile.approxSizeMB}MB)`
- **Shared widgets** — `$displayLabel chưa chắc`
- **Shared widgets** — `$displayLabel ổn`
- **Shared widgets** — `${_getRepeatCount(level)}x lặp`
- **Shared widgets** — `${_lines!.length} dòng · Nhấn để mở rộng`
- **Shared widgets** — `${diff.inDays} ngày`
- **Shared widgets** — `${diff.inHours}h trước`
- **Shared widgets** — `${widget.title} (${_lines!.length} dòng)`
- **Shared widgets** — `Ví dụ: ${word.example!.trim()}`
- **Shared widgets** — `Ôn tiếp sau ${word.daysUntilDue} ngày`
- **Shared widgets** — `Đang chờ... ${player.gapDuration.toStringAsFixed(1)}s`
- **Shared widgets** — `Đã lưu $relativeTime`
- **Shared widgets** — `Đã lưu: ${segment.title}`
- **Shared widgets** — `Đã phân loại $_classifiedCount / ${_candidates.length}`
- **TTS** — `"${provider.label}" lỗi: ${e.message}`
- **TTS** — `"${provider.label}" phản hồi quá chậm (timeout)`
- **TTS** — `"${provider.label}" đang rate-limit (429) — thử giảm tốc độ gọi`
- **TTS** — `${_friendlyError(e)} (đoạn ${i + 1}/${chunks.length})`
- **TTS** — `${_preview!.originalLineCount} dòng → ${_preview!.totalLines} dòng (~${_preview!.avgWordsPerLine.toStringAsFixed(1)} từ/dòng)`
- **TTS** — `API key sai/thiếu quyền tại "${provider.label}"`
- **TTS** — `Chưa có giọng Piper cho $language`
- **TTS** — `Dữ liệu trả về không phải audio hợp lệ: ${e.message}`
- **TTS** — `Edge TTS lỗi: $error`
- **TTS** — `Edge TTS từ chối kết nối WebSocket: ${error.message}`
- **TTS** — `Không có engine TTS nào phát được văn bản này ($lang).`
- **TTS** — `Không kết nối được "${provider.label}" (mất mạng/sai địa chỉ server)`
- **TTS** — `Không nạp được giọng Piper $name (thiếu espeak-ng-data?)`
- **TTS** — `Lỗi phát: $e`
- **TTS** — `Lỗi stream: $e`
- **TTS** — `Provider "${provider.label}" chưa chọn model TTS — cấu hình ở Server & API`
- **TTS** — `Provider "${provider.label}" thiếu baseUrl`
- **TTS** — `Tối thiểu $_minWords từ trước khi tách`
- **TTS** — `Tối đa $_maxWords từ/dòng`
- **TTS** — `Áp dụng (${_preview!.totalLines} dòng)`
- **Tipiṭaka** — `Tuyển tập chính văn ${orderIndex + 1}`
- **Tipiṭaka** — `diệu`
- **Tipiṭaka** — `luật`
- **Tools / WordList** — `"$documentTitle" — ${tp.lines.length} dòng`
- **Tools / WordList** — `$_correct / $_total đúng`
- **Tools / WordList** — `$pct% đã ôn tập`
- **Tools / WordList** — `$value ký tự`
- **Tools / WordList** — `${_selectedIds.length} đã chọn`
- **Tools / WordList** — `${provider.blindSpots} điểm mù`
- **Tools / WordList** — `${provider.masteredCount} thành thạo`
- **Tools / WordList** — `${w.sourceFiles.length} nguồn`
- **Tools / WordList** — `${widget.tools.where((t) => t.isAvailable).length} tính năng`
- **Tools / WordList** — `${words.length} từ tìm thấy · $selectedCount được chọn`
- **Tools / WordList** — `(${displayWords.length} từ)`
- **Tools / WordList** — `Chọn từ/cụm muốn lưu riêng từ "${parent.word}"`
- **Tools / WordList** — `Gặp lần $encounterCount!`
- **Tools / WordList** — `Import $count từ vào danh sách`
- **Tools / WordList** — `Không có từ nào cần ôn ${context.uiText(_skillName(_currentSkill!))}!`
- **Tools / WordList** — `Lưu ${selWords.length + selPhrases.length} mục`
- **Tools / WordList** — `Lưu từ: "$word"`
- **Tools / WordList** — `Lỗi đọc file: $e`
- **Tools / WordList** — `Ngữ cảnh (${entry.contexts.length})`
- **Tools / WordList** — `Thuần thục: ${(word.mastery * 100).toInt()}%`
- **Tools / WordList** — `Tất cả (${displayWords.length} từ)`
- **Tools / WordList** — `Tối thiểu $_minLength ký tự`
- **Tools / WordList** — `Ví dụ phức: ${data[`
- **Tools / WordList** — `Ví dụ đơn: ${data[`
- **Tools / WordList** — `Vòng ${_playbackService.listRepeatCurrent}/${_playbackService.listRepeatCount}`
- **Tools / WordList** — `Vòng ${_playbackService.listRepeatCurrent}/∞`
- **Tools / WordList** — `hình`
- **Tools / WordList** — `hình ảnh`
- **Tools / WordList** — `minh họa`
- **Tools / WordList** — `sai $wrong/${w.totalReviews} lần`
- **Tools / WordList** — `Ôn tập: ${context.uiText(_skillName(skill)).toUpperCase()}`
- **Tools / WordList** — `Đánh giá: ${context.uiText(_skillName(skill))}`
- **Tools / WordList** — `Đã lưu "$word" vào Tools`
- **Tools / WordList** — `Đã lưu ${ui.uiText(typeLabel)}: $text`
- **Tools / WordList** — `ảnh`
- **Tools / WordList** — `ảnh minh họa`
- **Tools / WordList** — `✅ Đã tạo ${selWords.length + selPhrases.length} entry con`
- **Tools / WordList** — `🌱 "${entry.word}" đã được gieo trong vườn nhớ rồi!`
- **Tools / WordList** — `🌱 Đã gieo mầm "${entry.word}" vào vườn trí nhớ!`
- **Tools / WordList** — `📅 Lần tới: ${entry.daysUntilDue} ngày nữa`
- **Tools / WordList** — `📌 Gặp nhiều lần (${frequent.length})`
- **Translation** — `$base (cặp nguồn đã chọn)`
- **Translation** — `$base (nguồn tự nhận diện — kiểm tra lại ngôn ngữ nguồn)`
- **Translation** — `${language.flag} Đã đổi bản dịch và giọng đọc sang ${language.nativeName}`
- **Translation** — `${language.nativeName} • ngôn ngữ nguồn`
- **Translation** — `File Hy-MT $issue: $path — bấm "Tải về" để tải lại file đầy đủ hoặc chọn đúng model Hy-MT GGUF.`
- **Translation** — `Hy-MT không hỗ trợ cặp $sourceLang → $targetLang`
- **Translation** — `Hy-MT trả về rỗng cho segment ${chunkIndex + 1}/$chunkCount`
- **Translation** — `Isolate Hy-MT không còn sống: ${_deathError ?? `
- **Translation** — `Isolate Hy-MT đã chết: ${error == null ? `
- **Translation** — `Không có heartbeat trong ${_pingTimeout.inSeconds}s`
- **Translation** — `Không tải được Hy-MT (HTTP ${e.response?.statusCode ?? `
- **Translation** — `Lỗi ML Kit: $e`
- **Translation** — `Lỗi tải Hy-MT: $e`
- **Translation** — `Lỗi tải gói $code`
- **Translation** — `ML Kit không hỗ trợ cặp $source → $target`
- **Translation** — `Model Hy-MT tải về $issue`
- **Translation** — `Rate limited (429) tại $server`
- **Translation** — `Server $server yêu cầu API key`
- **Translation** — `Timeout ML Kit sau 30 giây`
- **Translation** — `Timeout sau 12 giây`
- **Translation** — `Tự nhận diện ${sourceLanguage.nativeName} → ${targetLanguage.nativeName}`
- **Translation** — `[đĐơƠưƯạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹýàáảãạèéẻẽẹ`
- **Translation** — `bị cắt ($mb MB; cần khoảng 601 MB)`
- **Translation** — `không đọc được file ($e)`
- **Translation** — `không đọc được file (${e.osError?.message ?? e.message})`
- **Translation** — `model trả rỗng cho segment ${chunkIndex + 1}/$chunkCount`
- **Translation** — `mất slot glossary $lost ở segment ${chunkIndex + 1}/$chunkCount`
- **Translation** — `việt`
- **Translation** — `}). Wi-Fi rồi thử lại.`
- **Translation** — `}. Thử "Tải về" lại model rồi dịch lại.`
- **Translation** — `ìíỉĩịòóỏõọùúủũụ]`
- **Translation** — `Đã nhận diện ${widget.sourceLanguage.flag} ${widget.sourceLanguage.nativeName} • ${AppLanguageCatalog.languages.length} ngôn ngữ đích`
- **Translation** — `Đã tải gói $code`
- **Translation** — `ℹ️ LLM API: chưa cấu hình provider cho dịch LLM (màn Server & API) hoặc routing "Dịch" đang "Chỉ offline" — bỏ qua lớp LLM, dùng engine khác. (thông báo này chỉ in 1 lần)`
- **Translation** — `🧩 Hỗn hợp ngôn ngữ · ${engines.join(`
- **Understand** — `Dừng (${_formatDuration(shadowing.recordingDuration)})`
- **Understand** — `Đếm: ${shadowing.countdown}`
- **Video library** — `Quyền đọc thư mục đã mất (do gỡ hoặc cập nhật app). Chạm "Chọn thư mục khác" để cấp lại quyền.`
- **Web Reader** — `$draftCount batch nháp`
- **Web Reader** — `$noteCount ghi chú`
- **Web Reader** — `$pinnedArticleCount bài ghim`
- **Web Reader** — `$resumeCount tiếp tục`
- **Web Reader** — `$selectedCount đã chọn`
- **Web Reader** — `$statusCount theo bộ lọc`
- **Web Reader** — `${_candidates.length} ứng viên`
- **Web Reader** — `${analyzed!.encounterCount} lần gặp`
- **Web Reader** — `${collection.linkCount} liên kết`
- **Web Reader** — `${currentCollection.linkCount} liên kết`
- **Web Reader** — `${diff.inDays} ngày trước`
- **Web Reader** — `${diff.inHours} giờ trước`
- **Web Reader** — `${diff.inMinutes} phút trước`
- **Web Reader** — `${draft.candidates.length} mục`
- **Web Reader** — `).length} dòng`
- **Web Reader** — `Batch nháp · ${draftBatches.length}`
- **Web Reader** — `Bài có ghi chú · ${notedArticles.length}`
- **Web Reader** — `Bài đã ghim · ${pinnedArticles.length}`
- **Web Reader** — `Bộ sưu tập có sẵn · ${presetCollections.length}`
- **Web Reader** — `Cập nhật ${context.uiText(_HistoryTile._formatVisitedAt(draft.updatedAt))}`
- **Web Reader** — `Ghi chú · ${_controller.pageTitle.isEmpty ? _controller.currentUrl : _controller.pageTitle}`
- **Web Reader** — `Ghi chú · ${entry.title.isEmpty ? entry.url : entry.title}`
- **Web Reader** — `Mới $_newCount`
- **Web Reader** — `Mới mở · ${context.uiText(_HistoryTile._formatVisitedAt(entry.effectiveReadAt))}`
- **Web Reader** — `Nhóm "${collection.title}" sẽ bị xoá, nhưng các preset mặc định và lịch sử duyệt sẽ không bị ảnh hưởng.`
- **Web Reader** — `Nhóm của tôi · ${userCollections.length}`
- **Web Reader** — `Nhập $_selectedCount mục vào WordList`
- **Web Reader** — `Nhập $_selectedReadyCount mục sẵn sàng`
- **Web Reader** — `Ready đã chọn: $_selectedReadyCount`
- **Web Reader** — `Sẵn sàng $_readyCount`
- **Web Reader** — `Thiếu: ${missing.join(`
- **Web Reader** — `Tiến độ ~ ${entry.progressPercent}%`
- **Web Reader** — `Tiếp tục đọc · ${resumeEntries.length}`
- **Web Reader** — `Trang này đã có sẵn trong nhóm "${collection.title}"`
- **Web Reader** — `Trang này đã có sẵn trong nhóm "${currentCollection.title}"`
- **Web Reader** — `Trích đoạn · $sourceLabel`
- **Web Reader** — `Trích đoạn · ${_controller.pageTitle.isEmpty ? _controller.currentUrl : _controller.pageTitle}`
- **Web Reader** — `Xem tất cả ${collection.linkCount} link`
- **Web Reader** — `Đang lọc: “$queryLabel”`
- **Web Reader** — `Đang đọc ${entry.progressPercent}%`
- **Web Reader** — `Đã chọn $_selectedCount`
- **Web Reader** — `Đã chọn: $_selectedCount`
- **Web Reader** — `Đã có $_existingCount`
- **Web Reader** — `Đã enrich $_enrichedCount`
- **Web Reader** — `Đã lưu nhanh · ${bookmarks.length}`
- **Web Reader** — `Đã lưu trang hiện tại vào nhóm "${currentCollection.title}"`
- **Web Reader** — `Đã phân loại $_selectedClassifiedCount / $_selectedCount`
- **Web Reader** — `Đã đánh giá $_classifiedCount`
- **Web Reader** — `Độ khó đã lưu: ${context.uiText(analyzed!.userDifficulty!.label)}`
- **Web Reader** — `Ưu tiên $_priorityCount`
- **Web Reader** — `✅ Đã load vào Text Studio — ${text.split(`
- **Web Reader** — `✅ Đã lưu "$cleanWord" vào Vườn Nhớ`
- **Web Reader** — `✅ Đã lưu vào nhóm "${collection.title}"`
- **Web Reader** — `📚 Đã bổ sung ngữ cảnh cho "$cleanWord" trong WordList`
- **Web Reader** — `📚 Đã thêm "$cleanWord" vào WordList`
- **Web Reader** — `🛠️ Đã áp dụng bulk fields cho ${targets.length} mục`
- **YouTube** — `$ext · ${kbps}kbps (chọn thủ công)`
- **YouTube** — `$v lượt xem`
- **YouTube** — `${(v / 1000).toStringAsFixed(0)}K lượt xem`
- **YouTube** — `${(v / 1000000).toStringAsFixed(1)}M lượt xem`
- **YouTube** — `${_captions.length} dòng`
- **YouTube** — `${d.inDays ~/ 365} năm trước`
- **YouTube** — `${d.inDays} ngày trước`
- **YouTube** — `Chuẩn bị · ${kbps}kbps · ${_sizeLabel(totalBytes)}`
- **YouTube** — `Không có captions cho "$_lang".
Thử ngôn ngữ khác.`
- **YouTube** — `Lấy captions ($_lang)`
- **YouTube** — `Lỗi tải phụ đề: $e`
- **YouTube** — `Tải thất bại: ${event.message}`
- **YouTube** — `YouTube từ chối phát video này (lỗi cấu hình trình phát, mã $code). Bấm Thử lại, hoặc Mở ngoài để xem trong trình duyệt.`
- **YouTube** — `yt-dlp lỗi: $e`
- **YouTube** — `Đã chờ ${_waitedSec}s. AI chạy trên máy nên có thể mất 30–90 giây.`
- **YouTube** — `Đã lưu phụ đề (${lines.length} dòng): ${path ?? "?"}`
- **YouTube** — `Đã lưu phụ đề vào: $folder`
- **YouTube** — `Đã tải xong (${event.quality})`
- **YouTube** — `✅ [in4up-yt] tải xong $received / $totalBytes bytes (số lần nối: $attempt)`
- **YouTube** — `❌ [in4up-yt] tải chưa hoàn tất: $got / $totalBytes bytes sau $_maxAttempts lần thử.`

### `ja`

- **AI Chat** — `⚡ ${usage.promptTokens} token vào · ${usage.completionTokens} token ra`
- **Cabin** — `App chưa hỗ trợ nhận diện offline cho $language — chọn Tiếng Việt/English hoặc dùng Engine "Hệ thống".`
- **Cabin** — `Cabin chỉ nhận diện $language khi model đã có trên máy. Thiếu model, app KHÔNG tự nhận $language bằng model ngôn ngữ khác.`
- **Cabin** — `Dịch: ${pref == HyMtOfflinePreference.hymt ? "Hy-MT" : pref == HyMtOfflinePreference.mlkit ? "ML Kit" : "Offline"}`
- **Cabin** — `Lỗi khởi động Sherpa STT: $e`
- **Cabin** — `Máy đang có $languageNote — cần bạn xác nhận mới dùng thay.`
- **Cabin** — `}.Máy có thể KHÔNG có sẵn dịch vụ Speech Recognition. Bạn có thể chuyển sang Engine "Offline (sherpa)" để nhận diện không cần dịch vụ hệ thống.`
- **Grammar / Understand** — `Không`
- **Grammar / Understand** — `Preset cá nhân gồm ${categories.length} nhóm từ loại được chọn thủ công.`
- **Grammar / Understand** — `Preset hiện tại: $activePresetName`
- **Grammar / Understand** — `^Preset cá nhân gồm \d+ nhóm từ loại được chọn thủ công\.$`
- **Grammar / Understand** — `Đang chỉnh tay từ preset gần nhất: $previousPresetName`
- **Grammar / Understand** — `Đang ẩn ${hiddenCategories.length} nhóm từ loại. Chúng chưa bị mất — bạn có thể bật lại từng nhóm, bật lại tất cả, hoặc quay về preset gần nhất $previousPresetName.`
- **Home** — `Speech recognition của hệ thống không khả dụng`
- **Learn by heart** — `$diff ngày`
- **Learn by heart** — `$value lần`
- **Learn by heart** — `${math.max(1, (base * 0.8).round())} ngày`
- **Learn by heart** — `${math.max(1, (s * 1.1).round())} ngày`
- **Learn by heart** — `${math.max(1, base)} ngày`
- **Learn by heart** — `${math.max(2, (base * 1.3).round())} ngày`
- **Learn by heart** — `${math.max(2, (s * 1.25).round())} ngày`
- **Learn by heart** — `${math.max(4, (s * 1.5).round())} ngày`
- **Learn by heart** — `1 ngày`
- **Learn by heart** — `Bản dịch (${RecitationLanguage.fromCode(_targetLang).displayName(`
- **Learn by heart** — `Bản dịch (${item.targetLanguage.displayName(`
- **Learn by heart** — `Chưa đặt tên`
- **Learn by heart** — `Chạm mở các từ ẩn để tự kiểm tra`
- **Learn by heart** — `Cần củng cố`
- **Learn by heart** — `Cẩn trọng trong từng suy nghĩ và lời nói hàng ngày.`
- **Learn by heart** — `Ghép đoạn (Chunk 1 → ${chunk.index})`
- **Learn by heart** — `Gần đúng`
- **Learn by heart** — `Hành động từ tâm ô nhiễm đem lại khổ đau.`
- **Learn by heart** — `Học ${chunk.label}`
- **Learn by heart** — `Học lại`
- **Learn by heart** — `Hợp nhất các đoạn đã học trước khi sang phần tiếp theo`
- **Learn by heart** — `Không được để trống`
- **Learn by heart** — `Kinh Pháp Cú`
- **Learn by heart** — `Kinh Tụng & Chân Ngôn`
- **Learn by heart** — `Kệ Ngôn & Thơ Thiền`
- **Learn by heart** — `Lắng nghe và đọc theo nhịp`
- **Learn by heart** — `Nguyên văn (${RecitationLanguage.fromCode(_sourceLang).displayName(`
- **Learn by heart** — `Nguyên văn (${item.sourceLanguage.displayName(`
- **Learn by heart** — `Rất tốt! Giữ vững tiến độ để đạt chuẩn thuộc lòng 100%.`
- **Learn by heart** — `Sai nhiều`
- **Learn by heart** — `Thử thách: ${chunk.label}`
- **Learn by heart** — `Tự Tạo & Ghi Chú`
- **Learn by heart** — `Ví dụ: Kệ Pháp Cú 01, Từ Bi Kinh...`
- **Learn by heart** — `Ví dụ: Tâm dẫn đầu các pháp...`
- **Learn by heart** — `Xuất sắc! Trí nhớ bền vững được tăng gấp đôi (2x FSRS Weight).`
- **Learn by heart** — `hôm nay`
- **Learn by heart** — `Ý dẫn đầu các pháp,
Ý làm chủ, ý tạo...`
- **Learn by heart** — `Ý dẫn đầu, Ý ô nhiễm, Khổ não`
- **Learn by heart** — `Đang ôn`
- **Learn by heart** — `Đã ghi nhận củng cố lại. FSRS sẽ đưa vào lịch ôn tập sớm.`
- **Learn by heart** — `Đúng hoàn toàn`
- **Learn by heart** — `Được`
- **Learn by heart** — `Đọc theo nhịp 2 dòng`
- **Learn by heart** — `Đọc trọn vẹn bài kinh và đánh giá chu kỳ ôn tập`
- **Learn by heart** — `✅ LHB sync (REST): kéo ${records.length} doc, áp dụng $applied thay đổi`
- **Learn by heart** — `✅ LHB sync (REST): đẩy ${ids.length} thay đổi`
- **Learn by heart** — `✅ LHB sync: kéo ${records.length} doc, áp dụng $applied thay đổi`
- **Learn by heart** — `✅ LHB sync: đẩy ${ids.length} thay đổi`
- **Listen** — `  Âm cần chú ý: ${word.phonemeIssues.join(`
- **Listen** — `Chưa có bản ghi nội dung (transcript).

Chạy "⚡ Tự tạo mục lục" (VAD + Whisper)
hoặc tạo LRC trong tab AI —
sau đó tìm chữ là nhảy tới đúng chỗ.`
- **Listen** — `Chưa có mục lục.
Nhấn "⚡ Tự tạo mục lục" phía trên để app
tự tách đoạn theo khoảng lặng (VAD)
và đặt tên chương (Whisper).

Hoặc nhấn "＋ Chương" để tạo thủ công
(tự neo vào vị trí đang nghe).`
- **Listen** — `Âm cần chú ý: ${word.phonemeIssues.join(`
- **Memory** — `${(stats.averageAccuracy * 100).round()}% chính xác`
- **Memory** — `${absDiff.inDays} ngày trước`
- **Memory** — `${absDiff.inHours} giờ trước`
- **Memory** — `${absDiff.inMinutes} phút trước`
- **Memory** — `${item.overdueHours.toStringAsFixed(1)}h trước`
- **Memory** — `${item.totalReviews}x ôn`
- **Memory** — `${stats.reviewedToday}/${stats.dueToday} hôm nay`
- **Memory** — `Chưa có từ nào ở giai đoạn "${context.uiText(stage.label)}"`
- **Memory** — `Xóa "${item.word}" khỏi vườn nhớ?
Dữ liệu ôn tập sẽ mất.`
- **Memory** — `sau ${diff.inDays} ngày`
- **Memory** — `sau ${diff.inHours} giờ`
- **Memory** — `Đã ôn ${stats.reviewedToday} từ
Đúng ${stats.correctToday}/${stats.reviewedToday}`
- **OCR** — `Dữ liệu ảnh ${pixels.length} byte không khớp ${width}x$height BGRA`
- **OCR** — `Không tìm thấy ảnh: $imagePath`
- **OCR** — `Lỗi nhận dạng chữ: $e`
- **Other** — `Chưa cấu hình GOOGLE_DESKTOP_CLIENT_SECRET.
Lấy secret từ Google Cloud Console và truyền qua --dart-define hoặc env.
Ví dụ: flutter run -d windows --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=GOCSPX-...`
- **Other** — `Chưa cấu hình Google Sign In cho Desktop.
Tạo OAuth client ID loại Desktop app trong Google Cloud Console > APIs & Services > Credentials.
Truyền qua --dart-define=GOOGLE_DESKTOP_CLIENT_ID=xxx --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=yyy hoặc đặt env var GOOGLE_DESKTOP_CLIENT_ID/SECRET.`
- **Other** — `Chương ${i + 1}`
- **Other** — `Không khởi tạo được Google Sign-In ($e). Khởi động lại app rồi thử lại.`
- **Other** — `Không lấy được ID token từ Google. Kiểm tra:
1. SHA-1/SHA-256 của BẢN ĐANG CÀI có trong Firebase Console chưa? (Project Settings > Your apps > SHA certificate fingerprints)
2. Google Sign-In provider đã bật trong Authentication > Sign-in method chưa?
3. serverClientId=$_webClientId có đúng Web client không?`
- **Other** — `Lỗi tải danh sách: $e`
- **Other** — `Lỗi đăng nhập: $e`
- **Other** — `cuộn ${(scrollProgressHint! * 100).round()}%`
- **Other** — `có`
- **Other** — `dòng ${lineIndex + 1}`
- **Other** — `dòng ${lineIndexHint! + 1}`
- **Other** — `không tách được đoạn theo khoảng lặng — file quá ngắn (< 2× độ dài đoạn tối thiểu) hoặc máy không đọc được waveform/thời lượng của file này. Thử: mở bài audio trong trình phát rồi chạy lại, hoặc giảm "đoạn tối thiểu" trong preset Tách nhiều.`
- **Other** — `Đang bóc băng qua API (whisper-large-v3)…
File dài sẽ tự chia chunk — có thể tắt mạng giữa chừng để dừng.`
- **Other** — `Đang nhận diện giọng nói (Whisper)…
File dài có thể mất vài phút.`
- **Other features** — ` (dòng ${context.focusLineIndex! + 1})`
- **Other features** — `${(compressionRatio * 100).round()}% độ dài nguồn`
- **Other features** — `${(copiedPhraseRatio * 100).round()}% cụm 3 từ trùng nguồn`
- **Other features** — `${(keywordPresenceRatio * 100).round()}% từ khóa quan sát được`
- **Other features** — `${shadowing.sessionResults.length} lần`
- **Other features** — `Cho mình MỘT gợi ý ngắn giúp hiểu tốt hơn đoạn này: chỉ gợi ý mở (từ khoá, cấu trúc cần chú ý), chưa giải thích trọn vẹn, để mình tự suy ra.`
- **Other features** — `Chưa có câu nào đang phát. Cho mình một gợi ý luyện tập tiếp theo phù hợp với chế độ mình đang chọn nhé.`
- **Other features** — `Câu mình đang hỏi$lineLabel:
`
- **Other features** — `File audio không tồn tại (existsSync false): $audioPath`
- **Other features** — `Giải thích câu trong dấu « » giúp mình: dịch nghĩa tiếng Việt, chỉ ra các từ/cụm từ khó và cấu trúc ngữ pháp đáng chú ý. Viết ngắn gọn, dễ hiểu.`
- **Other features** — `Hoàn tất! ${allSegments.length} segments trong ${totalSw.elapsed.inSeconds}s`
- **Other features** — `Kiểm tra hiểu bài của mình về đoạn vừa rồi: đặt 3 câu hỏi từ dễ đến khó, đợi mình tự trả lời, rồi mới đưa đáp án ngắn ở cuối.`
- **Other features** — `Mình đang học ở tab Hiểu (${parts.join(`
- **Other features** — `Tóm tắt đoạn trong « Đoạn vừa nghe » bằng 3–5 câu tiếng Việt: nêu ý chính và 3–5 từ vựng đáng nhớ kèm nghĩa ngắn.`
- **Other features** — `Tối đa: ${shadowing.settings.maxRecordDuration.inSeconds}s`
- **Other features** — `VAD lỗi: $e`
- **Other features** — `bài: « ${context.sourceTitle} »`
- **Other features** — `Đang bóc băng chunk ${i + 1}/$totalChunks...`
- **Other features** — `Đang cắt chunk ${i + 1}/$totalChunks (${seg.startTime.toStringAsFixed(1)}s->${seg.endTime.toStringAsFixed(1)}s)...`
- **Other features** — `Đang dịch $done/$total khối chữ…`
- **Other features** — `Đang quét VAD… ${(f * 100).toStringAsFixed(0)}%`
- **Other features** — `Đã tìm ${speechSegments.length} đoạn speech, bỏ $skipped đoạn silence`
- **Other features** — `ℹ️ screen translate: vùng chọn $requestedRegion quá bé/ngoài màn hình ⇒ dịch cả màn hình`
- **Other features** — `⚠️ Segment $i: không cắt được chunk (FFmpeg lỗi?) — bỏ qua THAY VÌ re-transcribe toàn bộ file gốc`
- **Other screens** — `"${entry.title}" sẽ bị xoá khỏi thư viện cloud.`
- **Other screens** — `${tp.lines.length} dòng`
- **Other screens** — `Cài từ điển có sẵn bằng một chạm (offline)`
- **Other screens** — `Đã cập nhật "${updated.title}" từ văn bản hiện tại`
- **Other screens** — `Đã cập nhật file cloud "${updatedEntry.title}"`
- **Other screens** — `Đã cập nhật trực tiếp file cloud "${updated.title}"`
- **Other screens** — `Đã lưu "${entry.title}" lên cloud`
- **PDF Reader** — `    <!-- không có highlight/ghi chú nào để xuất -->
`
- **PDF Reader** — `${annotations.length} ghi chú đã lưu`
- **PDF Reader** — `${controller.annotations.length} ghi chú`
- **PDF Reader** — `${entry.encounterCount} lần gặp`
- **PDF Reader** — `${entry.sourceFiles.length} nguồn`
- **PDF Reader** — `PDF đoạn chọn · ${_title.replaceAll(`
- **PDF Reader** — `aàáảãạăằắẳẵặâầấẩẫậ`
- **PDF Reader** — `dđ`
- **PDF Reader** — `eèéẻẽẹêềếểễệ`
- **PDF Reader** — `iìíỉĩị`
- **PDF Reader** — `oòóỏõọôồốổỗộơờớởỡợ`
- **PDF Reader** — `uùúủũụưừứửữự`
- **PDF Reader** — `yỳýỷỹỵ`
- **PDF Reader** — `✅ Đã load "$_title" vào Text Studio`
- **PDF Reader** — `✅ Đã lưu "$_displayWord" vào Vườn Nhớ`
- **Read** — ` : selectedText}" → Đã lưu nhanh`
- **Read** — `${sourceLanguage.translationCode}×3 chậm 0.75x`
- **Read** — `Bạn bỏ sót một số từ khóa quan trọng: ${result.missingWords.join(`
- **Read** — `Đáp án: ${_blankPrompts.map((e) => `
- **Settings** — `Ngôn ngữ: ${lang.isEmpty ? `
- **Settings** — `Xoá (${level.sizeInMB}MB)`
- **Settings** — `Xoá (${profile.approxSizeMB}MB)`
- **Shared widgets** — `$displayLabel chưa chắc`
- **Shared widgets** — `$displayLabel ổn`
- **Shared widgets** — `${_getRepeatCount(level)}x lặp`
- **Shared widgets** — `${_lines!.length} dòng · Nhấn để mở rộng`
- **Shared widgets** — `${diff.inDays} ngày`
- **Shared widgets** — `${diff.inHours}h trước`
- **Shared widgets** — `${widget.title} (${_lines!.length} dòng)`
- **Shared widgets** — `Ví dụ: ${word.example!.trim()}`
- **Shared widgets** — `Ôn tiếp sau ${word.daysUntilDue} ngày`
- **Shared widgets** — `Đang chờ... ${player.gapDuration.toStringAsFixed(1)}s`
- **Shared widgets** — `Đã lưu $relativeTime`
- **Shared widgets** — `Đã lưu: ${segment.title}`
- **Shared widgets** — `Đã phân loại $_classifiedCount / ${_candidates.length}`
- **TTS** — `"${provider.label}" lỗi: ${e.message}`
- **TTS** — `"${provider.label}" phản hồi quá chậm (timeout)`
- **TTS** — `"${provider.label}" đang rate-limit (429) — thử giảm tốc độ gọi`
- **TTS** — `${_friendlyError(e)} (đoạn ${i + 1}/${chunks.length})`
- **TTS** — `${_preview!.originalLineCount} dòng → ${_preview!.totalLines} dòng (~${_preview!.avgWordsPerLine.toStringAsFixed(1)} từ/dòng)`
- **TTS** — `API key sai/thiếu quyền tại "${provider.label}"`
- **TTS** — `Chưa có giọng Piper cho $language`
- **TTS** — `Dữ liệu trả về không phải audio hợp lệ: ${e.message}`
- **TTS** — `Edge TTS lỗi: $error`
- **TTS** — `Edge TTS từ chối kết nối WebSocket: ${error.message}`
- **TTS** — `Không có engine TTS nào phát được văn bản này ($lang).`
- **TTS** — `Không kết nối được "${provider.label}" (mất mạng/sai địa chỉ server)`
- **TTS** — `Không nạp được giọng Piper $name (thiếu espeak-ng-data?)`
- **TTS** — `Lỗi phát: $e`
- **TTS** — `Lỗi stream: $e`
- **TTS** — `Provider "${provider.label}" chưa chọn model TTS — cấu hình ở Server & API`
- **TTS** — `Provider "${provider.label}" thiếu baseUrl`
- **TTS** — `Tối thiểu $_minWords từ trước khi tách`
- **TTS** — `Tối đa $_maxWords từ/dòng`
- **TTS** — `Áp dụng (${_preview!.totalLines} dòng)`
- **Tipiṭaka** — `Tuyển tập chính văn ${orderIndex + 1}`
- **Tipiṭaka** — `diệu`
- **Tipiṭaka** — `luật`
- **Tools / WordList** — `"$documentTitle" — ${tp.lines.length} dòng`
- **Tools / WordList** — `$_correct / $_total đúng`
- **Tools / WordList** — `$pct% đã ôn tập`
- **Tools / WordList** — `$value ký tự`
- **Tools / WordList** — `${_selectedIds.length} đã chọn`
- **Tools / WordList** — `${provider.blindSpots} điểm mù`
- **Tools / WordList** — `${provider.masteredCount} thành thạo`
- **Tools / WordList** — `${w.sourceFiles.length} nguồn`
- **Tools / WordList** — `${widget.tools.where((t) => t.isAvailable).length} tính năng`
- **Tools / WordList** — `${words.length} từ tìm thấy · $selectedCount được chọn`
- **Tools / WordList** — `(${displayWords.length} từ)`
- **Tools / WordList** — `Chọn từ/cụm muốn lưu riêng từ "${parent.word}"`
- **Tools / WordList** — `Gặp lần $encounterCount!`
- **Tools / WordList** — `Import $count từ vào danh sách`
- **Tools / WordList** — `Không có từ nào cần ôn ${context.uiText(_skillName(_currentSkill!))}!`
- **Tools / WordList** — `Lưu ${selWords.length + selPhrases.length} mục`
- **Tools / WordList** — `Lưu từ: "$word"`
- **Tools / WordList** — `Lỗi đọc file: $e`
- **Tools / WordList** — `Ngữ cảnh (${entry.contexts.length})`
- **Tools / WordList** — `Thuần thục: ${(word.mastery * 100).toInt()}%`
- **Tools / WordList** — `Tất cả (${displayWords.length} từ)`
- **Tools / WordList** — `Tối thiểu $_minLength ký tự`
- **Tools / WordList** — `Ví dụ phức: ${data[`
- **Tools / WordList** — `Ví dụ đơn: ${data[`
- **Tools / WordList** — `Vòng ${_playbackService.listRepeatCurrent}/${_playbackService.listRepeatCount}`
- **Tools / WordList** — `Vòng ${_playbackService.listRepeatCurrent}/∞`
- **Tools / WordList** — `hình`
- **Tools / WordList** — `hình ảnh`
- **Tools / WordList** — `minh họa`
- **Tools / WordList** — `sai $wrong/${w.totalReviews} lần`
- **Tools / WordList** — `Ôn tập: ${context.uiText(_skillName(skill)).toUpperCase()}`
- **Tools / WordList** — `Đánh giá: ${context.uiText(_skillName(skill))}`
- **Tools / WordList** — `Đã lưu "$word" vào Tools`
- **Tools / WordList** — `Đã lưu ${ui.uiText(typeLabel)}: $text`
- **Tools / WordList** — `ảnh`
- **Tools / WordList** — `ảnh minh họa`
- **Tools / WordList** — `✅ Đã tạo ${selWords.length + selPhrases.length} entry con`
- **Tools / WordList** — `🌱 "${entry.word}" đã được gieo trong vườn nhớ rồi!`
- **Tools / WordList** — `🌱 Đã gieo mầm "${entry.word}" vào vườn trí nhớ!`
- **Tools / WordList** — `📅 Lần tới: ${entry.daysUntilDue} ngày nữa`
- **Tools / WordList** — `📌 Gặp nhiều lần (${frequent.length})`
- **Translation** — `$base (cặp nguồn đã chọn)`
- **Translation** — `$base (nguồn tự nhận diện — kiểm tra lại ngôn ngữ nguồn)`
- **Translation** — `${language.flag} Đã đổi bản dịch và giọng đọc sang ${language.nativeName}`
- **Translation** — `${language.nativeName} • ngôn ngữ nguồn`
- **Translation** — `File Hy-MT $issue: $path — bấm "Tải về" để tải lại file đầy đủ hoặc chọn đúng model Hy-MT GGUF.`
- **Translation** — `Hy-MT không hỗ trợ cặp $sourceLang → $targetLang`
- **Translation** — `Hy-MT trả về rỗng cho segment ${chunkIndex + 1}/$chunkCount`
- **Translation** — `Isolate Hy-MT không còn sống: ${_deathError ?? `
- **Translation** — `Isolate Hy-MT đã chết: ${error == null ? `
- **Translation** — `Không có heartbeat trong ${_pingTimeout.inSeconds}s`
- **Translation** — `Không tải được Hy-MT (HTTP ${e.response?.statusCode ?? `
- **Translation** — `Lỗi ML Kit: $e`
- **Translation** — `Lỗi tải Hy-MT: $e`
- **Translation** — `Lỗi tải gói $code`
- **Translation** — `ML Kit không hỗ trợ cặp $source → $target`
- **Translation** — `Model Hy-MT tải về $issue`
- **Translation** — `Rate limited (429) tại $server`
- **Translation** — `Server $server yêu cầu API key`
- **Translation** — `Timeout ML Kit sau 30 giây`
- **Translation** — `Timeout sau 12 giây`
- **Translation** — `Tự nhận diện ${sourceLanguage.nativeName} → ${targetLanguage.nativeName}`
- **Translation** — `[đĐơƠưƯạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹýàáảãạèéẻẽẹ`
- **Translation** — `bị cắt ($mb MB; cần khoảng 601 MB)`
- **Translation** — `không đọc được file ($e)`
- **Translation** — `không đọc được file (${e.osError?.message ?? e.message})`
- **Translation** — `model trả rỗng cho segment ${chunkIndex + 1}/$chunkCount`
- **Translation** — `mất slot glossary $lost ở segment ${chunkIndex + 1}/$chunkCount`
- **Translation** — `việt`
- **Translation** — `}). Wi-Fi rồi thử lại.`
- **Translation** — `}. Thử "Tải về" lại model rồi dịch lại.`
- **Translation** — `ìíỉĩịòóỏõọùúủũụ]`
- **Translation** — `Đã nhận diện ${widget.sourceLanguage.flag} ${widget.sourceLanguage.nativeName} • ${AppLanguageCatalog.languages.length} ngôn ngữ đích`
- **Translation** — `Đã tải gói $code`
- **Translation** — `ℹ️ LLM API: chưa cấu hình provider cho dịch LLM (màn Server & API) hoặc routing "Dịch" đang "Chỉ offline" — bỏ qua lớp LLM, dùng engine khác. (thông báo này chỉ in 1 lần)`
- **Translation** — `🧩 Hỗn hợp ngôn ngữ · ${engines.join(`
- **Understand** — `Dừng (${_formatDuration(shadowing.recordingDuration)})`
- **Understand** — `Đếm: ${shadowing.countdown}`
- **Video library** — `Quyền đọc thư mục đã mất (do gỡ hoặc cập nhật app). Chạm "Chọn thư mục khác" để cấp lại quyền.`
- **Web Reader** — `$draftCount batch nháp`
- **Web Reader** — `$noteCount ghi chú`
- **Web Reader** — `$pinnedArticleCount bài ghim`
- **Web Reader** — `$resumeCount tiếp tục`
- **Web Reader** — `$selectedCount đã chọn`
- **Web Reader** — `$statusCount theo bộ lọc`
- **Web Reader** — `${_candidates.length} ứng viên`
- **Web Reader** — `${analyzed!.encounterCount} lần gặp`
- **Web Reader** — `${collection.linkCount} liên kết`
- **Web Reader** — `${currentCollection.linkCount} liên kết`
- **Web Reader** — `${diff.inDays} ngày trước`
- **Web Reader** — `${diff.inHours} giờ trước`
- **Web Reader** — `${diff.inMinutes} phút trước`
- **Web Reader** — `${draft.candidates.length} mục`
- **Web Reader** — `).length} dòng`
- **Web Reader** — `Batch nháp · ${draftBatches.length}`
- **Web Reader** — `Bài có ghi chú · ${notedArticles.length}`
- **Web Reader** — `Bài đã ghim · ${pinnedArticles.length}`
- **Web Reader** — `Bộ sưu tập có sẵn · ${presetCollections.length}`
- **Web Reader** — `Cập nhật ${context.uiText(_HistoryTile._formatVisitedAt(draft.updatedAt))}`
- **Web Reader** — `Ghi chú · ${_controller.pageTitle.isEmpty ? _controller.currentUrl : _controller.pageTitle}`
- **Web Reader** — `Ghi chú · ${entry.title.isEmpty ? entry.url : entry.title}`
- **Web Reader** — `Mới $_newCount`
- **Web Reader** — `Mới mở · ${context.uiText(_HistoryTile._formatVisitedAt(entry.effectiveReadAt))}`
- **Web Reader** — `Nhóm "${collection.title}" sẽ bị xoá, nhưng các preset mặc định và lịch sử duyệt sẽ không bị ảnh hưởng.`
- **Web Reader** — `Nhóm của tôi · ${userCollections.length}`
- **Web Reader** — `Nhập $_selectedCount mục vào WordList`
- **Web Reader** — `Nhập $_selectedReadyCount mục sẵn sàng`
- **Web Reader** — `Ready đã chọn: $_selectedReadyCount`
- **Web Reader** — `Sẵn sàng $_readyCount`
- **Web Reader** — `Thiếu: ${missing.join(`
- **Web Reader** — `Tiến độ ~ ${entry.progressPercent}%`
- **Web Reader** — `Tiếp tục đọc · ${resumeEntries.length}`
- **Web Reader** — `Trang này đã có sẵn trong nhóm "${collection.title}"`
- **Web Reader** — `Trang này đã có sẵn trong nhóm "${currentCollection.title}"`
- **Web Reader** — `Trích đoạn · $sourceLabel`
- **Web Reader** — `Trích đoạn · ${_controller.pageTitle.isEmpty ? _controller.currentUrl : _controller.pageTitle}`
- **Web Reader** — `Xem tất cả ${collection.linkCount} link`
- **Web Reader** — `Đang lọc: “$queryLabel”`
- **Web Reader** — `Đang đọc ${entry.progressPercent}%`
- **Web Reader** — `Đã chọn $_selectedCount`
- **Web Reader** — `Đã chọn: $_selectedCount`
- **Web Reader** — `Đã có $_existingCount`
- **Web Reader** — `Đã enrich $_enrichedCount`
- **Web Reader** — `Đã lưu nhanh · ${bookmarks.length}`
- **Web Reader** — `Đã lưu trang hiện tại vào nhóm "${currentCollection.title}"`
- **Web Reader** — `Đã phân loại $_selectedClassifiedCount / $_selectedCount`
- **Web Reader** — `Đã đánh giá $_classifiedCount`
- **Web Reader** — `Độ khó đã lưu: ${context.uiText(analyzed!.userDifficulty!.label)}`
- **Web Reader** — `Ưu tiên $_priorityCount`
- **Web Reader** — `✅ Đã load vào Text Studio — ${text.split(`
- **Web Reader** — `✅ Đã lưu "$cleanWord" vào Vườn Nhớ`
- **Web Reader** — `✅ Đã lưu vào nhóm "${collection.title}"`
- **Web Reader** — `📚 Đã bổ sung ngữ cảnh cho "$cleanWord" trong WordList`
- **Web Reader** — `📚 Đã thêm "$cleanWord" vào WordList`
- **Web Reader** — `🛠️ Đã áp dụng bulk fields cho ${targets.length} mục`
- **YouTube** — `$ext · ${kbps}kbps (chọn thủ công)`
- **YouTube** — `$v lượt xem`
- **YouTube** — `${(v / 1000).toStringAsFixed(0)}K lượt xem`
- **YouTube** — `${(v / 1000000).toStringAsFixed(1)}M lượt xem`
- **YouTube** — `${_captions.length} dòng`
- **YouTube** — `${d.inDays ~/ 365} năm trước`
- **YouTube** — `${d.inDays} ngày trước`
- **YouTube** — `Chuẩn bị · ${kbps}kbps · ${_sizeLabel(totalBytes)}`
- **YouTube** — `Không có captions cho "$_lang".
Thử ngôn ngữ khác.`
- **YouTube** — `Lấy captions ($_lang)`
- **YouTube** — `Lỗi tải phụ đề: $e`
- **YouTube** — `Tải thất bại: ${event.message}`
- **YouTube** — `YouTube từ chối phát video này (lỗi cấu hình trình phát, mã $code). Bấm Thử lại, hoặc Mở ngoài để xem trong trình duyệt.`
- **YouTube** — `yt-dlp lỗi: $e`
- **YouTube** — `Đã chờ ${_waitedSec}s. AI chạy trên máy nên có thể mất 30–90 giây.`
- **YouTube** — `Đã lưu phụ đề (${lines.length} dòng): ${path ?? "?"}`
- **YouTube** — `Đã lưu phụ đề vào: $folder`
- **YouTube** — `Đã tải xong (${event.quality})`
- **YouTube** — `✅ [in4up-yt] tải xong $received / $totalBytes bytes (số lần nối: $attempt)`
- **YouTube** — `❌ [in4up-yt] tải chưa hoàn tất: $got / $totalBytes bytes sau $_maxAttempts lần thử.`

