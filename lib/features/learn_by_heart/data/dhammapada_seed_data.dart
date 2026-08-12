// lib/features/learn_by_heart/data/dhammapada_seed_data.dart

import '../models/chunk.dart';
import '../models/learn_by_heart_item.dart';
import '../models/line_timestamp.dart';
import '../models/recitation_category.dart';
import '../models/review_state.dart';

/// Bộ dữ liệu hạt giống chuẩn hóa (Dhammapada 1-10 & Kinh tụng cốt lõi)
class DhammapadaSeedData {
  static List<LearnByHeartItem> getInitialItems() {
    final now = DateTime.now();

    return [
      // ════════════════════════════════════════════════════════════
      // 1. KỆ PHÁP CÚ 01 (Song Yếu - Cỗ xe & Bánh xe)
      // ════════════════════════════════════════════════════════════
      LearnByHeartItem(
        id: 'dhp_001',
        title: 'Kệ Pháp Cú 01: Song Yếu (Yamakavagga)',
        subtitle: 'Tâm dẫn đầu các pháp (Nghiệp ác)',
        category: RecitationCategory.dhammapada,
        paliText:
            'Manopubbaṅgamā dhammā,\nmanoseṭṭhā manomayā;\nManasā ce paduṭṭhena,\nbhāsati vā karoti vā;\nTato naṁ dukkhamanveti,\ncakkaṁva vahato padam.',
        vietnameseText:
            'Ý dẫn đầu các pháp,\nÝ làm chủ, ý tạo;\nNếu với ý ô nhiễm,\nNói lên hay hành động,\nKhổ não bước theo sau,\nNhư xe chân vật kéo.',
        shortMeaning: 'Hành động từ tâm ô nhiễm dẫn đến khổ đau như bánh xe theo chân bò.',
        keywords: ['Ý dẫn đầu', 'Ý ô nhiễm', 'Khổ não'],
        lifeConnection: 'Khi khởi tâm bực bội, hãy dừng lại trước khi nói hoặc làm để tránh quả đắng.',
        lineTimestamps: const [
          LineTimestamp(line: 1, start: 0.0, end: 2.8, text: 'Ý dẫn đầu các pháp,', paliText: 'Manopubbaṅgamā dhammā,'),
          LineTimestamp(line: 2, start: 2.8, end: 5.6, text: 'Ý làm chủ, ý tạo;', paliText: 'manoseṭṭhā manomayā;'),
          LineTimestamp(line: 3, start: 5.6, end: 8.4, text: 'Nếu với ý ô nhiễm,', paliText: 'Manasā ce paduṭṭhena,'),
          LineTimestamp(line: 4, start: 8.4, end: 11.2, text: 'Nói lên hay hành động,', paliText: 'bhāsati vā karoti vā;'),
          LineTimestamp(line: 5, start: 11.2, end: 14.0, text: 'Khổ não bước theo sau,', paliText: 'Tato naṁ dukkhamanveti,'),
          LineTimestamp(line: 6, start: 14.0, end: 17.2, text: 'Như xe chân vật kéo.', paliText: 'cakkaṁva vahato padam.'),
        ],
        chunkList: const [
          Chunk(index: 1, label: 'Khởi đầu: Vai trò của Tâm', lineRange: [1, 2], clue: 'Tâm dẫn đầu và làm chủ muôn việc', keywords: ['Ý dẫn đầu', 'Ý làm chủ']),
          Chunk(index: 2, label: 'Nhân: Tâm ô nhiễm', lineRange: [3, 4], clue: 'Nói hoặc làm với tâm bất thiện', keywords: ['Ý ô nhiễm', 'Hành động']),
          Chunk(index: 3, label: 'Quả: Khổ đau kéo theo', lineRange: [5, 6], clue: 'Khổ não đi theo như xe theo chân kéo', keywords: ['Khổ não', 'Xe chân vật kéo']),
        ],
        createdAt: now.subtract(const Duration(days: 2)),
        reviewState: ReviewState.newItem,
      ),

      // ════════════════════════════════════════════════════════════
      // 2. KỆ PHÁP CÚ 02 (Song Yếu - Bóng không rời hình)
      // ════════════════════════════════════════════════════════════
      LearnByHeartItem(
        id: 'dhp_002',
        title: 'Kệ Pháp Cú 02: Song Yếu (Yamakavagga)',
        subtitle: 'Tâm thanh tịnh (Nghiệp thiện)',
        category: RecitationCategory.dhammapada,
        paliText:
            'Manopubbaṅgamā dhammā,\nmanoseṭṭhā manomayā;\nManasā ce pasannena,\nbhāsati vā karoti vā;\nTato naṁ sukhamanveti,\nchāyāva anapāyinī.',
        vietnameseText:
            'Ý dẫn đầu các pháp,\nÝ làm chủ, ý tạo;\nNếu với ý thanh tịnh,\nNói lên hay hành động,\nAn lạc bước theo sau,\nNhư bóng không rời hình.',
        shortMeaning: 'Hành động từ tâm thanh tịnh đem lại an lạc như bóng theo hình.',
        keywords: ['Ý thanh tịnh', 'An lạc', 'Bóng không rời hình'],
        lifeConnection: 'Giữ tâm trong sáng, từ ái trong từng việc nhỏ sẽ tự nhiên gặt hái bình an.',
        lineTimestamps: const [
          LineTimestamp(line: 1, start: 0.0, end: 2.8, text: 'Ý dẫn đầu các pháp,', paliText: 'Manopubbaṅgamā dhammā,'),
          LineTimestamp(line: 2, start: 2.8, end: 5.6, text: 'Ý làm chủ, ý tạo;', paliText: 'manoseṭṭhā manomayā;'),
          LineTimestamp(line: 3, start: 5.6, end: 8.4, text: 'Nếu với ý thanh tịnh,', paliText: 'Manasā ce pasannena,'),
          LineTimestamp(line: 4, start: 8.4, end: 11.2, text: 'Nói lên hay hành động,', paliText: 'bhāsati vā karoti vā;'),
          LineTimestamp(line: 5, start: 11.2, end: 14.0, text: 'An lạc bước theo sau,', paliText: 'Tato naṁ sukhamanveti,'),
          LineTimestamp(line: 6, start: 14.0, end: 17.2, text: 'Như bóng không rời hình.', paliText: 'chāyāva anapāyinī.'),
        ],
        chunkList: const [
          Chunk(index: 1, label: 'Khởi nguồn: Tâm là gốc', lineRange: [1, 2], clue: 'Tâm dẫn dắt muôn pháp', keywords: ['Ý dẫn đầu', 'Ý làm chủ']),
          Chunk(index: 2, label: 'Nhân: Tâm thanh tịnh', lineRange: [3, 4], clue: 'Hành vi xuất phát từ sự trong lành', keywords: ['Ý thanh tịnh', 'Hành động']),
          Chunk(index: 3, label: 'Quả: An lạc kề bên', lineRange: [5, 6], clue: 'Hạnh phúc như bóng theo hình', keywords: ['An lạc', 'Bóng không rời hình']),
        ],
        createdAt: now.subtract(const Duration(days: 1)),
        reviewState: ReviewState.newItem,
      ),

      // ════════════════════════════════════════════════════════════
      // 3. KỆ PHÁP CÚ 03 (Nuôi dưỡng hận thù)
      // ════════════════════════════════════════════════════════════
      LearnByHeartItem(
        id: 'dhp_003',
        title: 'Kệ Pháp Cú 03: Song Yếu (Yamakavagga)',
        subtitle: 'Tâm ôm giữ oán hờn',
        category: RecitationCategory.dhammapada,
        paliText:
            'Akkocchi maṁ avadhi maṁ,\najini maṁ ahāsi me;\nYe taṁ upanayhanti,\nveraṁ tesaṁ na sammati.',
        vietnameseText:
            'Nó mắng tôi, đánh tôi,\nNó thắng tôi, cướp tôi;\nAi ôm hiềm hận ấy,\nHận thù không thể nguôi.',
        shortMeaning: 'Ôm giữ ý nghĩ bị tổn hại thì oán hận không bao giờ dứt.',
        keywords: ['Ôm hiềm hận', 'Hận thù', 'Không thể nguôi'],
        lifeConnection: 'Nhắc lại lỗi lầm người khác chỉ làm tổn thương chính bản thân mình.',
        lineTimestamps: const [
          LineTimestamp(line: 1, start: 0.0, end: 3.0, text: 'Nó mắng tôi, đánh tôi,', paliText: 'Akkocchi maṁ avadhi maṁ,'),
          LineTimestamp(line: 2, start: 3.0, end: 6.0, text: 'Nó thắng tôi, cướp tôi;', paliText: 'ajini maṁ ahāsi me;'),
          LineTimestamp(line: 3, start: 6.0, end: 9.0, text: 'Ai ôm hiềm hận ấy,', paliText: 'Ye taṁ upanayhanti,'),
          LineTimestamp(line: 4, start: 9.0, end: 12.5, text: 'Hận thù không thể nguôi.', paliText: 'veraṁ tesaṁ na sammati.'),
        ],
        chunkList: const [
          Chunk(index: 1, label: 'Ý niệm bị hại', lineRange: [1, 2], clue: 'Nghĩ rằng bị mắng, đánh, cướp', keywords: ['Mắng tôi', 'Cướp tôi']),
          Chunk(index: 2, label: 'Hậu quả chấp giữ', lineRange: [3, 4], clue: 'Nuôi dưỡng hận thì hận không nguôi', keywords: ['Ôm hiềm hận', 'Hận thù']),
        ],
        createdAt: now,
        reviewState: ReviewState.newItem,
      ),

      // ════════════════════════════════════════════════════════════
      // 4. KỆ PHÁP CÚ 04 (Buông bỏ oán hờn)
      // ════════════════════════════════════════════════════════════
      LearnByHeartItem(
        id: 'dhp_004',
        title: 'Kệ Pháp Cú 04: Song Yếu (Yamakavagga)',
        subtitle: 'Buông xả hiềm oán',
        category: RecitationCategory.dhammapada,
        paliText:
            'Akkocchi maṁ avadhi maṁ,\najini maṁ ahāsi me;\nYe taṁ na upanayhanti,\nveraṁ tesūpasammati.',
        vietnameseText:
            'Nó mắng tôi, đánh tôi,\nNó thắng tôi, cướp tôi;\nKhông ôm hiềm hận ấy,\nHận thù tự lắng xuôi.',
        shortMeaning: 'Không chấp chứa oán hờn thì hận thù tự nhiên tiêu tan.',
        keywords: ['Không ôm hiềm hận', 'Lắng xuôi', 'Tự nguôi'],
        lifeConnection: 'Tha thứ cho người khác là giải thoát cho chính tâm hồn mình.',
        lineTimestamps: const [
          LineTimestamp(line: 1, start: 0.0, end: 3.0, text: 'Nó mắng tôi, đánh tôi,', paliText: 'Akkocchi maṁ avadhi maṁ,'),
          LineTimestamp(line: 2, start: 3.0, end: 6.0, text: 'Nó thắng tôi, cướp tôi;', paliText: 'ajini maṁ ahāsi me;'),
          LineTimestamp(line: 3, start: 6.0, end: 9.0, text: 'Không ôm hiềm hận ấy,', paliText: 'Ye taṁ na upanayhanti,'),
          LineTimestamp(line: 4, start: 9.0, end: 12.5, text: 'Hận thù tự lắng xuôi.', paliText: 'veraṁ tesūpasammati.'),
        ],
        chunkList: const [
          Chunk(index: 1, label: 'Thực tế nghịch cảnh', lineRange: [1, 2], clue: 'Nghịch cảnh bên ngoài xảy ra', keywords: ['Mắng tôi', 'Thắng tôi']),
          Chunk(index: 2, label: 'Trí tuệ buông bỏ', lineRange: [3, 4], clue: 'Không chấp giữ thì hận tự tan', keywords: ['Không ôm hiềm hận', 'Lắng xuôi']),
        ],
        createdAt: now,
        reviewState: ReviewState.newItem,
      ),

      // ════════════════════════════════════════════════════════════
      // 5. KỆ PHÁP CÚ 05 (Lấy tình thương hóa giải hận thù)
      // ════════════════════════════════════════════════════════════
      LearnByHeartItem(
        id: 'dhp_005',
        title: 'Kệ Pháp Cú 05: Song Yếu (Yamakavagga)',
        subtitle: 'Định luật ngàn đời (Hận diệt hận)',
        category: RecitationCategory.dhammapada,
        paliText:
            'Na hi verena verāni,\nsammantīdha kudācanaṁ;\nAverena ca sammanti,\nesa dhammo sanantano.',
        vietnameseText:
            'Hận thù diệt hận thù,\nĐời này không thể có;\nTừ bi diệt hận thù,\nLà định luật ngàn thu.',
        shortMeaning: 'Hận thù chỉ có thể được dập tắt bằng tình thương, đó là chân lý muôn đời.',
        keywords: ['Từ bi', 'Diệt hận thù', 'Định luật ngàn thu'],
        lifeConnection: 'Khi gặp xung đột, dùng sự nhẫn nại và thấu hiểu thay vì hơn thua trả đũa.',
        lineTimestamps: const [
          LineTimestamp(line: 1, start: 0.0, end: 3.0, text: 'Hận thù diệt hận thù,', paliText: 'Na hi verena verāni,'),
          LineTimestamp(line: 2, start: 3.0, end: 6.0, text: 'Đời này không thể có;', paliText: 'sammantīdha kudācanaṁ;'),
          LineTimestamp(line: 3, start: 6.0, end: 9.0, text: 'Từ bi diệt hận thù,', paliText: 'Averena ca sammanti,'),
          LineTimestamp(line: 4, start: 9.0, end: 12.5, text: 'Là định luật ngàn thu.', paliText: 'esa dhammo sanantano.'),
        ],
        chunkList: const [
          Chunk(index: 1, label: 'Sự thật về hận thù', lineRange: [1, 2], clue: 'Oán không thể giải được oán', keywords: ['Hận thù', 'Không thể có']),
          Chunk(index: 2, label: 'Chân lý từ bi', lineRange: [3, 4], clue: 'Từ bi là chìa khóa ngàn đời', keywords: ['Từ bi', 'Định luật ngàn thu']),
        ],
        createdAt: now,
        reviewState: ReviewState.newItem,
      ),

      // ════════════════════════════════════════════════════════════
      // 6. KỆ PHÁP CÚ 06 (Ý thức về sự vô thường)
      // ════════════════════════════════════════════════════════════
      LearnByHeartItem(
        id: 'dhp_006',
        title: 'Kệ Pháp Cú 06: Song Yếu (Yamakavagga)',
        subtitle: 'Ý thức sự chết chấm dứt tranh chấp',
        category: RecitationCategory.dhammapada,
        paliText:
            'Pare ca na vijānanti,\nmayamettha yamāmase;\nYe ca tattha vijānanti,\ntato sammanti medhagā.',
        vietnameseText:
            'Người khác không nhận thức,\nChúng ta sẽ bị diệt;\nAi nhận thức điều ấy,\nTranh luận liền lắng yên.',
        shortMeaning: 'Nhận thức đời sống ngắn ngủi giúp con người chấm dứt tranh cãi hơn thua.',
        keywords: ['Chúng ta sẽ diệt', 'Nhận thức', 'Tranh luận lắng yên'],
        lifeConnection: 'Nhớ rằng ai rồi cũng qua đời để trân trọng nhau và bớt tranh giành.',
        lineTimestamps: const [
          LineTimestamp(line: 1, start: 0.0, end: 3.0, text: 'Người khác không nhận thức,', paliText: 'Pare ca na vijānanti,'),
          LineTimestamp(line: 2, start: 3.0, end: 6.0, text: 'Chúng ta sẽ bị diệt;', paliText: 'mayamettha yamāmase;'),
          LineTimestamp(line: 3, start: 6.0, end: 9.0, text: 'Ai nhận thức điều ấy,', paliText: 'Ye ca tattha vijānanti,'),
          LineTimestamp(line: 4, start: 9.0, end: 12.5, text: 'Tranh luận liền lắng yên.', paliText: 'tato sammanti medhagā.'),
        ],
        chunkList: const [
          Chunk(index: 1, label: 'Sự mê lầm', lineRange: [1, 2], clue: 'Quên mất lẽ vô thường', keywords: ['Không nhận thức', 'Bị diệt']),
          Chunk(index: 2, label: 'Sự thức tỉnh', lineRange: [3, 4], clue: 'Hiểu lẽ vô thường dập tắt tranh cãi', keywords: ['Nhận thức', 'Tranh luận lắng yên']),
        ],
        createdAt: now,
        reviewState: ReviewState.newItem,
      ),

      // ════════════════════════════════════════════════════════════
      // 7. KỆ PHÁP CÚ 07 (Cây yếu trước cuồng phong)
      // ════════════════════════════════════════════════════════════
      LearnByHeartItem(
        id: 'dhp_007',
        title: 'Kệ Pháp Cú 07: Song Yếu (Yamakavagga)',
        subtitle: 'Sống buông thả dễ bị khuất phục',
        category: RecitationCategory.dhammapada,
        paliText:
            'Subhānupassiṁ viharantaṁ,\nindriyesu asaṁvutaṁ;\nMattaññuṁ cābhojanamhi,\nkusītaṁ hīnavīriyaṁ;\nTaṁ ve pasahati māro,\nvāto rukkhaṁva dubbalaṁ.',
        vietnameseText:
            'Ai sống nhìn tịnh tướng,\nKhông hộ trì các căn,\nĂn uống vô độ lượng,\nBiếng nhác chẳng tinh cần;\nMa vương dễ khuất phục,\nNhư gió thổi cây non.',
        shortMeaning: 'Người sống buông thả dục vọng và biếng nhác dễ bị cám dỗ quật ngã.',
        keywords: ['Không hộ trì', 'Biếng nhác', 'Gió thổi cây non'],
        lifeConnection: 'Tập kiểm soát thói quen ăn uống, lướt mạng xã hội để rèn bản lĩnh kiên cường.',
        lineTimestamps: const [
          LineTimestamp(line: 1, start: 0.0, end: 2.8, text: 'Ai sống nhìn tịnh tướng,', paliText: 'Subhānupassiṁ viharantaṁ,'),
          LineTimestamp(line: 2, start: 2.8, end: 5.6, text: 'Không hộ trì các căn,', paliText: 'indriyesu asaṁvutaṁ;'),
          LineTimestamp(line: 3, start: 5.6, end: 8.4, text: 'Ăn uống vô độ lượng,', paliText: 'Mattaññuṁ cābhojanamhi,'),
          LineTimestamp(line: 4, start: 8.4, end: 11.2, text: 'Biếng nhác chẳng tinh cần;', paliText: 'kusītaṁ hīnavīriyaṁ;'),
          LineTimestamp(line: 5, start: 11.2, end: 14.0, text: 'Ma vương dễ khuất phục,', paliText: 'Taṁ ve pasahati māro,'),
          LineTimestamp(line: 6, start: 14.0, end: 17.0, text: 'Như gió thổi cây non.', paliText: 'vāto rukkhaṁva dubbalaṁ.'),
        ],
        chunkList: const [
          Chunk(index: 1, label: 'Thói quen buông thả', lineRange: [1, 2, 3], clue: 'Nhìn dục lạc, không phòng hộ, ăn uống quá độ', keywords: ['Nhìn tịnh tướng', 'Không hộ trì']),
          Chunk(index: 2, label: 'Hậu quả suy sụp', lineRange: [4, 5, 6], clue: 'Thiếu ý chí nên dễ bị lay chuyển', keywords: ['Biếng nhác', 'Ma vương', 'Cây non']),
        ],
        createdAt: now,
        reviewState: ReviewState.newItem,
      ),

      // ════════════════════════════════════════════════════════════
      // 8. KỆ PHÁP CÚ 08 (Đá tảng trước gió)
      // ════════════════════════════════════════════════════════════
      LearnByHeartItem(
        id: 'dhp_008',
        title: 'Kệ Pháp Cú 08: Song Yếu (Yamakavagga)',
        subtitle: 'Sống tỉnh giác kiên cố như núi đá',
        category: RecitationCategory.dhammapada,
        paliText:
            'Asubhānupassiṁ viharantaṁ,\nindriyesu susaṁvutaṁ;\nMattaññuṁ ca bhojanamhi,\nsaddhaṁ āraddhavīriyaṁ;\nTaṁ ve nappasahati māro,\nvāto selaṁva pabbataṁ.',
        vietnameseText:
            'Ai sống quán bất tịnh,\nKhéo hộ trì các căn,\nĂn uống có tiết độ,\nCó lòng tin, tinh cần;\nMa vương không chuyển nổi,\nNhư gió thổi núi đá.',
        shortMeaning: 'Người có chánh niệm, hộ trì giác quan và tinh tấn thì vững chãi trước cám dỗ.',
        keywords: ['Khéo hộ trì', 'Có lòng tin', 'Gió thổi núi đá'],
        lifeConnection: 'Giữ kỷ luật bản thân và niềm tin kiên định giúp ta đứng vững trước sóng gió.',
        lineTimestamps: const [
          LineTimestamp(line: 1, start: 0.0, end: 2.8, text: 'Ai sống quán bất tịnh,', paliText: 'Asubhānupassiṁ viharantaṁ,'),
          LineTimestamp(line: 2, start: 2.8, end: 5.6, text: 'Khéo hộ trì các căn,', paliText: 'indriyesu susaṁvutaṁ;'),
          LineTimestamp(line: 3, start: 5.6, end: 8.4, text: 'Ăn uống có tiết độ,', paliText: 'Mattaññuṁ ca bhojanamhi,'),
          LineTimestamp(line: 4, start: 8.4, end: 11.2, text: 'Có lòng tin, tinh cần;', paliText: 'saddhaṁ āraddhavīriyaṁ;'),
          LineTimestamp(line: 5, start: 11.2, end: 14.0, text: 'Ma vương không chuyển nổi,', paliText: 'Taṁ ve nappasahati māro,'),
          LineTimestamp(line: 6, start: 14.0, end: 17.0, text: 'Như gió thổi núi đá.', paliText: 'vāto selaṁva pabbataṁ.'),
        ],
        chunkList: const [
          Chunk(index: 1, label: 'Nếp sống kỷ luật', lineRange: [1, 2, 3], clue: 'Phòng hộ căn, tiết độ ăn uống', keywords: ['Quán bất tịnh', 'Khéo hộ trì']),
          Chunk(index: 2, label: 'Sức mạnh kiên định', lineRange: [4, 5, 6], clue: 'Lòng tin và tinh tấn vững như núi đá', keywords: ['Tinh cần', 'Không chuyển nổi', 'Núi đá']),
        ],
        createdAt: now,
        reviewState: ReviewState.newItem,
      ),

      // ════════════════════════════════════════════════════════════
      // 9. KỆ PHÁP CÚ 09 (Mặc áo cà sa bất xứng)
      // ════════════════════════════════════════════════════════════
      LearnByHeartItem(
        id: 'dhp_009',
        title: 'Kệ Pháp Cú 09: Song Yếu (Yamakavagga)',
        subtitle: 'Chưa thanh lọc tâm mà khoác áo đạo',
        category: RecitationCategory.dhammapada,
        paliText:
            'Anikkasāvo kāsāvaṁ,\nyo vatthaṁ paridahessati;\nApeto damasaccena,\nna so kāsāvamarahati.',
        vietnameseText:
            'Ai mặc áo cà sa,\nTâm chưa rời uế trược,\nKhông tự chế, chân thật,\nKhông xứng áo cà sa.',
        shortMeaning: 'Hình tướng bên ngoài không làm nên đức hạnh nếu nội tâm còn ô nhiễm.',
        keywords: ['Áo cà sa', 'Chưa rời uế trược', 'Không xứng'],
        lifeConnection: 'Hãy chú trọng phẩm chất chân thật bên trong hơn là danh xưng hay vẻ ngoài.',
        lineTimestamps: const [
          LineTimestamp(line: 1, start: 0.0, end: 3.0, text: 'Ai mặc áo cà sa,', paliText: 'Anikkasāvo kāsāvaṁ,'),
          LineTimestamp(line: 2, start: 3.0, end: 6.0, text: 'Tâm chưa rời uế trược,', paliText: 'yo vatthaṁ paridahessati;'),
          LineTimestamp(line: 3, start: 6.0, end: 9.0, text: 'Không tự chế, chân thật,', paliText: 'Apeto damasaccena,'),
          LineTimestamp(line: 4, start: 9.0, end: 12.5, text: 'Không xứng áo cà sa.', paliText: 'na so kāsāvamarahati.'),
        ],
        chunkList: const [
          Chunk(index: 1, label: 'Tâm ô nhiễm', lineRange: [1, 2], clue: 'Mang áo đạo nhưng tâm còn bợn nhơ', keywords: ['Áo cà sa', 'Uế trược']),
          Chunk(index: 2, label: 'Sự không xứng đáng', lineRange: [3, 4], clue: 'Thiếu tự chế và chân thật', keywords: ['Không tự chế', 'Không xứng']),
        ],
        createdAt: now,
        reviewState: ReviewState.newItem,
      ),

      // ════════════════════════════════════════════════════════════
      // 10. KỆ PHÁP CÚ 10 (Người xứng đáng mặc áo cà sa)
      // ════════════════════════════════════════════════════════════
      LearnByHeartItem(
        id: 'dhp_010',
        title: 'Kệ Pháp Cú 10: Song Yếu (Yamakavagga)',
        subtitle: 'Người xứng đáng đắp y đạo nghiệp',
        category: RecitationCategory.dhammapada,
        paliText:
            'Yo ca vanta-kasāv’assa,\nsīlesu susamāhito;\nUpeto dama-saccena,\nsa ve kāsāvam-arahati.',
        vietnameseText:
            'Ai rời bỏ uế trược,\nGiới luật khéo an trú,\nBiết tự chế, chân thật,\nRất xứng áo cà sa.',
        shortMeaning: 'Người trong sạch uế trược, giữ gìn giới hạnh xứng đáng khoác áo đạo.',
        keywords: ['Rời bỏ uế trược', 'Giới luật an trú', 'Rất xứng'],
        lifeConnection: 'Lời nói và lối sống phải đi đôi với sự trung thực và chuẩn mực đạo đức.',
        lineTimestamps: const [
          LineTimestamp(line: 1, start: 0.0, end: 3.0, text: 'Ai rời bỏ uế trược,', paliText: 'Yo ca vanta-kasāv’assa,'),
          LineTimestamp(line: 2, start: 3.0, end: 6.0, text: 'Giới luật khéo an trú,', paliText: 'sīlesu susamāhito;'),
          LineTimestamp(line: 3, start: 6.0, end: 9.0, text: 'Biết tự chế, chân thật,', paliText: 'Upeto dama-saccena,'),
          LineTimestamp(line: 4, start: 9.0, end: 12.5, text: 'Rất xứng áo cà sa.', paliText: 'sa ve kāsāvam-arahati.'),
        ],
        chunkList: const [
          Chunk(index: 1, label: 'Giới hạnh thanh tịnh', lineRange: [1, 2], clue: 'Tẩy trừ bợn nhơ, giữ giới nghiêm minh', keywords: ['Rời uế trược', 'Giới luật']),
          Chunk(index: 2, label: 'Sự xứng đáng trọn vẹn', lineRange: [3, 4], clue: 'Tự chế và chân thật là nền tảng', keywords: ['Tự chế', 'Rất xứng']),
        ],
        createdAt: now,
        reviewState: ReviewState.newItem,
      ),

      // ════════════════════════════════════════════════════════════
      // 11. TAM QUY Y (Ti-Saraṇa) - Kinh tụng phổ quát
      // ════════════════════════════════════════════════════════════
      LearnByHeartItem(
        id: 'chant_tisarana',
        title: 'Tam Quy Y (Ti-Saraṇa)',
        subtitle: 'Ba nơi nương tựa vững chắc',
        category: RecitationCategory.chanting,
        paliText:
            'Buddhaṁ saraṇaṁ gacchāmi.\nDhammaṁ saraṇaṁ gacchāmi.\nSaṅghaṁ saraṇaṁ gacchāmi.\nDutiyampi Buddhaṁ saraṇaṁ gacchāmi.\nDutiyampi Dhammaṁ saraṇaṁ gacchāmi.\nDutiyampi Saṅghaṁ saraṇaṁ gacchāmi.\nTatiyampi Buddhaṁ saraṇaṁ gacchāmi.\nTatiyampi Dhammaṁ saraṇaṁ gacchāmi.\nTatiyampi Saṅghaṁ saraṇaṁ gacchāmi.',
        vietnameseText:
            'Con đem hết lòng thành kính xin quy y Phật.\nCon đem hết lòng thành kính xin quy y Pháp.\nCon đem hết lòng thành kính xin quy y Tăng.\nLần thứ nhì, con đem hết lòng quy y Phật.\nLần thứ nhì, con đem hết lòng quy y Pháp.\nLần thứ nhì, con đem hết lòng quy y Tăng.\nLần thứ ba, con đem hết lòng quy y Phật.\nLần thứ ba, con đem hết lòng quy y Pháp.\nLần thứ ba, con đem hết lòng quy y Tăng.',
        shortMeaning: 'Trọn đời nương tựa bậc Giác Ngộ, Chánh Pháp và Tăng đoàn hòa hợp.',
        keywords: ['Quy y Phật', 'Quy y Pháp', 'Quy y Tăng'],
        lifeConnection: 'Tìm về nơi nương tựa tâm linh để tâm trí luôn an định trước biến động.',
        lineTimestamps: const [
          LineTimestamp(line: 1, start: 0.0, end: 3.5, text: 'Con đem hết lòng thành kính xin quy y Phật.', paliText: 'Buddhaṁ saraṇaṁ gacchāmi.'),
          LineTimestamp(line: 2, start: 3.5, end: 7.0, text: 'Con đem hết lòng thành kính xin quy y Pháp.', paliText: 'Dhammaṁ saraṇaṁ gacchāmi.'),
          LineTimestamp(line: 3, start: 7.0, end: 10.5, text: 'Con đem hết lòng thành kính xin quy y Tăng.', paliText: 'Saṅghaṁ saraṇaṁ gacchāmi.'),
          LineTimestamp(line: 4, start: 10.5, end: 14.5, text: 'Lần thứ nhì, quy y Phật, Pháp, Tăng...', paliText: 'Dutiyampi...'),
          LineTimestamp(line: 5, start: 14.5, end: 18.5, text: 'Lần thứ ba, quy y Phật, Pháp, Tăng...', paliText: 'Tatiyampi...'),
        ],
        chunkList: const [
          Chunk(index: 1, label: 'Quy y Tam Bảo lần 1', lineRange: [1, 2, 3], clue: 'Phật - Pháp - Tăng', keywords: ['Quy y Phật', 'Quy y Pháp', 'Quy y Tăng']),
          Chunk(index: 2, label: 'Nhắc lại lần 2 & 3', lineRange: [4, 5], clue: 'Khắc sâu niềm tin kiên cố', keywords: ['Lần thứ nhì', 'Lần thứ ba']),
        ],
        createdAt: now,
        reviewState: ReviewState.newItem,
      ),

      // ════════════════════════════════════════════════════════════
      // 12. KINH TỪ BI (Karaṇīyamettā Sutta - Khởi đầu)
      // ════════════════════════════════════════════════════════════
      LearnByHeartItem(
        id: 'sutta_metta_01',
        title: 'Kinh Từ Bi (Karaṇīyamettā Sutta)',
        subtitle: 'Hạnh nguyện rải tâm từ muôn phương',
        category: RecitationCategory.sutta,
        paliText:
            'Karaṇīyamatthakusalena,\nyanta santaṁ padaṁ abhisamecca;\nSakko ujū ca sūjū ca,\nsuvaco c’assa mudu anatimānī;\nSantussako ca subharo ca,\nappakicco ca sallahukavutti.',
        vietnameseText:
            'Đây là điều nên làm,\nBởi bậc cầu an lạc:\nPhải có tài, ngay thẳng,\nThật ngay thẳng, dễ dạy,\nHiền hòa, không kiêu mạn,\nBiết đủ, dễ nuôi dưỡng,\nÍt việc, sống thanh bần.',
        shortMeaning: 'Những phẩm chất cần thiết của người tìm cầu an lạc và rải tâm từ.',
        keywords: ['Ngay thẳng', 'Hiền hòa', 'Sống thanh bần'],
        lifeConnection: 'Đơn giản hóa cuộc sống, hạ bớt bản ngã để tâm luôn rộng mở tình thương.',
        lineTimestamps: const [
          LineTimestamp(line: 1, start: 0.0, end: 3.0, text: 'Đây là điều nên làm, bởi bậc cầu an lạc:', paliText: 'Karaṇīyamatthakusalena...'),
          LineTimestamp(line: 2, start: 3.0, end: 6.5, text: 'Phải có tài, ngay thẳng, thật ngay thẳng, dễ dạy,', paliText: 'Sakko ujū ca sūjū ca, suvaco...'),
          LineTimestamp(line: 3, start: 6.5, end: 10.0, text: 'Hiền hòa, không kiêu mạn, biết đủ, dễ nuôi dưỡng,', paliText: 'Mudu anatimānī, Santussako ca subharo ca,'),
          LineTimestamp(line: 4, start: 10.0, end: 13.5, text: 'Ít việc, sống thanh bần.', paliText: 'Appakicco ca sallahukavutti.'),
        ],
        chunkList: const [
          Chunk(index: 1, label: 'Mục đích & Đức tính căn bản', lineRange: [1, 2], clue: 'Ngay thẳng, dễ bảo', keywords: ['Bậc cầu an lạc', 'Ngay thẳng']),
          Chunk(index: 2, label: 'Phẩm hạnh khiêm tốn', lineRange: [3, 4], clue: 'Không kiêu ngạo, sống thanh đạm', keywords: ['Hiền hòa', 'Biết đủ', 'Thanh bần']),
        ],
        createdAt: now,
        reviewState: ReviewState.newItem,
      ),
    ];
  }
}
