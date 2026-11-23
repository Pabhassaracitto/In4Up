"""GLIB-008 — nội dung VocabPack seed (10 pack EN→VI, tự soạn tuyển chọn).

Mỗi entry: {word*, meaning*, phonetic?, example?, audio?, image?}
khớp data/entries.json schema GLIB-005. Nghĩa VI tự soạn (CC0). Trường
`audio` trỏ media/<slug>.mp3 — file được TTS bulk pipeline của app sinh 1 lần
lúc soạn trên máy chủ (không chạy trong sandbox) rồi đóng gói; validator
bỏ qua media/audio vì seed v1 chưa kèm (xem README — v1 text-only audio ref).

TODO(nguồn mở): khi có network, nạp NGSL/NAWL CSV (CC-BY-SA, ghi attribution)
qua load_wordlist_external() thay thế/làm giàu các pack 1, 4–8, 10.
"""

from __future__ import annotations

from seed_spec import PackSpec, slugify

# Cơ sở storage gợi ý cho catalog doc (owner upload pack lên đây).
# Path THUẦN trong bucket vipsound-df903.firebasestorage.app
# (download = /v0/b/{bucket}/o/{path}?alt=media) — khớp rules §3.
_STORAGE = 'packs/seed'


def _entry(word: str, meaning: str, phonetic: str = '', example: str = ''):
    e = {
        'word': word,
        'meaning': meaning,
        'audio': f'{slugify(word)}.mp3',  # TTS bulk sinh lúc soạn (máy chủ)
    }
    if phonetic:
        e['phonetic'] = phonetic
    if example:
        e['example'] = example
    return e


def _spec(pid, title, subtitle, desc, level, tags):
    return PackSpec(
        pack_id=pid,
        pack_type='vocab',
        title=title,
        subtitle=subtitle,
        description=desc,
        level=level,
        tags=tags,
        attribution='In4Up Seed — tự soạn tuyển chọn (cc0).',
        storage_path=f'{_STORAGE}/{pid}.i4upack',
    )


# --------------------------------------------------------------------------
# Pack 1 — 500 động từ thông dụng nhất (v1: tuyển 120 động từ lõi tần suất
# cao; mở rộng lên 500 khi nạp NGSL có network — xem module docstring).
# --------------------------------------------------------------------------

_COMMON_VERBS: list[tuple[str, str, str, str]] = [
    # (word, meaning, phonetic, example)
    ('be', 'thì; là; ở', '/biː/', 'I want to be a teacher.'),
    ('have', 'có', '/hæv/', 'Do you have any brothers or sisters?'),
    ('do', 'làm', '/duː/', 'What do you do every morning?'),
    ('say', 'nói', '/seɪ/', 'She said she was tired.'),
    ('get', 'lấy; được; trở nên', '/ɡet/', "Let's get some coffee."),
    ('make', 'làm; chế tạo', '/meɪk/', 'She makes bread every Sunday.'),
    ('go', 'đi', '/ɡəʊ/', 'We go to school by bus.'),
    ('know', 'biết', '/nəʊ/', 'I know the answer.'),
    ('take', 'lấy; mang; mất (thời gian)', '/teɪk/', 'Take your time.'),
    ('see', 'nhìn thấy', '/siː/', 'I see a bird in the tree.'),
    ('come', 'đến', '/kʌm/', 'Come here, please.'),
    ('think', 'nghĩ', '/θɪŋk/', 'I think it will rain.'),
    ('look', 'nhìn', '/lʊk/', 'Look at the moon tonight.'),
    ('want', 'muốn', '/wɒnt/', 'I want to learn English well.'),
    ('give', 'cho', '/ɡɪv/', 'Give me your hand.'),
    ('use', 'sử dụng', '/juːz/', 'You can use my pen.'),
    ('find', 'tìm thấy', '/faɪnd/', "I can't find my keys."),
    ('tell', 'kể; bảo', '/tel/', 'Tell me a story.'),
    ('ask', 'hỏi; yêu cầu', '/ɑːsk/', 'May I ask a question?'),
    ('work', 'làm việc', '/wɜːk/', 'They work in a hospital.'),
    ('seem', 'dường như', '/siːm/', 'You seem very happy today.'),
    ('feel', 'cảm thấy', '/fiːl/', 'I feel a little cold.'),
    ('try', 'cố gắng; thử', '/traɪ/', 'Try to speak slowly.'),
    ('leave', 'rời đi; để lại', '/liːv/', 'The train leaves at six.'),
    ('call', 'gọi', '/kɔːl/', "I'll call you tonight."),
    ('need', 'cần', '/niːd/', 'We need more time.'),
    ('become', 'trở thành', '/bɪˈkʌm/', 'She became a doctor.'),
    ('mean', 'có nghĩa; ý định', '/miːn/', 'What does this word mean?'),
    ('put', 'đặt; để', '/pʊt/', 'Put the books on the table.'),
    ('keep', 'giữ', '/kiːp/', 'Keep the door open.'),
    ('let', 'để cho', '/let/', 'Let me help you.'),
    ('begin', 'bắt đầu', '/bɪˈɡɪn/', 'Class begins at eight.'),
    ('help', 'giúp đỡ', '/help/', 'Can you help me with this bag?'),
    ('talk', 'nói chuyện', '/tɔːk/', 'We talked for hours.'),
    ('turn', 'quay; rẽ', '/tɜːn/', 'Turn left at the corner.'),
    ('start', 'bắt đầu; khởi động', '/stɑːt/', 'The movie starts soon.'),
    ('show', 'cho xem; chỉ', '/ʃəʊ/', 'Show me your photos.'),
    ('hear', 'nghe thấy', '/hɪə(r)/', 'Did you hear that sound?'),
    ('play', 'chơi; chơi (nhạc cụ)', '/pleɪ/', 'Children play in the park.'),
    ('run', 'chạy', '/rʌn/', 'He runs every morning.'),
    ('move', 'di chuyển; chuyển nhà', '/muːv/', "Don't move, please."),
    ('like', 'thích', '/laɪk/', 'I like Vietnamese coffee.'),
    ('live', 'sống; ở', '/lɪv/', 'They live in Hue.'),
    ('believe', 'tin; tin tưởng', '/bɪˈliːv/', 'I believe you.'),
    ('hold', 'cầm; giữ', '/həʊld/', 'Hold my hand.'),
    ('bring', 'mang đến', '/brɪŋ/', 'Bring an umbrella with you.'),
    ('happen', 'xảy ra', '/ˈhæpən/', 'What happened yesterday?'),
    ('write', 'viết', '/raɪt/', 'She writes in her diary every night.'),
    ('sit', 'ngồi', '/sɪt/', 'Sit down, please.'),
    ('stand', 'đứng', '/stænd/', 'Stand up straight.'),
    ('lose', 'mất; thua', '/luːz/', "Don't lose hope."),
    ('pay', 'trả tiền', '/peɪ/', "I'll pay for dinner."),
    ('meet', 'gặp', '/miːt/', 'Nice to meet you.'),
    ('include', 'bao gồm', '/ɪnˈkluːd/', 'The price includes breakfast.'),
    ('continue', 'tiếp tục', '/kənˈtɪnjuː/', 'Please continue reading.'),
    ('set', 'đặt; thiết lập', '/set/', 'Set the alarm for six.'),
    ('learn', 'học', '/lɜːn/', 'We learn new words every day.'),
    ('change', 'thay đổi', '/tʃeɪndʒ/', 'People change over time.'),
    ('lead', 'dẫn dắt', '/liːd/', 'She leads the team well.'),
    ('understand', 'hiểu', '/ˌʌndəˈstænd/', 'I understand the lesson.'),
    ('watch', 'xem; đồng hồ đeo tay', '/wɒtʃ/', 'We watched a film.'),
    ('follow', 'theo sau; làm theo', '/ˈfɒləʊ/', 'Follow me, please.'),
    ('stop', 'dừng lại', '/stɒp/', 'The bus stops here.'),
    ('create', 'tạo ra', '/kriˈeɪt/', 'She created a new song.'),
    ('speak', 'nói', '/spiːk/', 'Do you speak English?'),
    ('read', 'đọc', '/riːd/', 'He reads the news every morning.'),
    ('allow', 'cho phép', '/əˈlaʊ/', 'They allow pets here.'),
    ('add', 'thêm vào', '/æd/', 'Add some sugar to the tea.'),
    ('spend', 'dành; tiêu (tiền)', '/spend/', 'We spent two days in Hanoi.'),
    ('grow', 'lớn lên; trồng', '/ɡrəʊ/', 'Rice grows well here.'),
    ('open', 'mở', '/ˈəʊpən/', 'Open the window, please.'),
    ('walk', 'đi bộ', '/wɔːk/', 'We walk to the market.'),
    ('win', 'thắng', '/wɪn/', 'Our team won the game.'),
    ('offer', 'đề nghị; mời', '/ˈɒfə(r)/', 'They offered us tea.'),
    ('remember', 'nhớ', '/rɪˈmembə(r)/', 'Remember to call your mother.'),
    ('love', 'yêu', '/lʌv/', 'She loves reading books.'),
    ('consider', 'xem xét; cân nhắc', '/kənˈsɪdə(r)/', 'We considered the plan carefully.'),
    ('appear', 'xuất hiện', '/əˈpɪə(r)/', 'A rainbow appeared in the sky.'),
    ('buy', 'mua', '/baɪ/', 'He bought a new bicycle.'),
    ('wait', 'chờ đợi', '/weɪt/', 'Wait for me at the gate.'),
    ('serve', 'phục vụ', '/sɜːv/', 'They serve lunch at noon.'),
    ('die', 'chết', '/daɪ/', 'The old tree died last year.'),
    ('send', 'gửi', '/send/', 'Send me a message when you arrive.'),
    ('expect', 'mong đợi', '/ɪkˈspekt/', 'We expect guests tonight.'),
    ('build', 'xây dựng', '/bɪld/', 'They built a small house.'),
    ('stay', 'ở lại', '/steɪ/', 'Stay with us a little longer.'),
    ('fall', 'ngã; rơi', '/fɔːl/', 'Leaves fall in autumn.'),
    ('cut', 'cắt', '/kʌt/', 'Cut the paper in half.'),
    ('reach', 'đến; với tới', '/riːtʃ/', 'We reached the top of the hill.'),
    ('kill', 'giết', '/kɪl/', 'The cold killed the plants.'),
    ('remain', 'còn lại', '/rɪˈmeɪn/', 'Only two tickets remain.'),
    ('suggest', 'gợi ý', '/səˈdʒest/', 'She suggested a new idea.'),
    ('raise', 'nâng lên; nuôi', '/reɪz/', 'Raise your hand if you know.'),
    ('pass', 'vượt qua; đậu (kỳ thi)', '/pɑːs/', 'He passed the exam.'),
    ('sell', 'bán', '/sel/', 'They sell fresh fruit.'),
    ('require', 'yêu cầu', '/rɪˈkwaɪə(r)/', 'This job requires patience.'),
    ('report', 'báo cáo', '/rɪˈpɔːt/', 'She reported the accident.'),
    ('decide', 'quyết định', '/dɪˈsaɪd/', 'We decided to stay home.'),
    ('pull', 'kéo', '/pʊl/', 'Pull the door to open it.'),
    ('explain', 'giải thích', '/ɪkˈspleɪn/', 'The teacher explained the rule.'),
    ('hope', 'hy vọng', '/həʊp/', 'I hope you feel better soon.'),
    ('develop', 'phát triển', '/dɪˈveləp/', 'The city is developing fast.'),
    ('carry', 'mang; xách', '/ˈkæri/', 'He carried the heavy box.'),
    ('break', 'làm vỡ; nghỉ giải lao', '/breɪk/', 'Be careful not to break the glass.'),
    ('receive', 'nhận được', '/rɪˈsiːv/', 'She received a letter today.'),
    ('agree', 'đồng ý', '/əˈɡriː/', 'I agree with you.'),
    ('support', 'ủng hộ', '/səˈpɔːt/', 'My family supports my dream.'),
    ('hit', 'đánh trúng; đập', '/hɪt/', 'The ball hit the window.'),
    ('produce', 'sản xuất', '/prəˈdjuːs/', 'This farm produces rice.'),
    ('eat', 'ăn', '/iːt/', 'We eat dinner at seven.'),
    ('cover', 'bao phủ', '/ˈkʌvə(r)/', 'Snow covered the road.'),
    ('catch', 'bắt; đón (xe)', '/kætʃ/', 'Catch the ball!'),
    ('draw', 'vẽ; kéo', '/drɔː/', 'She draws beautiful pictures.'),
    ('choose', 'chọn', '/tʃuːz/', 'Choose one you like best.'),
    ('cook', 'nấu ăn', '/kʊk/', 'My father cooks very well.'),
    ('smile', 'mỉm cười', '/smaɪl/', 'She smiled at the baby.'),
    ('drink', 'uống', '/drɪŋk/', 'Drink more water in summer.'),
    ('sleep', 'ngủ', '/sliːp/', 'The baby sleeps ten hours a day.'),
]

VOCAB_500_VERBS = (
    _spec(
        'seed_vocab_500_verbs',
        'Động từ thông dụng nhất (lõi 120)',
        'Core English verbs with Vietnamese meanings',
        'Tuyển chọn các động từ tần suất cao nhất trong tiếng Anh, kèm nghĩa '
        'Việt, phiên âm và câu ví dụ ngắn. Lộ trình mở rộng lên 500 từ khi '
        'nạp bảng NGSL (v2).',
        'B1',
        ['verbs', 'core', 'seed'],
    ),
    [_entry(w, m, p, ex) for (w, m, p, ex) in _COMMON_VERBS],
)

# --------------------------------------------------------------------------
# Pack 2 — 120 động từ bất quy tắc (V1/V2/V3). meaning gộp 3 dạng + nghĩa.
# --------------------------------------------------------------------------

_IRREGULAR: list[tuple[str, str, str, str]] = [
    # (V1, V2, V3, nghĩa)
    ('arise', 'arose', 'arisen', 'nảy sinh'),
    ('awake', 'awoke', 'awoken', 'đánh thức; tỉnh dậy'),
    ('be', 'was/were', 'been', 'thì; là; ở'),
    ('bear', 'bore', 'borne', 'chịu đựng; sinh'),
    ('beat', 'beat', 'beaten', 'đánh bại'),
    ('become', 'became', 'become', 'trở thành'),
    ('begin', 'began', 'begun', 'bắt đầu'),
    ('bend', 'bent', 'bent', 'uốn cong'),
    ('bet', 'bet', 'bet', 'đặt cược'),
    ('bind', 'bound', 'bound', 'buộc; ràng'),
    ('bite', 'bit', 'bitten', 'cắn'),
    ('bleed', 'bled', 'bled', 'chảy máu'),
    ('blow', 'blew', 'blown', 'thổi'),
    ('break', 'broke', 'broken', 'làm vỡ'),
    ('bring', 'brought', 'brought', 'mang đến'),
    ('build', 'built', 'built', 'xây dựng'),
    ('burn', 'burnt', 'burnt', 'đốt cháy'),
    ('buy', 'bought', 'bought', 'mua'),
    ('catch', 'caught', 'caught', 'bắt; đón'),
    ('choose', 'chose', 'chosen', 'chọn'),
    ('come', 'came', 'come', 'đến'),
    ('cost', 'cost', 'cost', 'trị giá'),
    ('cut', 'cut', 'cut', 'cắt'),
    ('deal', 'dealt', 'dealt', 'giải quyết; chia bài'),
    ('dig', 'dug', 'dug', 'đào'),
    ('do', 'did', 'done', 'làm'),
    ('draw', 'drew', 'drawn', 'vẽ; kéo'),
    ('drink', 'drank', 'drunk', 'uống'),
    ('drive', 'drove', 'driven', 'lái xe'),
    ('eat', 'ate', 'eaten', 'ăn'),
    ('fall', 'fell', 'fallen', 'ngã; rơi'),
    ('feed', 'fed', 'fed', 'cho ăn'),
    ('feel', 'felt', 'felt', 'cảm thấy'),
    ('fight', 'fought', 'fought', 'chiến đấu'),
    ('find', 'found', 'found', 'tìm thấy'),
    ('fly', 'flew', 'flown', 'bay'),
    ('forget', 'forgot', 'forgotten', 'quên'),
    ('forgive', 'forgave', 'forgiven', 'tha thứ'),
    ('freeze', 'froze', 'frozen', 'đóng băng'),
    ('get', 'got', 'got/gotten', 'lấy; được'),
    ('give', 'gave', 'given', 'cho'),
    ('go', 'went', 'gone', 'đi'),
    ('grow', 'grew', 'grown', 'lớn lên; trồng'),
    ('hang', 'hung', 'hung', 'treo'),
    ('have', 'had', 'had', 'có'),
    ('hear', 'heard', 'heard', 'nghe thấy'),
    ('hide', 'hid', 'hidden', 'giấu; trốn'),
    ('hit', 'hit', 'hit', 'đánh trúng'),
    ('hold', 'held', 'held', 'cầm; giữ'),
    ('hurt', 'hurt', 'hurt', 'làm đau'),
    ('keep', 'kept', 'kept', 'giữ'),
    ('know', 'knew', 'known', 'biết'),
    ('lay', 'laid', 'laid', 'đặt; đẻ (trứng)'),
    ('lead', 'led', 'led', 'dẫn dắt'),
    ('leave', 'left', 'left', 'rời đi'),
    ('lend', 'lent', 'lent', 'cho mượn'),
    ('let', 'let', 'let', 'để cho'),
    ('lie', 'lay', 'lain', 'nằm'),
    ('lose', 'lost', 'lost', 'mất; thua'),
    ('make', 'made', 'made', 'làm'),
    ('mean', 'meant', 'meant', 'có nghĩa'),
    ('meet', 'met', 'met', 'gặp'),
    ('pay', 'paid', 'paid', 'trả tiền'),
    ('put', 'put', 'put', 'đặt; để'),
    ('read', 'read', 'read', 'đọc'),
    ('ride', 'rode', 'ridden', 'cưỡi; đi (xe)'),
    ('ring', 'rang', 'rung', 'rung chuông'),
    ('rise', 'rose', 'risen', 'mọc; dâng lên'),
    ('run', 'ran', 'run', 'chạy'),
    ('say', 'said', 'said', 'nói'),
    ('see', 'saw', 'seen', 'nhìn thấy'),
    ('seek', 'sought', 'sought', 'tìm kiếm'),
    ('sell', 'sold', 'sold', 'bán'),
    ('send', 'sent', 'sent', 'gửi'),
    ('set', 'set', 'set', 'đặt; thiết lập'),
    ('shake', 'shook', 'shaken', 'lắc'),
    ('shine', 'shone', 'shone', 'tỏa sáng'),
    ('shoot', 'shot', 'shot', 'bắn'),
    ('show', 'showed', 'shown', 'cho xem'),
    ('shut', 'shut', 'shut', 'đóng'),
    ('sing', 'sang', 'sung', 'hát'),
    ('sit', 'sat', 'sat', 'ngồi'),
    ('sleep', 'slept', 'slept', 'ngủ'),
    ('slide', 'slid', 'slid', 'trượt'),
    ('smell', 'smelt', 'smelt', 'ngửi'),
    ('speak', 'spoke', 'spoken', 'nói'),
    ('spend', 'spent', 'spent', 'dành; tiêu'),
    ('spill', 'spilt', 'spilt', 'làm đổ'),
    ('stand', 'stood', 'stood', 'đứng'),
    ('steal', 'stole', 'stolen', 'ăn cắp'),
    ('stick', 'stuck', 'stuck', 'dán; gắn'),
    ('sting', 'stung', 'stung', 'chích; đốt'),
    ('swim', 'swam', 'swum', 'bơi'),
    ('swing', 'swung', 'swung', 'đu đưa'),
    ('take', 'took', 'taken', 'lấy; mang'),
    ('teach', 'taught', 'taught', 'dạy'),
    ('tear', 'tore', 'torn', 'xé'),
    ('tell', 'told', 'told', 'kể; bảo'),
    ('think', 'thought', 'thought', 'nghĩ'),
    ('throw', 'threw', 'thrown', 'ném'),
    ('understand', 'understood', 'understood', 'hiểu'),
    ('wake', 'woke', 'woken', 'thức dậy'),
    ('wear', 'wore', 'worn', 'mặc'),
    ('win', 'won', 'won', 'thắng'),
    ('write', 'wrote', 'written', 'viết'),
    ('bend', 'bent', 'bent', 'uốn cong'),
    ('blow', 'blew', 'blown', 'thổi'),
    ('bring', 'brought', 'brought', 'mang đến'),
    ('build', 'built', 'built', 'xây dựng'),
    ('catch', 'caught', 'caught', 'bắt giữ'),
    ('deal', 'dealt', 'dealt', 'đối phó'),
    ('fight', 'fought', 'fought', 'chiến đấu'),
    ('forbid', 'forbade', 'forbidden', 'cấm'),
    ('forget', 'forgot', 'forgotten', 'lãng quên'),
    ('forgive', 'forgave', 'forgiven', 'tha lỗi'),
    ('freeze', 'froze', 'frozen', 'đông cứng'),
    ('hang', 'hung', 'hung', 'treo lên'),
    ('hide', 'hid', 'hidden', 'che giấu'),
    ('lead', 'led', 'led', 'chỉ đường'),
    ('light', 'lit', 'lit', 'thắp sáng'),
    ('seek', 'sought', 'sought', 'kiếm tìm'),
    ('shake', 'shook', 'shaken', 'rung lắc'),
    ('shine', 'shone', 'shone', 'chiếu sáng'),
    ('sink', 'sank', 'sunk', 'chìm'),
    ('spring', 'sprang', 'sprung', 'nhảy bật'),
    ('steal', 'stole', 'stolen', 'trộm cắp'),
    ('strike', 'struck', 'struck', 'đánh; đình công'),
    ('swear', 'swore', 'sworn', 'thề'),
]
# Bỏ trùng lặp theo V1 giữ thứ tự.
_seen: set[str] = set()
_IRREGULAR = [t for t in _IRREGULAR if not (t[0] in _seen or _seen.add(t[0]))]

VOCAB_IRREGULAR = (
    _spec(
        'seed_vocab_irregular_verbs',
        '120 động từ bất quy tắc (V1/V2/V3)',
        'Irregular verbs with Vietnamese meanings',
        'Bảng 120 động từ bất quy tắc thông dụng nhất: V1 → V2 → V3 kèm nghĩa '
        'Việt. Học theo cặp để nhớ lâu.',
        'B1',
        ['verbs', 'irregular', 'grammar'],
    ),
    [
        {
            'word': v1,
            'meaning': f'{v2} / {v3} — {mean}',
            'audio': f'{slugify(v1)}.mp3',
        }
        for (v1, v2, v3, mean) in _IRREGULAR[:120]
    ],
)

# --------------------------------------------------------------------------
# Pack 3 — 300 phrasal verbs (v1: 60 cụm lõi tần suất cao).
# --------------------------------------------------------------------------

_PHRASAL: list[tuple[str, str, str]] = [
    ('ask out', 'mời đi chơi (hẹn hò)', 'He asked her out for dinner.'),
    ('back up', 'sao lưu; ủng hộ', 'Always back up your files.'),
    ('blow up', 'phát nổ; thổi phồng', 'The balloon blew up.'),
    ('break down', 'hỏng (máy); suy sụp', 'The car broke down on the way.'),
    ('break up', 'chia tay; tan vỡ', 'They broke up last month.'),
    ('bring up', 'nuôi dạy; nhắc đến', 'She brought up three children.'),
    ('call off', 'hủy bỏ', 'The match was called off.'),
    ('calm down', 'bình tĩnh lại', 'Calm down and listen to me.'),
    ('carry on', 'tiếp tục', 'Carry on with your work.'),
    ('carry out', 'thực hiện', 'They carried out the plan.'),
    ('catch up', 'bắt kịp', "I need to catch up on sleep."),
    ('check in', 'làm thủ tục (khách sạn/máy bay)', 'We checked in at noon.'),
    ('check out', 'trả phòng; kiểm tra', 'Check out this new song!'),
    ('come across', 'tình cờ gặp', 'I came across an old photo.'),
    ('come back', 'quay lại', 'When will you come back?'),
    ('come up with', 'nảy ra (ý tưởng)', 'She came up with a great idea.'),
    ('cut down', 'chặt; cắt giảm', "I'm cutting down on sugar."),
    ('drop by', 'ghé thăm', 'Drop by anytime.'),
    ('drop off', 'thả xuống xe; ngủ gật', 'Drop me off at the station.'),
    ('fall apart', 'rơi ra từng mảnh', 'The old book is falling apart.'),
    ('figure out', 'tìm ra; hiểu ra', "I can't figure out this puzzle."),
    ('fill in', 'điền vào', 'Fill in this form, please.'),
    ('find out', 'khám phá ra', 'We found out the truth.'),
    ('get along', 'hòa thuận', 'Do you get along with your neighbors?'),
    ('get away', 'trốn thoát; đi nghỉ', "Let's get away for the weekend."),
    ('get back', 'trở về; lấy lại', 'I got my money back.'),
    ('get over', 'vượt qua (bệnh/nỗi buồn)', 'It took months to get over the flu.'),
    ('get up', 'thức dậy', 'I get up at six.'),
    ('give up', 'bỏ cuộc; từ bỏ', "Don't give up your dream."),
    ('go on', 'tiếp diễn', 'The show must go on.'),
    ('go out', 'đi chơi; tắt (lửa/đèn)', "Let's go out tonight."),
    ('grow up', 'lớn lên; trưởng thành', 'I grew up in the countryside.'),
    ('hang out', 'đi chơi với bạn', 'We hang out at the cafe.'),
    ('hold on', 'chờ một chút', 'Hold on, please.'),
    ('keep on', 'cứ tiếp tục', 'Keep on trying.'),
    ('let down', 'làm thất vọng', "Don't let me down."),
    ('look after', 'chăm sóc', 'She looks after her grandmother.'),
    ('look for', 'tìm kiếm', "I'm looking for my phone."),
    ('look forward to', 'mong chờ', 'I look forward to your reply.'),
    ('look up', 'tra (từ); nhìn lên', 'Look up the word in a dictionary.'),
    ('make up', 'bịa chuyện; làm hòa', 'They made up after the fight.'),
    ('pick up', 'nhặt; đón; học lóm', "I'll pick you up at seven."),
    ('point out', 'chỉ ra', 'She pointed out my mistake.'),
    ('put off', 'trì hoãn', "Don't put off your homework."),
    ('put on', 'mặc vào; mở (thiết bị)', 'Put on your coat.'),
    ('put out', 'dập tắt', 'They put out the fire.'),
    ('run out of', 'hết sạch', 'We ran out of milk.'),
    ('set off', 'khởi hành', 'We set off early in the morning.'),
    ('set up', 'dựng lên; thiết lập', 'They set up a new company.'),
    ('show off', 'khoe khoang', 'Stop showing off.'),
    ('shut down', 'tắt máy; đóng cửa', 'Shut down your computer.'),
    ('slow down', 'chậm lại', 'Slow down! You speak too fast.'),
    ('take off', 'cất cánh; cởi ra', 'The plane took off on time.'),
    ('take over', 'tiếp quản', 'She took over the family shop.'),
    ('take up', 'bắt đầu (sở thích)', 'He took up yoga this year.'),
    ('throw away', 'vứt đi', 'Throw away the old papers.'),
    ('try on', 'thử (quần áo)', 'Can I try on this jacket?'),
    ('turn down', 'từ chối; vặn nhỏ', 'She turned down the offer.'),
    ('turn on', 'bật', 'Turn on the light, please.'),
    ('wake up', 'thức giấc', 'I woke up at dawn.'),
]

VOCAB_PHRASAL = (
    _spec(
        'seed_vocab_phrasal_verbs',
        'Phrasal verbs thông dụng (lõi 60)',
        'Everyday phrasal verbs with Vietnamese meanings',
        'Cụm động từ tần suất cao trong giao tiếp, kèm nghĩa Việt và câu ví '
        'dụ. Lộ trình mở rộng lên 300 (v2).',
        'B2',
        ['phrasal-verbs', 'conversation'],
    ),
    [
        _entry(w, m, '', ex) for (w, m, ex) in _PHRASAL
    ],
)

# --------------------------------------------------------------------------
# Pack 4–7 — NGSL theo chủ đề (4 × 40 từ lõi tự tuyển).
# --------------------------------------------------------------------------

_TOPIC_FAMILY_FOOD: list[tuple[str, str]] = [
    ('family', 'gia đình'), ('father', 'cha'), ('mother', 'mẹ'),
    ('parents', 'cha mẹ'), ('son', 'con trai'), ('daughter', 'con gái'),
    ('brother', 'anh/em trai'), ('sister', 'chị/em gái'), ('husband', 'chồng'),
    ('wife', 'vợ'), ('child', 'đứa trẻ'), ('baby', 'em bé'),
    ('grandfather', 'ông'), ('grandmother', 'bà'), ('uncle', 'chú/bác'),
    ('aunt', 'cô/dì'), ('cousin', 'anh chị em họ'), ('relative', 'họ hàng'),
    ('meal', 'bữa ăn'), ('breakfast', 'bữa sáng'), ('lunch', 'bữa trưa'),
    ('dinner', 'bữa tối'), ('rice', 'cơm; gạo'), ('bread', 'bánh mì'),
    ('noodle', 'mì; phở'), ('soup', 'canh; súp'), ('meat', 'thịt'),
    ('fish', 'cá'), ('chicken', 'thịt gà'), ('egg', 'trứng'),
    ('vegetable', 'rau'), ('fruit', 'trái cây'), ('milk', 'sữa'),
    ('water', 'nước'), ('tea', 'trà'), ('coffee', 'cà phê'),
    ('sugar', 'đường'), ('salt', 'muối'), ('kitchen', 'nhà bếp'),
    ('table', 'cái bàn'),
]

_TOPIC_STUDY_WORK: list[tuple[str, str]] = [
    ('school', 'trường học'), ('teacher', 'giáo viên'), ('student', 'học sinh'),
    ('class', 'lớp học'), ('lesson', 'bài học'), ('homework', 'bài tập về nhà'),
    ('exam', 'kỳ thi'), ('test', 'bài kiểm tra'), ('book', 'sách'),
    ('notebook', 'quyển vở'), ('pen', 'bút mực'), ('pencil', 'bút chì'),
    ('paper', 'giấy'), ('dictionary', 'từ điển'), ('subject', 'môn học'),
    ('language', 'ngôn ngữ'), ('word', 'từ'), ('sentence', 'câu'),
    ('question', 'câu hỏi'), ('answer', 'câu trả lời'), ('job', 'công việc'),
    ('office', 'văn phòng'), ('company', 'công ty'), ('boss', 'sếp'),
    ('worker', 'công nhân'), ('salary', 'lương'), ('meeting', 'cuộc họp'),
    ('email', 'thư điện tử'), ('computer', 'máy tính'), ('phone', 'điện thoại'),
    ('money', 'tiền'), ('hour', 'giờ'), ('week', 'tuần'),
    ('colleague', 'đồng nghiệp'), ('skill', 'kỹ năng'), ('task', 'nhiệm vụ'),
    ('project', 'dự án'), ('deadline', 'hạn chót'), ('interview', 'phỏng vấn'),
    ('experience', 'kinh nghiệm'),
]

_TOPIC_TRAVEL_TRANSPORT: list[tuple[str, str]] = [
    ('travel', 'du lịch'), ('trip', 'chuyến đi'), ('journey', 'hành trình'),
    ('ticket', 'vé'), ('passport', 'hộ chiếu'), ('luggage', 'hành lý'),
    ('map', 'bản đồ'), ('road', 'con đường'), ('street', 'phố'),
    ('station', 'nhà ga; trạm'), ('airport', 'sân bay'), ('hotel', 'khách sạn'),
    ('bus', 'xe buýt'), ('train', 'tàu hỏa'), ('plane', 'máy bay'),
    ('car', 'ô tô'), ('bicycle', 'xe đạp'), ('motorbike', 'xe máy'),
    ('ship', 'tàu thủy'), ('taxi', 'tắc xi'), ('driver', 'tài xế'),
    ('passenger', 'hành khách'), ('traffic', 'giao thông'),
    ('crossroads', 'ngã tư'), ('bridge', 'cây cầu'), ('corner', 'góc phố'),
    ('left', 'bên trái'), ('right', 'bên phải'), ('straight', 'thẳng'),
    ('far', 'xa'), ('near', 'gần'), ('north', 'phía bắc'),
    ('south', 'phía nam'), ('east', 'phía đông'), ('west', 'phía tây'),
    ('beach', 'bãi biển'), ('mountain', 'núi'), ('village', 'làng quê'),
    ('city', 'thành phố'), ('country', 'đất nước'),
]

_TOPIC_FEELINGS_SOCIETY: list[tuple[str, str]] = [
    ('happy', 'vui vẻ'), ('sad', 'buồn'), ('angry', 'tức giận'),
    ('afraid', 'sợ hãi'), ('worried', 'lo lắng'), ('excited', 'hào hứng'),
    ('tired', 'mệt mỏi'), ('bored', 'chán'), ('surprised', 'ngạc nhiên'),
    ('proud', 'tự hào'), ('lonely', 'cô đơn'), ('calm', 'bình tĩnh'),
    ('nervous', 'bồn chồn'), ('confident', 'tự tin'), ('grateful', 'biết ơn'),
    ('jealous', 'ghen tị'), ('shy', 'nhút nhát'), ('friendly', 'thân thiện'),
    ('kind', 'tử tế'), ('polite', 'lịch sự'), ('honest', 'trung thực'),
    ('patient', 'kiên nhẫn'), ('selfish', 'ích kỷ'), ('generous', 'hào phóng'),
    ('friend', 'bạn bè'), ('neighbor', 'hàng xóm'), ('community', 'cộng đồng'),
    ('society', 'xã hội'), ('culture', 'văn hóa'), ('tradition', 'truyền thống'),
    ('festival', 'lễ hội'), ('holiday', 'ngày lễ'), ('gift', 'quà tặng'),
    ('party', 'bữa tiệc'), ('wedding', 'đám cưới'), ('funeral', 'đám tang'),
    ('respect', 'tôn trọng'), ('trust', 'tin tưởng'), ('peace', 'hòa bình'),
]

VOCAB_NGSL_FAMILY = (
    _spec(
        'seed_vocab_ngsl_family_food',
        'NGSL theo chủ đề: Gia đình & Ăn uống',
        'NGSL topics — family & food',
        'Từ vựng thiết yếu chủ đề gia đình và ăn uống (tuyển từ bảng tần suất, '
        'tự soạn nghĩa Việt).',
        'A2',
        ['ngsl', 'topic', 'family', 'food'],
    ),
    [_entry(w, m) for (w, m) in _TOPIC_FAMILY_FOOD],
)

VOCAB_NGSL_STUDY = (
    _spec(
        'seed_vocab_ngsl_study_work',
        'NGSL theo chủ đề: Học tập & Công việc',
        'NGSL topics — study & work',
        'Từ vựng chủ đề học tập và công việc, tuyển từ bảng tần suất, tự soạn '
        'nghĩa Việt.',
        'A2',
        ['ngsl', 'topic', 'study', 'work'],
    ),
    [_entry(w, m) for (w, m) in _TOPIC_STUDY_WORK],
)

VOCAB_NGSL_TRAVEL = (
    _spec(
        'seed_vocab_ngsl_travel_transport',
        'NGSL theo chủ đề: Du lịch & Giao thông',
        'NGSL topics — travel & transport',
        'Từ vựng chủ đề du lịch và giao thông, tuyển từ bảng tần suất, tự soạn '
        'nghĩa Việt.',
        'A2',
        ['ngsl', 'topic', 'travel', 'transport'],
    ),
    [_entry(w, m) for (w, m) in _TOPIC_TRAVEL_TRANSPORT],
)

VOCAB_NGSL_FEELINGS = (
    _spec(
        'seed_vocab_ngsl_feelings_society',
        'NGSL theo chủ đề: Cảm xúc & Xã hội',
        'NGSL topics — feelings & society',
        'Từ vựng chủ đề cảm xúc và xã hội, tuyển từ bảng tần suất, tự soạn '
        'nghĩa Việt.',
        'A2',
        ['ngsl', 'topic', 'feelings', 'society'],
    ),
    [_entry(w, m) for (w, m) in _TOPIC_FEELINGS_SOCIETY],
)

# --------------------------------------------------------------------------
# Pack 8 — Tính từ & trạng từ miêu tả (60).
# --------------------------------------------------------------------------

_ADJ_ADV: list[tuple[str, str]] = [
    ('big', 'to; lớn'), ('small', 'nhỏ'), ('long', 'dài'), ('short', 'ngắn'),
    ('tall', 'cao (người)'), ('low', 'thấp'), ('wide', 'rộng'),
    ('narrow', 'hẹp'), ('deep', 'sâu'), ('shallow', 'nông'),
    ('heavy', 'nặng'), ('light', 'nhẹ'), ('fast', 'nhanh'), ('slow', 'chậm'),
    ('hot', 'nóng'), ('cold', 'lạnh'), ('warm', 'ấm'), ('cool', 'mát'),
    ('new', 'mới'), ('old', 'cũ'), ('young', 'trẻ'), ('beautiful', 'đẹp'),
    ('ugly', 'xấu'), ('clean', 'sạch'), ('dirty', 'bẩn'), ('easy', 'dễ'),
    ('difficult', 'khó'), ('simple', 'đơn giản'), ('complex', 'phức tạp'),
    ('rich', 'giàu'), ('poor', 'nghèo'), ('strong', 'mạnh'), ('weak', 'yếu'),
    ('loud', 'ồn ào'), ('quiet', 'yên tĩnh'), ('bright', 'sáng'),
    ('dark', 'tối'), ('soft', 'mềm'), ('hard', 'cứng'), ('sweet', 'ngọt'),
    ('bitter', 'đắng'), ('sour', 'chua'), ('salty', 'mặn'),
    ('quickly', 'một cách nhanh chóng'), ('slowly', 'một cách chậm rãi'),
    ('carefully', 'một cách cẩn thận'), ('quietly', 'một cách lặng lẽ'),
    ('happily', 'một cách vui vẻ'), ('clearly', 'một cách rõ ràng'),
    ('easily', 'một cách dễ dàng'), ('usually', 'thường xuyên'),
    ('always', 'luôn luôn'), ('never', 'không bao giờ'),
    ('often', 'thường'), ('sometimes', 'thỉnh thoảng'), ('rarely', 'hiếm khi'),
    ('very', 'rất'), ('quite', 'khá'), ('almost', 'gần như'),
    ('enough', 'đủ'), ('together', 'cùng nhau'),
]

VOCAB_ADJ_ADV = (
    _spec(
        'seed_vocab_adj_adv',
        'Tính từ & trạng từ miêu tả',
        'Descriptive adjectives & adverbs',
        'Tính từ và trạng từ miêu tả thông dụng, kèm nghĩa Việt.',
        'B1',
        ['adjectives', 'adverbs'],
    ),
    [_entry(w, m) for (w, m) in _ADJ_ADV],
)

# --------------------------------------------------------------------------
# Pack 9 — Collocations thông dụng (50).
# --------------------------------------------------------------------------

_COLLOCATIONS: list[tuple[str, str, str]] = [
    ('make a decision', 'đưa ra quyết định', 'We made a decision together.'),
    ('make a mistake', 'mắc lỗi', 'Everyone makes mistakes.'),
    ('make progress', 'tiến bộ', 'She is making good progress.'),
    ('make an effort', 'cố gắng', 'Please make an effort to arrive on time.'),
    ('make friends', 'kết bạn', 'He made friends quickly.'),
    ('do homework', 'làm bài tập về nhà', 'I do my homework after dinner.'),
    ('do business', 'kinh doanh', 'They do business online.'),
    ('do a favor', 'giúp một tay', 'Can you do me a favor?'),
    ('take a break', 'nghỉ giải lao', "Let's take a break."),
    ('take a photo', 'chụp ảnh', 'She took a photo of the sunset.'),
    ('take responsibility', 'chịu trách nhiệm', 'He took responsibility for the error.'),
    ('take a risk', 'mạo hiểm', 'Starting a business is taking a risk.'),
    ('have a look', 'nhìn qua', 'Have a look at this picture.'),
    ('have a rest', 'nghỉ ngơi', 'You look tired — have a rest.'),
    ('have a conversation', 'trò chuyện', 'We had a long conversation.'),
    ('catch a cold', 'bị cảm lạnh', 'I caught a cold last week.'),
    ('catch a bus', 'bắt xe buýt', 'I catch the bus at seven.'),
    ('break the news', 'thông báo tin (buồn)', 'She broke the news gently.'),
    ('keep a promise', 'giữ lời hứa', 'He always keeps his promises.'),
    ('keep quiet', 'giữ im lặng', 'Please keep quiet in the library.'),
    ('save time', 'tiết kiệm thời gian', 'This shortcut saves time.'),
    ('save money', 'tiết kiệm tiền', 'She saves money every month.'),
    ('pay attention', 'chú ý', 'Pay attention to the teacher.'),
    ('pay a visit', 'đi thăm', 'We paid a visit to our old school.'),
    ('lose weight', 'giảm cân', 'He lost weight by running.'),
    ('gain experience', 'tích lũy kinh nghiệm', 'You gain experience over time.'),
    ('run a business', 'điều hành doanh nghiệp', 'She runs a small business.'),
    ('set a goal', 'đặt mục tiêu', 'Set a goal and work toward it.'),
    ('reach an agreement', 'đạt được thỏa thuận', 'They reached an agreement.'),
    ('miss a chance', 'bỏ lỡ cơ hội', "Don't miss this chance."),
    ('give advice', 'cho lời khuyên', 'My father gave me good advice.'),
    ('give a speech', 'phát biểu', 'She gave a speech at the wedding.'),
    ('get married', 'kết hôn', 'They got married in spring.'),
    ('get ready', 'chuẩn bị sẵn sàng', 'Get ready for school.'),
    ('go abroad', 'ra nước ngoài', 'He went abroad to study.'),
    ('go on a trip', 'đi du lịch', 'We went on a trip to Da Lat.'),
    ('earn a living', 'kiếm sống', 'She earns a living as a teacher.'),
    ('face a problem', 'đối mặt vấn đề', 'We are facing a big problem.'),
    ('solve a problem', 'giải quyết vấn đề', 'They solved the problem quickly.'),
    ('draw a conclusion', 'rút ra kết luận', 'We drew a conclusion from the data.'),
    ('raise a question', 'đặt câu hỏi', 'She raised an interesting question.'),
    ('hold a meeting', 'tổ chức cuộc họp', 'They hold a meeting every Monday.'),
    ('take place', 'diễn ra', 'The festival takes place in autumn.'),
    ('come true', 'trở thành hiện thực', 'Her dream came true.'),
    ('make sense', 'có lý; hợp lý', 'Your plan makes sense.'),
    ('in the long run', 'về lâu dài', 'Reading pays off in the long run.'),
    ('on the other hand', 'mặt khác', 'On the other hand, it is cheaper.'),
    ('at first sight', 'ngay từ cái nhìn đầu', 'It was love at first sight.'),
    ('by heart', 'thuộc lòng', 'She knows the poem by heart.'),
    ('from time to time', 'thỉnh thoảng', 'We meet from time to time.'),
]

VOCAB_COLLOCATIONS = (
    _spec(
        'seed_vocab_collocations',
        'Collocations thông dụng (lõi 50)',
        'Common collocations with examples',
        'Cụm từ kết hợp tự nhiên trong tiếng Anh, kèm nghĩa Việt và ví dụ. '
        'Lộ trình mở rộng (v2).',
        'B2',
        ['collocations', 'fluency'],
    ),
    [_entry(w, m, '', ex) for (w, m, ex) in _COLLOCATIONS],
)

# --------------------------------------------------------------------------
# Pack 10 — IELTS Academic Wordlist theo chủ đề (60 từ lõi tự tuyển theo
# phong cách NAWL; v2 nạp NAWL CSV khi có network).
# --------------------------------------------------------------------------

_ACADEMIC: list[tuple[str, str, str]] = [
    # Nhóm nghiên cứu
    ('analyze', 'phân tích', 'We analyzed the survey results.'),
    ('approach', 'cách tiếp cận', 'She took a new approach to the problem.'),
    ('assess', 'đánh giá', 'They assessed the damage after the storm.'),
    ('assume', 'giả định', 'We assume the plan will work.'),
    ('concept', 'khái niệm', 'The concept is hard to explain.'),
    ('conclude', 'kết luận', 'The study concluded that sleep matters.'),
    ('data', 'dữ liệu', 'The data shows a clear trend.'),
    ('define', 'định nghĩa', 'Define the key terms first.'),
    ('demonstrate', 'chứng minh', 'The experiment demonstrates the effect.'),
    ('derive', 'suy ra; bắt nguồn', 'The word derives from Latin.'),
    ('evaluate', 'đánh giá (giá trị)', 'We evaluated the results carefully.'),
    ('evidence', 'bằng chứng', 'There is strong evidence for this theory.'),
    ('factor', 'yếu tố', 'Cost is an important factor.'),
    ('hypothesis', 'giả thuyết', 'The hypothesis needs more testing.'),
    ('identify', 'xác định', 'Identify the main cause of the problem.'),
    ('indicate', 'chỉ ra', 'The results indicate a change.'),
    ('interpret', 'diễn giải', 'How do you interpret this poem?'),
    ('investigate', 'điều tra; nghiên cứu', 'They investigated the causes.'),
    ('method', 'phương pháp', 'This method saves time.'),
    ('occur', 'xảy ra', 'Storms occur often in summer.'),
    ('phenomenon', 'hiện tượng', 'Lightning is a natural phenomenon.'),
    ('predict', 'dự đoán', 'It is hard to predict the weather.'),
    ('publish', 'xuất bản; công bố', 'The journal published her paper.'),
    ('research', 'nghiên cứu', 'His research focuses on climate.'),
    ('significant', 'đáng kể; quan trọng', 'There was a significant increase.'),
    ('source', 'nguồn', 'Milk is a good source of calcium.'),
    ('survey', 'khảo sát', 'The survey included 1,000 people.'),
    ('theory', 'lý thuyết', 'The theory is widely accepted.'),
    ('vary', 'thay đổi; khác nhau', 'Prices vary from shop to shop.'),
    ('verify', 'xác minh', 'Please verify your email address.'),
    # Nhóm xã hội
    ('authority', 'chính quyền; uy quyền', 'Local authorities closed the road.'),
    ('benefit', 'lợi ích', 'Exercise has many benefits.'),
    ('community', 'cộng đồng', 'The community welcomed the project.'),
    ('culture', 'văn hóa', 'Every culture has its own festivals.'),
    ('economy', 'nền kinh tế', 'The economy is growing fast.'),
    ('environment', 'môi trường', 'We must protect the environment.'),
    ('policy', 'chính sách', 'The new policy starts next year.'),
    ('population', 'dân số', 'The population of the city is rising.'),
    ('role', 'vai trò', 'Teachers play an important role.'),
    ('society', 'xã hội', 'Technology changes society.'),
    ('structure', 'cấu trúc', 'The structure of the essay is clear.'),
    ('tradition', 'truyền thống', 'It is a family tradition.'),
    # Nhóm học thuật chung
    ('achieve', 'đạt được', 'She achieved her goal.'),
    ('affect', 'ảnh hưởng', 'The weather affects our mood.'),
    ('available', 'có sẵn', 'The book is available online.'),
    ('challenge', 'thách thức', 'Learning a language is a challenge.'),
    ('complex', 'phức tạp', 'The issue is more complex than it seems.'),
    ('consequence', 'hậu quả', 'Every action has consequences.'),
    ('contribute', 'đóng góp', 'Everyone contributed to the project.'),
    ('create', 'tạo ra', 'Artists create beauty.'),
    ('develop', 'phát triển', 'The program develops new skills.'),
    ('effect', 'tác động; hiệu ứng', 'The medicine had no effect.'),
    ('establish', 'thành lập', 'They established the school in 1990.'),
    ('focus', 'tập trung; tiêu điểm', 'Focus on the main idea.'),
    ('function', 'chức năng', 'The heart has a vital function.'),
    ('impact', 'tác động', 'The storm had a huge impact.'),
    ('increase', 'tăng lên', 'Prices increased this year.'),
    ('issue', 'vấn đề', 'We discussed the issue in class.'),
    ('major', 'chính; lớn', 'Traffic is a major problem here.'),
    ('process', 'quá trình', 'Learning is a lifelong process.'),
    ('require', 'đòi hỏi', 'The task requires patience.'),
]

VOCAB_ACADEMIC = (
    _spec(
        'seed_vocab_academic_wordlist',
        'Từ vựng học thuật theo chủ đề (lõi 60)',
        'Academic wordlist by topic (IELTS style)',
        'Từ vựng học thuật tần suất cao theo nhóm chủ đề (nghiên cứu, xã hội, '
        'chung), phong cách NAWL/IELTS, tự soạn nghĩa Việt + ví dụ.',
        'C1',
        ['academic', 'ielts', 'nawl'],
    ),
    [_entry(w, m, '', ex) for (w, m, ex) in _ACADEMIC],
)

# --------------------------------------------------------------------------

VOCAB_PACKS = [
    VOCAB_500_VERBS,
    VOCAB_IRREGULAR,
    VOCAB_PHRASAL,
    VOCAB_NGSL_FAMILY,
    VOCAB_NGSL_STUDY,
    VOCAB_NGSL_TRAVEL,
    VOCAB_NGSL_FEELINGS,
    VOCAB_ADJ_ADV,
    VOCAB_COLLOCATIONS,
    VOCAB_ACADEMIC,
]
