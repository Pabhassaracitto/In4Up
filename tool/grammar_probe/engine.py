"""Reference prototype (SPIKE) — cụm từ + cấu trúc câu cho Tab Đọc.

ĐÂY KHÔNG PHẢI CODE SẢN PHẨM. Đây là bản mẫu thuật toán (Python) để:
  1) chốt ĐỊNH NGHĨA span của từng loại cụm (chunk) TRƯỚC khi viết Dart;
  2) đo độ chính xác trên corpus vàng (corpus.json) để kế hoạch có SỐ THẬT,
     không phải phỏng đoán;
  3) làm đặc tả 1-1 cho bản port sang Dart (lib/features/grammar/**).

Bản Dart TÁI DÙNG hạ tầng đã có trong repo thay vì port từng dòng:
  - tách câu/cụm   : lib/knowledge/text/segmenter.dart (TextSegmenter)
  - loại từ/POS    : lib/features/grammar/services/grammar_lexicon_service.dart
                     + lib/services/syntax_highlighter_service.dart
  - phân tích dòng : lib/features/grammar/services/grammar_analysis_service.dart

Sandbox này KHÔNG có Dart SDK ⇒ bản mẫu viết bằng Python, cùng thuật toán,
để đo chất lượng luật trước khi đầu tư code sản phẩm.

Chạy: python3 tool/grammar_probe/run_probe.py
"""

from __future__ import annotations

import re

# ─────────────────────────────────────────────────────────────────────────────
# 1. CHUẨN HOÁ — typography trước, 1 ký tự ↔ 1 ký tự ⇒ offset không lệch
# ─────────────────────────────────────────────────────────────────────────────

_TYPO = {
    "\u2019": "'", "\u2018": "'", "\u201c": '"', "\u201d": '"',
    "\u2013": "-", "\u2014": "-", "\u00a0": " ", "\u2009": " ",
    "\u200b": " ", "\u2026": ".", "\u02bc": "'",
}


def normalize(text: str) -> str:
    return "".join(_TYPO.get(ch, ch) for ch in text)


_TOKEN_RE = re.compile(r"[^\W\d_]+(?:'[^\W\d_]+)?|\d+(?:[.,]\d+)*|[^\s]", re.UNICODE)


def _src_tokens(text: str):
    return [{"t": m.group(0), "l": m.group(0).lower(), "s": m.start(), "e": m.end()}
            for m in _TOKEN_RE.finditer(text)]


# ─────────────────────────────────────────────────────────────────────────────
# 2. TỪ ĐIỂN (seed) — bản Dart nạp từ assets/grammar/en/*.json
# ─────────────────────────────────────────────────────────────────────────────

DET = set("""a an the this that these those my your his her its our their whose some any no
    every each either neither both all most few little many much several enough another
    such what which whatever whichever""".split())
PRON = set("""i me my mine myself you your yours yourself he him his himself she her hers
    herself it its itself we us our ours ourselves they them their theirs themselves who
    whom whose which what that someone somebody something anyone anybody anything everyone
    everybody everything nobody nothing none one ones us""".split())
SIMPLE_PREP = set("""about above across after against along among around as at before behind
    below beneath beside between beyond by despite down during except for from in inside
    into like near of off on onto out outside over past per since through throughout till to
    toward towards under underneath until up upon via with within without than""".split())
COMPOUND_PREP = [("because", "of"), ("in", "spite", "of"), ("due", "to"), ("according", "to"),
                 ("instead", "of"), ("as", "well", "as"), ("in", "front", "of"), ("next", "to"),
                 ("apart", "from"), ("thanks", "to"), ("prior", "to"), ("close", "to"),
                 ("out", "of"), ("up", "to"), ("together", "with"), ("regardless", "of"),
                 ("in", "case", "of"), ("by", "means", "of"), ("on", "behalf", "of"),
                 ("as", "for"), ("as", "to"), ("rather", "than")]
SUBORDINATORS = set("""because although though while when whenever where wherever if unless
    until till since after before as once whether that than so whereas""".split())
CONJ = set("""and or but nor so yet for""".split())
AUX_FORMS = {}
for _base, _forms in {"be": ["am", "is", "are", "was", "were", "be", "being", "been"],
                      "have": ["have", "has", "had", "having"],
                      "do": ["do", "does", "did", "doing", "done"]}.items():
    for _f in _forms:
        AUX_FORMS[_f] = _base
MODALS = set("""can could may might must shall should will would ought had used better
    need dare""".split())
NEGATORS = set("""not never no nothing nobody none neither nor hardly scarcely barely rarely
    seldom without""".split())
PARTICLES = set("""up down off out in on over away back through about along around by for
    into to against across at after""".split())
DEGREE_ADV = set("""very really quite rather so too extremely pretty fairly slightly
    completely totally absolutely almost nearly""".split())
PLAIN_ADV = set("""here there now then yesterday today tomorrow soon later early late again
    once twice outside home upstairs downstairs abroad everywhere somewhere anywhere nowhere
    always usually often sometimes never ever already still just probably certainly
    definitely hard fast well""".split())
WH_WORDS = set("""what who whom whose which when where why how whatever whoever whichever
    whenever wherever however""".split())
LINKING = set("""become seem look feel taste sound smell get grow turn remain stay appear
    prove""".split())
DITRANSITIVE = set("""give send tell show offer bring teach buy write read pass lend promise
    ask cost wish hand throw pay owe allow deny grant sell sing cook make""".split())
COMPLEX_TRANSITIVE = set("""make call name consider find keep leave elect appoint think
    believe declare prove judge nominate""".split())
SVOA = set("""put place set lay send bring take throw hang keep drive lead carry invite""".split())
PHRASAL_VERB_LIST = """give up|look after|put off|turn on|turn off|turn down|pick up|take off|
    get up|wake up|find out|figure out|carry on|go on|come back|come in|get on|get off|
    shut down|log in|log out|fill in|hand in|hand out|work out|break down|bring up|call off|
    set up|deal with|look for|look up|come up with|get along|take after|give back|grow up|
    throw away|try on|put on|switch on|switch off|clean up|eat out|sit down|stand up|lie down|
    look forward to|run out of|put away|turn up|turn around|pay back""".replace("\n", " ").split("|")
PHRASAL_PAIRS = set(tuple(v.strip().split()) for v in PHRASAL_VERB_LIST)
PHRASAL_VERB_BASES = set(pair[0] for pair in PHRASAL_PAIRS if len(pair) == 2)
INTJ = set("""please oh wow hey ah yes no well hi hello thanks sorry""".split())
ADJ_WORDS = set("""happy sad good bad big small new old young beautiful interesting tired
    hungry kind smart cold hot easy hard difficult important expensive cheap tall short long
    fast slow strong weak rich poor busy free dark light green red blue black white careful
    dangerous famous funny gentle heavy lucky modern natural nervous polite quiet ready
    serious sick silly useful warm wet wrong right sure clear main full open close""".split())
DEGREE_ADV_OR_PLAIN = DEGREE_ADV | PLAIN_ADV | {"not"}
AMBIG_VERB_PREP = set("""like love want need help work play call use start stop try look
    turn pick watch talk walk run stay mean mind face answer end back pass close open point
    cover cross plan ride drive fly fish joke matter care hope hate prefer post text book
    order value rate score judge guard share sound form place""".split())
NOUN_EXTRA = set("""english spanish french chinese japanese vietnamese korean german italian
    russian polish turkish swedish danish finnish irish scottish business news series
    species analysis basis crisis physics mathematics politics economics""".split())
ADJ_ING = set("""interesting exciting boring tiring surprising amazing relaxing confusing
    embarrassing disappointing worrying satisfying challenging rewarding moving outstanding
    missing willing leading living dying surprising""".split())
NUMBER_WORDS = set("""one two three four five six seven eight nine ten eleven twelve twenty
    thirty hundred thousand million first second third""".split())
NOUN_SUFFIX = ("tion", "sion", "ment", "ness", "ity", "ance", "ence", "ship", "hood", "ism",
               "ist", "er", "or", "age", "ure", "dom", "age", "ance")
ADJ_SUFFIX = ("ous", "ful", "ive", "able", "ible", "al", "ic", "less", "ish", "ary", "ent",
              "ant")
VERB_SUFFIX = ("ize", "ise", "ify", "ate", "en")
ADV_EXC = {"friendly", "lonely", "lovely", "likely", "daily", "early", "weekly", "monthly",
           "yearly", "silly", "ugly", "only", "family", "italy", "reply", "apply", "supply",
           "rely", "imply", "multiply", "holy", "july", "assembly", "study", "carry"}
S_BASE_VERBS = set("""like love want need help work study learn play watch call use start stop
    try look turn pick rain snow grow stay live happen die belong exist arrive walk run sit
    stand rise fall swim laugh cry smile talk speak read write break open close touch forget
    remember know think see hear eat drink sleep wake quit submit deliver build finish wait
    prove elect appoint consider name keep leave make send spend buy sell give talk join
    enjoy own marry visit clean fix sing dance travel drive ride fly wish hope matter care
    prefer hate offer promise refuse decide agree explain describe suggest repeat answer
    arrive happen change check choose complain continue control cost cover create cross
    decide deliver depend describe destroy develop die divide doubt drop dry earn employ
    enter expect fail feel fight fill follow forget forgive fry guess hang hate hide hunt
    hurt improve include increase invent invite join judge jump kick kill kiss knock land
    last laugh learn lend lie lift listen lose love manage mark marry matter mean measure
    meet melt mind miss mix move need notice obey occur open order pack paint park pass
    perform permit pick plan plant play point practice prefer prepare present press prevent
    produce promise protect prove provide pull push quit rain reach realize receive reduce
    refuse regret relax remain remember remind remove repair repeat replace reply report
    rescue respect rest return ride ring rise roll rub sail save search seem sell send
    separate serve set shake shout show shut sing sink sit sleep slide smell smile smoke
    solve sound speak spell spend spill split spoil spot spread stand start stay steal
    stick stop stretch study succeed suffer suggest supply support suppose surprise survive
    swim switch take talk taste teach tear tell thank think throw tidy tie touch train
    translate travel treat trust try turn type understand unite urge use value visit wait
    wake walk want warm warn wash waste watch wave wear weigh welcome win wind wish wonder
    worry wrap write yell""".split())

IRREGULAR = {
    "be": ("was", "been"), "have": ("had", "had"), "do": ("did", "done"),
    "go": ("went", "gone"), "say": ("said", "said"), "get": ("got", "gotten"),
    "make": ("made", "made"), "know": ("knew", "known"), "think": ("thought", "thought"),
    "take": ("took", "taken"), "see": ("saw", "seen"), "come": ("came", "come"),
    "give": ("gave", "given"), "find": ("found", "found"), "tell": ("told", "told"),
    "become": ("became", "become"), "show": ("showed", "shown"), "leave": ("left", "left"),
    "feel": ("felt", "felt"), "put": ("put", "put"), "bring": ("brought", "brought"),
    "begin": ("began", "begun"), "keep": ("kept", "kept"), "hold": ("held", "held"),
    "write": ("wrote", "written"), "stand": ("stood", "stood"), "hear": ("heard", "heard"),
    "let": ("let", "let"), "mean": ("meant", "meant"), "set": ("set", "set"),
    "meet": ("met", "met"), "run": ("ran", "run"), "pay": ("paid", "paid"),
    "sit": ("sat", "sat"), "speak": ("spoke", "spoken"), "lie": ("lay", "lain"),
    "lead": ("led", "led"), "read": ("read", "read"), "grow": ("grew", "grown"),
    "lose": ("lost", "lost"), "fall": ("fell", "fallen"), "send": ("sent", "sent"),
    "build": ("built", "built"), "understand": ("understood", "understood"),
    "draw": ("drew", "drawn"), "break": ("broke", "broken"), "spend": ("spent", "spent"),
    "cut": ("cut", "cut"), "rise": ("rose", "risen"), "drive": ("drove", "driven"),
    "buy": ("bought", "bought"), "wear": ("wore", "worn"), "choose": ("chose", "chosen"),
    "eat": ("ate", "eaten"), "win": ("won", "won"), "forget": ("forgot", "forgotten"),
    "sleep": ("slept", "slept"), "swim": ("swam", "swum"), "throw": ("threw", "thrown"),
    "steal": ("stole", "stolen"), "hide": ("hid", "hidden"), "sing": ("sang", "sung"),
    "ring": ("rang", "rung"), "shake": ("shook", "shaken"), "wake": ("woke", "woken"),
    "fly": ("flew", "flown"), "blow": ("blew", "blown"), "teach": ("taught", "taught"),
    "catch": ("caught", "caught"), "cost": ("cost", "cost"), "hurt": ("hurt", "hurt"),
    "hit": ("hit", "hit"), "quit": ("quit", "quit"), "shut": ("shut", "shut"),
    "strike": ("struck", "struck"), "stick": ("stuck", "stuck"),
}
PAST_FORMS = {v[0]: k for k, v in IRREGULAR.items()}
PP_FORMS = {v[1]: k for k, v in IRREGULAR.items()}
PP_FORMS.setdefault("been", "be")
PP_FORMS.setdefault("had", "have")
PP_FORMS.setdefault("done", "do")


def _inflections(base: str):
    out = {base, base + "s", base + "es"}
    if base.endswith("e"):
        out |= {base + "d", base[:-1] + "ing"}
    elif len(base) > 2 and base[-1] not in "aeiou" and base[-2] in "aeiou" and base[-3] not in "aeiou":
        out |= {base + base[-1] + "ing", base + base[-1] + "ed"}
    else:
        out |= {base + "ing", base + "ed"}
    if base.endswith("y") and base[-2] not in "aeiou":
        out |= {base[:-1] + "ies", base[:-1] + "ied"}
    return out


PHRASAL_FORMS = {}
for _base in PHRASAL_VERB_BASES:
    for _f in _inflections(_base):
        PHRASAL_FORMS[_f] = _base


def is_vbn(w: str) -> bool:
    return w in PP_FORMS or (w.endswith("ed") and w not in DET and w not in {"red", "need"})


def is_vbd(w: str) -> bool:
    return w in PAST_FORMS or (w.endswith("ed") and w not in DET and w not in {"red", "need"})


def lemma_of(surface: str, form: str) -> str:
    w = surface
    if w in AUX_FORMS:
        return AUX_FORMS[w]
    if form == "vbd" and w in PAST_FORMS:
        return PAST_FORMS[w]
    if form == "vbn" and w in PP_FORMS:
        return PP_FORMS[w]
    if form == "vbz" and w.endswith("s") and w[:-1] in IRREGULAR:
        return w[:-1]
    if form == "vbg" and w.endswith("ing") and len(w) > 5:
        stem = w[:-3]
        for cand in (stem + "e", stem, stem[:-1] if len(stem) > 2 and stem[-1] == stem[-2] else stem):
            if cand in IRREGULAR or cand in S_BASE_VERBS or cand in PHRASAL_FORMS:
                return cand
        return stem
    if form in ("vbd", "vbn") and w.endswith("ed") and len(w) > 4:
        for cand in (w[:-2], w[:-1], w[:-2][:-1] if len(w) > 5 and w[:-2][-1] == w[:-2][-2] else w[:-2]):
            if cand in IRREGULAR or cand in S_BASE_VERBS:
                return cand
        return w[:-2]
    return w


# ─────────────────────────────────────────────────────────────────────────────
# 3. CONTRACTION EXPANSION
# ─────────────────────────────────────────────────────────────────────────────

_EXPLICIT = {
    "don't": ("do", "not"), "doesn't": ("does", "not"), "didn't": ("did", "not"),
    "can't": ("can", "not"), "cannot": ("can", "not"), "won't": ("will", "not"),
    "isn't": ("is", "not"), "aren't": ("are", "not"), "wasn't": ("was", "not"),
    "weren't": ("were", "not"), "hasn't": ("has", "not"), "haven't": ("have", "not"),
    "hadn't": ("had", "not"), "shouldn't": ("should", "not"), "wouldn't": ("would", "not"),
    "couldn't": ("could", "not"), "mustn't": ("must", "not"), "didnt": ("did", "not"),
    "dont": ("do", "not"), "i'm": ("i", "am"), "i've": ("i", "have"), "i'll": ("i", "will"),
    "i'd": ("i", "would"), "you're": ("you", "are"), "we're": ("we", "are"),
    "they're": ("they", "are"), "let's": ("let", "us"), "o'clock": ("o", "clock"),
}


def expand_contractions(src):
    out = []
    for i, tok in enumerate(src):
        low = tok["l"]
        nxt = src[i + 1]["l"] if i + 1 < len(src) else ""
        if low in _EXPLICIT:
            a, b = _EXPLICIT[low]
            out.append({**tok, "t": a, "l": a, "s": tok["s"], "e": tok["s"] + len(a),
                        "part_of": (tok["s"], tok["e"])})
            out.append({**tok, "t": b, "l": b, "s": tok["s"] + len(a), "e": tok["e"],
                        "neg": b == "not", "part_of": (tok["s"], tok["e"])})
            continue
        if low.endswith("'s") and len(low) > 2:
            stem = low[:-2]
            prev_low = out[-1]["l"] if out else ""
            # sở hữu khi: KHÔNG phải đại từ tạo rút gọn, VÀ (viết hoa hoặc sau DET)
            possessive = (stem not in PRON and stem not in ("there", "here", "what", "who",
                                                            "one", "let", "how", "it"))
            possessive = possessive and (tok["t"][:1].isupper() or prev_low in DET or
                                         prev_low in PRON)
            if possessive:
                cut = tok["e"] - 2
                out.append({**tok, "t": stem, "l": stem, "e": cut,
                            "part_of": (tok["s"], tok["e"])})
                out.append({**tok, "t": "'s", "l": "'s", "s": cut, "e": tok["e"],
                            "poss": True, "part_of": (tok["s"], tok["e"])})
                continue
            as_have = nxt in PP_FORMS or nxt == "been" or (nxt.endswith("ed") and is_vbn(nxt))
            aux = "has" if as_have else "is"
            cut = tok["e"] - 2
            out.append({**tok, "t": tok["t"][:-2], "l": stem, "e": cut,
                        "part_of": (tok["s"], tok["e"])})
            out.append({**tok, "t": "'s", "l": aux, "s": cut, "e": tok["e"],
                        "part_of": (tok["s"], tok["e"])})
            continue
        out.append({**tok, "part_of": (tok["s"], tok["e"])})
    return out


# ─────────────────────────────────────────────────────────────────────────────
# 4. POS TAGGER (rút gọn — bản Dart dùng GrammarLexiconService)
# ─────────────────────────────────────────────────────────────────────────────

COMPARATIVE_IRREG = set("""better worse best worst more most less least
    further further furthest elder eldest""".split())

PUNCT = set(".,;:!?()[]\"'—-")


_ADJ_SUFFIXES = ("ous", "ful", "ive", "able", "ible", "less", "ary", "ish", "al", "ic")


def _adj_suffix_ok(w):
    """Đuôi tính từ chỉ tính khi gốc còn ≥2 ký tự ('comfortable' ✓ / 'table' ✗)."""
    for suf in _ADJ_SUFFIXES:
        if w.endswith(suf) and len(w) - len(suf) >= 2:
            return True
    return False


def tag_tokens(toks):
    n = len(toks)
    for i, tk in enumerate(toks):
        w = tk["l"]
        prev = toks[i - 1]["l"] if i else ""
        nxt = toks[i + 1]["l"] if i + 1 < n else ""
        tag, form, lemma = "UNK", "", w

        if w in PUNCT or (len(w) == 1 and not w.isalnum()):
            tag = "PUNCT"
        elif tk.get("poss"):
            tag, lemma = "DET", "'s"
        elif w in INTJ:
            tag = "INTJ"
        elif w in NOUN_EXTRA:
            tag = "NOUN"
        elif w in ADJ_ING:
            tag = "ADJ"
        elif w in COMPARATIVE_IRREG:
            tag = "ADJ"
        elif w.endswith("er") and len(w) > 4 and w[:-2] in ADJ_WORDS:
            tag = "ADJ"
        elif w.endswith("est") and len(w) > 5 and w[:-3] in ADJ_WORDS:
            tag = "ADJ"
        elif tk.get("neg") or w in NEGATORS:
            tag = "NEG"
        elif w == "whose" and nxt not in ("is", "are", "was", "were", "", "?"):
            tag = "DET"
        elif w in WH_WORDS:
            tag = "WH"
        elif w in ("will", "shall"):
            tag, form, lemma = "MODAL", "future", w
        elif w in MODALS and w not in ("had", "better"):
            tag, form, lemma = "MODAL", "modal", w
        elif w in ("had",) and nxt == "better":
            tag, form, lemma = "MODAL", "modal", "had"
        elif w in AUX_FORMS:
            form = {"am": "present", "is": "present", "are": "present", "was": "past",
                    "were": "past", "have": "present", "has": "present", "had": "past",
                    "do": "present", "does": "present", "did": "past",
                    "been": "vbn", "being": "vbg", "having": "vbg"}.get(w, "base")
            tag, lemma = "AUX", AUX_FORMS[w]
        elif w in DET:
            tag = "DET"
        elif w in PRON:
            tag = "PRON"
        elif w == "to":
            tag = "TO"
        elif w in DEGREE_ADV_OR_PLAIN:
            tag = "ADV"
        elif prev in ("a", "an", "the", "this", "that", "these", "those", "my", "your",
                      "his", "her", "its", "our", "their") and not w.endswith("ly") \
                and not w.endswith("ing"):
            tag = "ADJ" if (w in ADJ_WORDS) else "NOUN"
        elif w in SIMPLE_PREP and w in AMBIG_VERB_PREP and (
                prev in ("i", "you", "we", "they", "he", "she", "it", "who", "that")
                or prev in AUX_FORMS
                or (i > 0 and toks[i - 1]["tag"] in ("MODAL", "NEG", "TO", "AUX"))):
            tag = "VERB"
        elif w in SIMPLE_PREP:
            tag = "PREP"
        elif w in SUBORDINATORS and any(
                seq[0] == w and len(seq) > 1 and nxt == seq[1] for seq in COMPOUND_PREP):
            tag = "PREP"
        elif w in CONJ:
            tag = "CONJ"
        elif w in SUBORDINATORS:
            tag = "SUB"
        elif w in NUMBER_WORDS or re.fullmatch(r"\d+(?:[.,]\d+)*", w):
            tag = "NUM"
        elif prev in ("have", "has", "had") and (w in PP_FORMS or w.endswith("ed")
                                                 or w.endswith("en")):
            tag, form, lemma = "VERB", "vbn", PP_FORMS.get(w, lemma_of(w, "vbn"))
        elif prev in ("be", "is", "are", "was", "were", "been", "being", "am") and \
                (w in PP_FORMS or (w.endswith("ed") and w not in DET)):
            tag, form, lemma = "VERB", "vbn", PP_FORMS.get(w, lemma_of(w, "vbn"))
        elif w in PP_FORMS and prev in ("to",):
            tag, form, lemma = "VERB", "vbn", PP_FORMS[w]
        elif w in PP_FORMS and w not in PAST_FORMS:
            tag, form, lemma = "VERB", "vbn", PP_FORMS[w]
        elif w in PAST_FORMS:
            tag, form, lemma = "VERB", "vbd", PAST_FORMS[w]
        elif w.endswith("ing") and len(w) > 4:
            tag, form, lemma = "VERB", "vbg", lemma_of(w, "vbg")
        elif w.endswith("ed") and len(w) > 3 and w not in DET:
            tag, form, lemma = "VERB", "vbd", lemma_of(w, "vbd")
        elif w.endswith("s") and len(w) > 2 and w[:-1] in IRREGULAR:
            tag, form, lemma = "VERB", "vbz", w[:-1]
        elif w.endswith("es") and len(w) > 3 and (
                w[:-2] in S_BASE_VERBS or w[:-2] in PHRASAL_FORMS):
            tag, form, lemma = "VERB", "vbz", w[:-2]
        elif w.endswith("s") and len(w) > 2 and (
                w[:-1] in S_BASE_VERBS or w[:-1] in PHRASAL_FORMS):
            tag, form, lemma = "VERB", "vbz", w[:-1]
        elif w in PHRASAL_FORMS or w in S_BASE_VERBS or w.endswith(VERB_SUFFIX):
            tag, form, lemma = "VERB", "vb", lemma_of(w, "vb")
        elif w in PLAIN_ADV:
            tag = "ADV"
        elif w.endswith("ly") and w not in ADV_EXC:
            tag = "ADV"
        elif w in ADJ_WORDS or _adj_suffix_ok(w):
            tag = "ADJ"
        elif w.endswith(("al", "ic", "ent", "ant", "y")) and (
                prev in ("is", "are", "was", "were", "am", "be", "very", "really", "so",
                         "too", "extremely", "quite", "rather", "looks", "look", "seems",
                         "seem", "feels", "feel", "becomes", "became", "get", "gets", "got")):
            tag = "ADJ"
        else:
            tag = "NOUN"
        tk["tag"], tk["form"], tk["lemma"] = tag, form, lemma
    return toks


# ─────────────────────────────────────────────────────────────────────────────
# 5. TÁCH CÂU / MỆNH ĐỀ (bản Dart: TextSegmenter)
# ─────────────────────────────────────────────────────────────────────────────

_ABBREV = {"mr", "mrs", "ms", "dr", "prof", "sr", "jr", "st", "vs", "etc", "eg", "ie",
           "pm", "am", "no", "inc", "ltd", "approx", "fig", "vol"}


def sentence_spans(text: str):
    out, start = [], 0
    for m in re.finditer(r"[.!?]+", text):
        i = m.start()
        prev_m = re.search(r"[^\W\d_]+$", text[:i], re.UNICODE)
        prev = prev_m.group(0).lower() if prev_m else ""
        nxt = text[m.end():m.end() + 1]
        if m.group(0).startswith("."):
            if prev in _ABBREV or len(prev) == 1:
                continue
            if i >= 1 and text[i - 1].isdigit() and nxt.isdigit():
                continue
            if re.search(r"(?:[^\W\d_]\.){2,}$", text[:i + 1], re.UNICODE):
                continue
            if nxt and not nxt.isspace():
                continue
        out.append((start, m.end()))
        start = m.end()
    if start < len(text) and text[start:].strip():
        out.append((start, len(text)))
    return out or [(0, len(text))]


def clause_spans(text, lo, hi, toks):
    cuts = [lo]
    for i, tk in enumerate(toks):
        if tk["e"] <= lo or tk["s"] >= hi:
            continue
        if tk["t"] in (",", ";", ":"):
            cuts.append(tk["e"])
        elif tk["tag"] == "CONJ":
            window = toks[i + 1:i + 7]
            has_finite = any(t["tag"] in ("AUX", "MODAL") or
                             (t["tag"] == "VERB" and t["form"] in ("vbd", "vbz", "vb", ""))
                             for t in window)
            has_subject = any(t["tag"] in ("PRON", "NOUN", "DET") for t in window[:3])
            if has_finite and has_subject:
                cuts.append(tk["s"])
    cuts = sorted(set(cuts + [hi]))
    spans = [(cuts[i], cuts[i + 1]) for i in range(len(cuts) - 1)]
    spans = [(a, b) for a, b in spans if text[a:b].strip()]
    return spans or [(lo, hi)]


def tok_in_span(tk, span):
    return tk["s"] >= span[0] and tk["e"] <= span[1]


# ─────────────────────────────────────────────────────────────────────────────
# 6. VERB CHAIN
# ─────────────────────────────────────────────────────────────────────────────

_SPECIAL_TO_HEADS = {"going", "used", "have", "has", "had", "ought", "better",
                     "supposed", "able", "about"}

_CHAIN_ADV = {"never", "always", "often", "usually", "just", "already", "still",
              "probably", "really", "hardly", "rarely", "seldom", "ever", "not", "simply",
              "definitely", "certainly", "actually", "almost", "only", "also", "finally"}


def is_chain_token(tk):
    if tk["tag"] in ("AUX", "MODAL", "NEG", "VERB"):
        return True
    return tk["tag"] == "ADV" and tk["l"] in _CHAIN_ADV


def verb_chain_at(toks, i, limit=None):
    """Nhóm động từ quanh token i. Trả (idx list, parts list) — parts để render."""
    limit = len(toks) if limit is None else limit
    if not is_chain_token(toks[i]) or toks[i]["tag"] not in ("AUX", "MODAL", "VERB"):
        return None
    idx = [i]
    # mở rộng trái (CHỈ trợ động từ/khuyết thiếu/phủ định/trạng từ chen —
    # không nuốt V-ing/V-ed: "Swimming is…" có chủ ngữ là danh động từ)
    k = i - 1
    while k >= 0 and (toks[k]["tag"] in ("AUX", "MODAL", "NEG")
                      or (toks[k]["tag"] == "ADV" and toks[k]["l"] in _CHAIN_ADV)):
        idx.insert(0, k)
        k -= 1
    # mở rộng phải (nếu chuỗi BẮT ĐẦU bằng V-ing/V-ed trần thì dừng trước AUX:
    # "Swimming is good" — 'Swimming' là chủ ngữ danh động từ, không thuộc 'is')
    k = i + 1
    while k < limit and is_chain_token(toks[k]):
        if toks[k]["tag"] in ("DET", "PRON", "NOUN", "ADJ", "NUM", "PUNCT"):
            break
        if toks[k]["tag"] in ("AUX", "MODAL") and toks[idx[0]]["tag"] == "VERB" and \
                toks[idx[0]]["form"] in ("vbg", "vbn"):
            break
        idx.append(k)
        k += 1
    # bắc qua chủ ngữ TRONG CÂU HỎI: aux ... [subject] ... verb
    # (chỉ khi aux đứng ĐẦU mệnh đề — nếu trước nó là chủ ngữ thì đây là câu kể)
    clause_initial = idx[0] == 0 or toks[idx[0] - 1]["tag"] in ("PUNCT", "WH", "CONJ", "SUB")
    if clause_initial and toks[idx[-1]]["tag"] in ("AUX", "MODAL") and k < limit:
        j = k
        bridge = []
        while j < limit and j - k < 5 and (
                toks[j]["tag"] in ("PRON", "DET", "NOUN", "ADJ", "NUM")
                or (toks[j]["tag"] == "ADV" and toks[j]["l"] in _CHAIN_ADV)):
            bridge.append(j)
            j += 1
        if bridge and j < limit and toks[j]["tag"] in ("AUX", "MODAL", "VERB"):
            idx.extend(bridge)
            idx.extend(range(j, j + 1))
    # chuỗi đặc biệt: going to V / used to V / have to V / ought to V
    last = idx[-1]
    if toks[last]["l"] in ("going", "used", "have", "has", "had", "ought", "better") \
            and last + 2 < limit and toks[last + 1]["l"] == "to" \
            and toks[last + 2]["tag"] == "VERB":
        be_in_chain = any(toks[k]["l"] in ("am", "is", "are", "was", "were") for k in idx)
        if toks[last]["l"] == "used" and be_in_chain:
            pass  # "is used to + V-ing" (quen với) ≠ "used to + V" (thói quen)
        else:
            idx.extend([last + 1, last + 2])
    # NEG/ADV ở mép trái mà trước nó không có động từ ⇒ bỏ trước khi bắc cầu
    while len(idx) > 1 and toks[idx[0]]["tag"] in ("NEG", "ADV"):
        idx.pop(0)
    # bắc TRÁI qua chủ ngữ trong câu hỏi: [aux] + subject + [verb]
    if idx and toks[idx[0]]["tag"] in ("VERB", "AUX", "MODAL"):
        j = idx[0] - 1
        bridge = []
        while j >= 0 and (idx[0] - j) <= 5 and (
                toks[j]["tag"] in ("PRON", "DET", "NOUN", "ADJ", "NUM")
                or (toks[j]["tag"] == "ADV" and toks[j]["l"] in _CHAIN_ADV)):
            bridge.insert(0, j)
            j -= 1
        if bridge and j >= 0 and toks[j]["tag"] in ("AUX", "MODAL"):
            idx = [j] + bridge + idx
    # mở rộng TRÁI cho chuỗi bán-khuyết-thiếu: going to / used to / have to / ought to
    k = idx[0] - 1
    if k >= 1 and toks[k]["l"] == "to" and toks[k - 1]["l"] in _SPECIAL_TO_HEADS:
        head = toks[k - 1]
        # 'be used to + V-ing' (quen với) KHÁC 'used to + V' (thói quen quá khứ)
        be_before = any(toks[j]["l"] in ("am", "is", "are", "was", "were")
                        for j in range(max(0, k - 4), k - 1))
        if not (head["l"] == "used" and be_before):
            idx = [k - 1, k] + idx
            k2 = k - 2
            while k2 >= 0 and toks[k2]["tag"] in ("AUX", "MODAL", "NEG"):
                idx.insert(0, k2)
                k2 -= 1
    if not idx:
        return None
    parts = []
    for k in idx:
        if parts and parts[-1][1] + 1 == k:
            parts[-1] = (parts[-1][0], k)
        else:
            parts.append((k, k))
    return idx, parts


def chain_has_finite(toks, idx):
    if any(toks[k]["tag"] in ("AUX", "MODAL") for k in idx):
        return True
    return any(toks[k]["tag"] == "VERB" and toks[k]["form"] in ("vbd", "vbz", "vb", "base", "")
               for k in idx)


def chain_finite(toks, char_span, limit):
    """Chuỗi hữu hạn ĐẦU TIÊN trong span KÝ TỰ (bỏ 'to + V')."""
    i = 0
    while i < len(toks):
        tk = toks[i]
        if not tok_in_span(tk, char_span):
            i += 1
            continue
        if tk["tag"] == "TO" and i + 1 < len(toks) and toks[i + 1]["tag"] == "VERB":
            i += 2
            continue
        if tk["tag"] in ("AUX", "MODAL", "VERB"):
            ch = verb_chain_at(toks, i, limit)
            if ch:
                idx = [k for k in ch[0] if tok_in_span(toks[k], char_span)]
                prev_is_to = i - 1 >= 0 and toks[i - 1]["tag"] == "TO" and \
                    tok_in_span(toks[i - 1], char_span)
                if idx and chain_has_finite(toks, idx) and not prev_is_to:
                    return idx
        i += 1
    return None


def read_verb_group(toks, idx):
    """(tense, aspect, voice, modal, has_neg, words) cho một nhóm động từ."""
    words = [toks[i]["l"] for i in idx]
    tags = [toks[i]["tag"] for i in idx]
    forms = [toks[i]["form"] for i in idx]
    has_neg = any(t == "NEG" for t in tags)

    modal = next((w for w in words if w in MODALS and w not in ("had", "better")), None)
    if "had" in words and "better" in words:
        modal = "had better"
    if modal == "used" and any(w in ("am", "is", "are", "was", "were")
                               for w in words[:words.index("used")]):
        modal = None  # "be used to": 'used' là tính từ

    # trợ động từ HAVE chỉ khi có phân từ theo sau ("have lunch" KHÔNG phải perfect)
    have_aux = None
    for k, w in enumerate(words):
        if w in ("have", "has", "had") and any(f == "vbn" for f in forms[k + 1:]):
            have_aux = k
            break

    be_idx = next((k for k, w in enumerate(words)
                   if w in ("am", "is", "are", "was", "were", "be", "been", "being")), None)
    ing = any(f == "vbg" for f in forms)
    going_to = "going" in words and "to" in words
    voice = "passive" if _is_passive(toks, idx) else "active"

    if have_aux is not None:
        aspect = "perfect"
        if any(f == "vbg" for f in forms[have_aux + 1:]):
            aspect = "perfect_continuous"
    elif ing and be_idx is not None and be_idx < len(forms) - 1:
        aspect = "continuous"
    else:
        aspect = "simple"

    if "will" in words or "shall" in words or going_to:
        tense = "future"
    elif modal == "used":
        tense = "past"
    elif modal:
        tense = "modal"
    elif have_aux is not None:
        tense = "past" if words[have_aux] == "had" else "present"
    elif "did" in words or "was" in words or "were" in words:
        tense = "past"
    elif any(toks[k]["tag"] == "AUX" and toks[k]["form"] == "past" for k in idx):
        tense = "past"
    elif any(toks[k]["tag"] == "AUX" and toks[k]["form"] == "present" for k in idx):
        tense = "present"
    elif any(is_vbd(w) for w in words) and words[0] not in ("have", "has", "had"):
        tense = "past"
    else:
        tense = "present"
    if going_to:
        aspect = "simple"
    return tense, aspect, voice, modal, has_neg, words


def _is_passive(toks, idx):
    """be + ĐỘNG TỪ PHÂN TỪ (form vbn) ⇒ bị động. 'be + used/…' là tính từ ⇒ không."""
    for pos, k in enumerate(idx):
        if toks[k]["tag"] != "AUX" or toks[k]["lemma"] != "be":
            continue
        rest = idx[pos + 1:]
        if not rest:
            return False
        nxt = toks[rest[0]]
        if nxt["l"] == "being":
            return len(rest) > 1 and toks[rest[1]]["form"] == "vbn"
        if nxt["form"] == "vbn":
            return True
    return False


# ─────────────────────────────────────────────────────────────────────────────
# 7. CỤM TỪ — candidate spans (idx = token logic, parts = nhóm liền mạch)
# ─────────────────────────────────────────────────────────────────────────────


def _cand(kind, idx, parts=None, note=""):
    idx = sorted(idx)
    if not idx:
        return None
    if parts is None:
        parts = [(idx[0], idx[-1])]
    return {"kind": kind, "idx": idx, "parts": parts, "note": note}


def parts_text(toks, text, parts):
    """Cắt span từ text GỐC (normalize giữ nguyên độ dài) và SNAP về biên token
    nguồn — 'She's finished' chứ không phải "'s finished"."""
    out = []
    for a, b in parts:
        start = toks[a].get("part_of", (toks[a]["s"], toks[a]["e"]))[0]
        end = toks[b].get("part_of", (toks[b]["s"], toks[b]["e"]))[1]
        out.append(text[start:end])
    return " ".join(out)


def _compound_prep_len(toks, i, limit):
    for seq in sorted(COMPOUND_PREP, key=len, reverse=True):
        if all(i + k < limit and toks[i + k]["l"] == seq[k] for k in range(len(seq))):
            return len(seq)
    return 0


def _head_noun_right(toks, i, limit):
    for j in range(i, limit):
        if toks[j]["tag"] in ("NOUN", "PRON", "NUM"):
            return j
        if toks[j]["tag"] in ("VERB", "PREP", "CONJ", "PUNCT", "SUB"):
            return None
    return None


def is_particle(toks, i, limit):
    """Tiểu từ của cụm động từ cố định (không phải giới từ)."""
    if i <= 0 or toks[i]["l"] not in PARTICLES:
        return False
    verb = toks[i - 1]
    if verb["tag"] != "VERB":
        return False
    return (verb["lemma"], toks[i]["l"]) in PHRASAL_PAIRS


NP_COMPLEMENT_PREPS = {"of", "for", "with", "from", "about", "to", "by", "in"}


def build_np(toks, i, limit):
    if toks[i]["tag"] in ("DET", "ADJ", "NUM") or (
            toks[i]["tag"] == "ADV" and i + 1 < limit and toks[i + 1]["tag"] == "ADJ"):
        head = _head_noun_right(toks, i, limit)
        if head is None:
            return None
    elif toks[i]["tag"] in ("NOUN", "PRON", "NUM"):
        head = i
    else:
        return None
    idx = [head]
    # sang trái
    k = head - 1
    while k >= 0 and toks[k]["tag"] in ("DET", "ADJ", "NUM"):
        idx.insert(0, k)
        k -= 1
    while k >= 0 and toks[k]["tag"] == "ADV" and toks[k]["l"] in DEGREE_ADV:
        idx.insert(0, k)
        k -= 1
    if k >= 0 and toks[k]["l"] == "'s":
        idx.insert(0, k)
        if k - 1 >= 0 and toks[k - 1]["tag"] in ("NOUN", "PRON"):
            idx.insert(0, k - 1)
    # sang phải: PP bổ ngữ (không phải tiểu từ), mệnh đề quan hệ, phân từ, danh từ ghép
    b = head
    while b + 1 < limit:
        nxt = toks[b + 1]
        if nxt["tag"] == "PREP" and nxt["l"] in NP_COMPLEMENT_PREPS \
                and not is_particle(toks, b + 1, limit):
            np = build_np(toks, b + 2, limit) if b + 2 < limit else None
            if np and np["idx"][0] <= b + 2:
                idx.extend(np["idx"])
                b = np["idx"][-1]
                continue
            break
        if nxt["tag"] in ("WH",) or nxt["l"] == "that":
            k = _modifier_end(toks, b + 1, limit, allow_finite=1)
            if k <= b:
                break
            idx.extend(range(b + 1, k + 1))
            b = k
            continue
        if nxt["tag"] == "VERB" and nxt["form"] == "vbg":
            k = _modifier_end(toks, b + 1, limit, allow_finite=0)
            if k <= b:
                break
            idx.extend(range(b + 1, k + 1))
            b = k
            continue
        if nxt["tag"] in ("NOUN", "ADJ") and toks[b]["tag"] == "NOUN":
            idx.append(b + 1)
            b += 1
            continue
        break
    return _cand("NP", idx)


def _modifier_end(toks, start, limit, allow_finite=0):
    """Hết span bổ nghĩa (mệnh đề quan hệ / phân từ).

    allow_finite = số chuỗi hữu hạn ĐƯỢC PHÉP nằm trong span (mệnh đề quan hệ có
    động từ riêng = 1; phân từ = 0). Gặp chuỗi hữu hạn vượt hạn mức ⇒ dừng TRƯỚC nó.
    """
    seen_finite = 0
    k = start
    last = start - 1
    while k < limit:
        if toks[k]["t"] in (",", ".", ";", ":", "!", "?"):
            break
        ch = verb_chain_at(toks, k, limit)
        if ch and k in ch[0] and chain_has_finite(toks, ch[0]):
            if seen_finite >= allow_finite:
                break
            seen_finite += 1
            last = ch[0][-1]
            k = ch[0][-1] + 1
            continue
        last = k
        k += 1
    return last


def build_vp(toks, i, limit):
    ch = verb_chain_at(toks, i, limit)
    if ch is None:
        return None
    idx, parts = ch
    if not chain_has_finite(toks, idx):
        return None
    if idx[0] - 1 >= 0 and toks[idx[0] - 1]["tag"] == "TO":
        return None  # to + V ⇒ InfP, không phải VP hữu hạn
    # tiểu từ của cụm động từ cố định
    last = idx[-1]
    if last + 1 < limit and toks[last + 1]["l"] in PARTICLES:
        key = (toks[last]["lemma"], toks[last + 1]["l"])
        if key in PHRASAL_PAIRS:
            idx = idx + [last + 1]
            parts = parts + [(last + 1, last + 1)]
            if last + 2 < limit and toks[last + 2]["tag"] == "PRON":
                idx = idx + [last + 2]
                parts = parts + [(last + 2, last + 2)]
            return _cand("PHRASAL_V", idx, parts)
    return _cand("VP", idx, parts)


def build_phrasal_at_particle(toks, i, limit):
    """Anchor rơi vào tiểu từ: "looked after", "pick it up"."""
    if toks[i]["l"] not in PARTICLES:
        return None
    if is_particle(toks, i, limit):
        idx = [i - 1, i]
        if i + 1 < limit and toks[i + 1]["tag"] == "PRON":
            idx.append(i + 1)
        return _cand("PHRASAL_V", idx)
    # verb + PRON + particle  ("pick it up")
    if i >= 2 and toks[i - 1]["tag"] == "PRON" and toks[i - 2]["tag"] == "VERB":
        if (toks[i - 2]["lemma"], toks[i]["l"]) in PHRASAL_PAIRS:
            return _cand("PHRASAL_V", [i - 2, i - 1, i])
    return None


def build_adjp(toks, i, limit):
    if toks[i]["tag"] != "ADJ":
        return None
    idx = [i]
    k = i - 1
    while k >= 0 and toks[k]["tag"] == "ADV" and toks[k]["l"] in DEGREE_ADV:
        idx.insert(0, k)
        k -= 1
    b = i
    if b + 1 < limit and toks[b + 1]["tag"] == "PREP":
        np = build_np(toks, b + 2, limit) if b + 2 < limit else None
        if np:
            idx.extend([b + 1] + np["idx"])
            b = np["idx"][-1]
    if b + 1 < limit and toks[b + 1]["tag"] == "TO":
        k = b + 1
        while k < limit and toks[k]["t"] not in (",", ".", ";", ":", "!", "?"):
            k += 1
        idx.extend(range(b + 1, k))
    return _cand("ADJP", idx)


def build_advp(toks, i, limit):
    if toks[i]["tag"] != "ADV":
        return None
    idx = [i]
    k = i - 1
    while k >= 0 and toks[k]["tag"] == "ADV" and toks[k]["l"] in DEGREE_ADV:
        idx.insert(0, k)
        k -= 1
    return _cand("ADVP", idx)


def build_pp(toks, i, limit):
    n = _compound_prep_len(toks, i, limit)
    if toks[i]["tag"] != "PREP" and n == 0:
        return None
    j = i + n if n > 1 else i + 1
    if j >= limit:
        return None
    np = build_np(toks, j, limit)
    if np is None:
        return None
    return _cand("PP", list(range(i, np["idx"][-1] + 1)))


def build_gerund_inf(toks, i, limit):
    if (toks[i]["tag"] == "TO" and i + 1 < limit and toks[i + 1]["tag"] == "VERB"
            and not (i >= 1 and toks[i - 1]["l"] in _SPECIAL_TO_HEADS)):
        idx = [i, i + 1]
        if i + 2 < limit and toks[i + 2]["l"] in PARTICLES and \
                (toks[i + 1]["lemma"], toks[i + 2]["l"]) in PHRASAL_PAIRS:
            idx.append(i + 2)
        np = build_np(toks, idx[-1] + 1, limit) if idx[-1] + 1 < limit else None
        if np and np["idx"][0] == idx[-1] + 1:
            idx.extend(np["idx"])
        return _cand("InfP", idx)
    if toks[i]["tag"] == "VERB" and toks[i]["form"] == "vbg":
        if _in_finite_chain(toks, i, limit):
            return None  # "is running": V-ing thuộc VP hữu hạn
        idx = [i]
        if i + 1 < limit and toks[i + 1]["l"] in PARTICLES and \
                (toks[i]["lemma"], toks[i + 1]["l"]) in PHRASAL_PAIRS:
            idx.append(i + 1)
        if _is_participial_modifier(toks, i):
            return None  # "the man standing there" ⇒ PartP
        np = build_np(toks, idx[-1] + 1, limit) if idx[-1] + 1 < limit else None
        if np and np["idx"][0] == idx[-1] + 1:
            idx.extend(np["idx"])
        return _cand("GerP", idx)
    return None


def _in_finite_chain(toks, i, limit):
    ch = verb_chain_at(toks, i, limit)
    if not ch:
        return False
    idx = ch[0]
    if not chain_has_finite(toks, idx):
        return False
    return not (idx[0] - 1 >= 0 and toks[idx[0] - 1]["tag"] == "TO")


def _is_participial_modifier(toks, i):
    """V-ing đứng ngay sau danh từ ⇒ bổ nghĩa cho danh từ đó (PartP)."""
    if i == 0:
        return False
    prev = toks[i - 1]
    return prev["tag"] in ("NOUN", "NUM") and prev["l"] not in SUBORDINATORS


def build_participle(toks, i, limit):
    if toks[i]["tag"] != "VERB" or toks[i]["form"] != "vbg":
        return None
    if _in_finite_chain(toks, i, limit):
        return None
    idx = [i]
    b = i
    if b + 1 < limit and toks[b + 1]["l"] in PARTICLES and \
            (toks[i]["lemma"], toks[b + 1]["l"]) in PHRASAL_PAIRS:
        idx.append(b + 1)
        b += 1
    np = build_np(toks, b + 1, limit) if b + 1 < limit else None
    if np and np["idx"][0] == b + 1:
        idx.extend(np["idx"])
        b = np["idx"][-1]
    if b + 1 < limit and toks[b + 1]["tag"] == "ADV":
        idx.append(b + 1)
    return _cand("PartP", idx)


def build_coord(toks, cands, i, limit):
    for c in cands:
        if i not in c["idx"]:
            continue
        b = c["idx"][-1]
        if b + 2 < limit and toks[b + 1]["tag"] == "CONJ" and \
                toks[b + 1]["l"] in ("and", "or", "but", "nor"):
            if c["kind"] == "NP":
                right = build_np(toks, b + 2, limit)
                if right and right["idx"][0] == b + 2:
                    return _cand("COORD", list(range(c["idx"][0], right["idx"][-1] + 1)))
            if c["kind"] == "ADJP":
                right = build_adjp(toks, b + 2, limit)
                if right and right["idx"][0] == b + 2:
                    return _cand("COORD", list(range(c["idx"][0], right["idx"][-1] + 1)))
    return None


def build_clause(toks, i, limit, sent_span):
    a = None
    for k in range(i, -1, -1):
        if not tok_in_span(toks[k], sent_span):
            break
        if toks[k]["t"] in (",", ";", ":"):
            a = k + 1
            break
        if toks[k]["tag"] in ("WH", "SUB") and (k == 0 or toks[k - 1]["t"] in (",", ";", ":")):
            a = k
            break
    if a is None:
        return None
    b = a
    while b + 1 < limit and toks[b + 1]["t"] not in (",", ";", ":", ".", "!", "?"):
        b += 1
    idx = [k for k in range(a, b + 1) if toks[k]["tag"] != "PUNCT"]
    if not idx or i not in idx or b - a < 2:
        return None
    if not any(toks[k]["tag"] in ("AUX", "MODAL", "VERB") for k in idx):
        return None
    return _cand("CLAUSE", idx)


def modifier_spans(toks, limit):
    """Span của mệnh đề quan hệ / cụm phân từ — dùng để loại khỏi mệnh đề CHÍNH."""
    spans = []
    for i, tk in enumerate(toks):
        if i == 0:
            continue
        prev = toks[i - 1]
        if tk["l"] in ("that", "whose") or tk["tag"] == "WH":
            if prev["tag"] in ("NOUN", "PRON", "NUM"):
                end = _modifier_end(toks, i, limit, allow_finite=1)
                if end > i:
                    spans.append((i, end))
        elif tk["tag"] == "VERB" and tk["form"] == "vbg" and prev["tag"] in ("NOUN", "NUM"):
            end = _modifier_end(toks, i, limit, allow_finite=0)
            if end > i:
                spans.append((i, end))
    return spans


def all_candidates(toks, limit, sent_span):
    out = []
    for i in range(limit):
        for fn in (build_np, build_advp, build_adjp, build_pp, build_vp, build_participle,
                   build_gerund_inf):
            c = fn(toks, i, limit)
            if c:
                out.append(c)
    out = [c for c in out if c["idx"] and c["idx"][-1] < limit]
    for i in range(limit):
        c = build_phrasal_at_particle(toks, i, limit)
        if c:
            out.append(c)
    for i in range(limit):
        c = build_clause(toks, i, limit, sent_span)
        if c:
            out.append(c)
    for i in range(limit):
        c = build_coord(toks, list(out), i, limit)
        if c:
            out.append(c)
    # PHRASAL_V trùng token với GerP/PartP ⇒ để GerP/PartP thắng ("waking up")
    gerund_sets = {tuple(c["idx"]) for c in out if c["kind"] in ("GerP", "PartP")}
    out = [c for c in out if not (c["kind"] == "PHRASAL_V" and tuple(c["idx"]) in gerund_sets)]
    # khử trùng
    seen, uniq = set(), []
    for c in out:
        key = (c["kind"], tuple(c["idx"]))
        if key in seen:
            continue
        seen.add(key)
        uniq.append(c)
    return uniq


KIND_PRIORITY = ["PHRASAL_V", "NP", "GerP", "InfP", "ADJP", "ADVP", "VP", "PartP", "PP",
                 "COORD", "CLAUSE"]


def pick_chunk(cands, anchor):
    inside = [c for c in cands if anchor in c["idx"]]
    if not inside:
        return None, None
    inside.sort(key=lambda c: (len(c["idx"]),
                               KIND_PRIORITY.index(c["kind"]) if c["kind"] in KIND_PRIORITY else 99,
                               c["idx"][0]))
    best = inside[0]
    outer = None
    for c in inside[1:]:
        if c["kind"] == best["kind"] or c["kind"] == "CLAUSE":
            continue
        if not set(c["idx"]) > set(best["idx"]):
            continue
        if len(c["idx"]) > len(best["idx"]) + 6:
            continue
        if outer is None or len(c["idx"]) > len(outer["idx"]):
            outer = c
    return best, outer


# ─────────────────────────────────────────────────────────────────────────────
# 8. LOẠI CÂU / KHẲNG-PHỦ ĐỊNH / CÔNG THỨC
# ─────────────────────────────────────────────────────────────────────────────


def is_imperative(toks, span, main_ch):
    seg = [t for t in toks if tok_in_span(t, span) and t["tag"] != "PUNCT"]
    if not seg:
        return False
    k = 0
    while k < len(seg) and seg[k]["l"] in ("please", "never", "always", "just"):
        k += 1
    if k >= len(seg):
        return False
    if seg[k]["l"] in ("let", "lets") and k + 1 < len(seg) and seg[k + 1]["l"] == "us":
        return True
    if seg[k]["l"] in ("do", "does") and k + 1 < len(seg) and seg[k + 1]["l"] == "not":
        k += 2
    if k >= len(seg):
        return False
    head = seg[k]
    bare_ok = head["form"] in ("vb", "base", "") or \
        (head["form"] == "vbd" and head["lemma"] == head["l"])
    if head["tag"] != "VERB" or not bare_ok:
        return False
    polite = {"please", "never", "always", "just", "kindly"}
    return not any(t["tag"] in ("PRON", "DET", "NOUN", "NUM") and t["l"] not in polite
                   for t in seg[:k])


def sentence_type(text, toks, span, main_ch):
    seg = text[span[0]:span[1]].strip()
    if is_imperative(toks, span, main_ch):
        return "imperative", "none"
    m = re.search(r",\s*(\S+)\s+([^\W\d_']+)\s*\?\s*$", seg, re.UNICODE)
    if m:
        aux = m.group(1).lower().replace("'", "").replace("’", "")
        if aux in AUX_FORMS or aux in MODALS or aux.endswith("nt"):
            # Quyết định người sở hữu (2026-09-24): hiển thị "câu khẳng định + hỏi đuôi"
            return "declarative", "tag"
    if seg.endswith("?"):
        first = next((t for t in toks if tok_in_span(t, span) and t["tag"] != "PUNCT"), None)
        if first is not None and first["tag"] == "WH":
            return "interrogative", "wh"
        idx_first_verb = min(main_ch) if main_ch else 10 ** 6
        for i in range(span[0], min(idx_first_verb, span[1])):
            if toks[i]["tag"] == "WH":
                return "interrogative", "wh"
        if re.search(r"\bor\b", seg.lower()) and main_ch and \
                any(toks[k]["tag"] == "VERB" for k in main_ch):
            return "interrogative", "alternative"
        return "interrogative", "yesno"
    low = seg.lower()
    if seg.endswith("!") and not is_imperative(toks, span, main_ch):
        return "exclamative", "none"
    if re.match(r"^(what a|what an|how|such a)\b", low) and re.search(r"\b(it|he|she|they|i|we|you)\b", low):
        return "exclamative", "none"
    return "declarative", "none"


def polarity(toks, span, main_ch, text):
    if main_ch:
        if any(toks[k]["tag"] == "NEG" for k in main_ch):
            return "negative", "not"
    words = [t["l"] for t in toks if tok_in_span(t, span)]
    strong = ["never", "no", "nothing", "nobody", "none", "neither", "nor", "hardly",
              "scarcely", "barely", "rarely", "seldom", "without"]
    for w in strong:
        if w in words:
            return "negative", w
    return "affirmative", ""


def clause_role(toks, span):
    first = next((t for t in toks if tok_in_span(t, span) and t["tag"] != "PUNCT"), None)
    if first is None:
        return None
    if first["tag"] in ("WH", "SUB") or first["l"] == "that":
        prev = None
        for t in toks:
            if t["e"] <= first["s"] and t["tag"] != "PUNCT":
                prev = t
        if prev is not None and prev["tag"] in ("NOUN", "PRON", "NUM", "DET"):
            return "relative"
        if first["l"] in ("because", "although", "though", "while", "when", "if", "unless",
                          "since", "after", "before", "as", "so", "though"):
            return "adverbial"
        return "nominal"
    if first["tag"] == "PREP" or first["l"] in ("because", "although", "though", "while",
                                                "when", "if", "unless", "since", "after",
                                                "before", "despite", "in"):
        return "adverbial"
    return None


def conditional_type(text, span):
    seg = text[span[0]:span[1]].lower()
    if not re.search(r"\bif\b|\bunless\b", seg):
        return None
    if re.search(r"\bwould have\b|\bwould've\b", seg):
        return 3
    if re.search(r"\bif\b[^,]*\b(were|was)\b", seg) and re.search(r"\bwould\b", seg):
        return 2
    if re.search(r"\bif\b[^,]*\bpresent\b", seg):
        pass
    if re.search(r"\bif\b[^,]*\b(don't|doesn't|are|is|am|rains?|goes?|comes?|have|has)\b", seg) \
            and re.search(r"\bwill\b|\bcan\b|\bmay\b|\bshould\b", seg):
        return 1
    if re.search(r"\bif\b", seg):
        return 0
    return None


def pattern_of(toks, span, main_ch, text):
    words = [t for t in toks if tok_in_span(t, span) and t["tag"] != "PUNCT"]
    if not words:
        return "?"
    lows = [t["l"] for t in words]
    if lows[:1] == ["there"] and any(w in ("is", "are", "was", "were") for w in lows[:3]):
        return "There+V+S"
    if lows[:1] == ["it"] and any(w in ("is", "was") for w in lows[:3]) and \
            ("who" in lows or "that" in lows):
        return "IT-CLEFT"
    if main_ch is None:
        return "?"
    v = _main_verb(toks, main_ch)
    end_i = max(main_ch)
    phrasal = False
    if end_i + 1 < len(toks) and toks[end_i + 1]["l"] in PARTICLES and \
            (v, toks[end_i + 1]["l"]) in PHRASAL_PAIRS:
        end_i += 1
        phrasal = True
    if is_imperative(toks, span, main_ch):
        prof = _profile_after(toks, span, end_i)
        return "VO" if "NP" in prof else "V"
    prof = _profile_after(toks, span, end_i)
    prof = re.sub(r"^(ADV )+", "", prof)
    if v == "be":
        if prof.startswith("PP"):
            return "SVA"
        if prof and prof.split()[0] in ("NP", "ADJ", "to-V", "V-ing", "CLAUSE"):
            return "SVC"
        return "SV"
    if v in LINKING and not phrasal:
        return "SVC" if prof.startswith(("NP", "ADJ")) else ("SVA" if prof.startswith("PP") else "SV")
    if v in DITRANSITIVE and prof.startswith("NP NP"):
        return "SVOO"
    if v in COMPLEX_TRANSITIVE:
        if prof.startswith("NP ADJ") or prof.startswith("NP NP"):
            return "SVOC"
    if v in SVOA and prof.startswith("NP PP"):
        return "SVOA"
    if prof.startswith("NP ADJ") or prof.startswith("NP NP"):
        return "SVOC"
    if prof.startswith("NP"):
        return "SVO"
    if prof.startswith("PP"):
        return "SVA"
    if prof.startswith(("to-V", "V-ing", "CLAUSE")):
        return "SVO"
    return "SV"


def _main_verb(toks, idx):
    verbs = [k for k in idx if toks[k]["tag"] == "VERB"]
    if not verbs:
        for k in idx:
            if toks[k]["tag"] == "AUX":
                return toks[k]["lemma"]
        return "be"
    return toks[verbs[-1]]["lemma"]


def _profile_after(toks, span, end_i):
    out = []
    i = end_i + 1
    while i < len(toks) and tok_in_span(toks[i], span):
        t = toks[i]
        if t["tag"] == "PUNCT":
            break
        if t["tag"] == "ADJ":
            out.append("ADJ")
        elif t["tag"] in ("DET", "NOUN", "PRON", "NUM"):
            out.append("NP")
            if t["tag"] != "PRON":
                while i + 1 < len(toks) and toks[i + 1]["tag"] in ("NOUN", "ADJ", "NUM"):
                    i += 1
        elif t["tag"] == "PREP":
            out.append("PP")
            while i + 1 < len(toks) and toks[i + 1]["tag"] in ("DET", "NOUN", "ADJ", "NUM", "PRON"):
                i += 1
        elif t["tag"] == "TO":
            out.append("to-V")
        elif t["tag"] == "VERB" and t["form"] == "vbg":
            out.append("V-ing")
        elif t["tag"] in ("WH", "SUB"):
            out.append("CLAUSE")
            break
        else:
            out.append(t["tag"])
        i += 1
        if len(out) >= 4:
            break
    return " ".join(out)


# ─────────────────────────────────────────────────────────────────────────────
# 9. LANGUAGE GATE
# ─────────────────────────────────────────────────────────────────────────────

_VI_CHARS = set("ăâđêôơưàảãáạằắẳẵặầấẩẫậèẻẽéẹềếểễệìỉĩíịòỏõóọồốổỗộờớởỡợùủũúụừứửữựỳỷỹýỵ")
EN_FUNCTION = {"the", "a", "an", "is", "are", "was", "were", "to", "of", "in", "and", "that",
               "it", "he", "she", "they", "we", "you", "i", "not", "have", "has", "had",
               "do", "does", "did", "will", "can", "there", "my", "his", "her", "with",
               "for", "on", "at", "this", "these", "those", "but", "or", "be", "been"}


def is_likely_english(text: str) -> bool:
    low = text.lower()
    if any(ch in _VI_CHARS for ch in low):
        return False
    words = re.findall(r"[^\W\d_]+", low, re.UNICODE)
    if not words:
        return False
    ascii_letters = sum(1 for c in low if c.isascii() and c.isalpha())
    total_letters = sum(1 for c in low if c.isalpha()) or 1
    if ascii_letters / total_letters < 0.95:
        return False
    hits = sum(1 for w in words if w in EN_FUNCTION)
    return (hits / len(words) >= 0.10) or len(words) <= 3


# ─────────────────────────────────────────────────────────────────────────────
# 10. API CHÍNH
# ─────────────────────────────────────────────────────────────────────────────


def analyze(text: str, anchor: str, anchor_occurrence: int = 1):
    norm = normalize(text)
    src = _src_tokens(norm)
    toks = tag_tokens(expand_contractions(src))
    limit = len(toks)

    res = {"text": text, "supported": True, "phrase": None, "outer": None,
           "sentence": None, "clause_role": None, "conditional": None,
           "sentence_span": None, "notes": []}

    if not is_likely_english(norm):
        res["supported"] = False
        res["notes"].append("language_gate")
        return res

    hits = [i for i, t in enumerate(toks) if t["l"] == anchor.lower()]
    if not hits:
        res["notes"].append("anchor_not_found")
        return res
    anchor_idx = hits[min(anchor_occurrence, len(hits)) - 1]

    sents = sentence_spans(norm)
    sent = next((s for s in sents if toks[anchor_idx]["s"] >= s[0] and
                 toks[anchor_idx]["e"] <= s[1]), sents[0])
    res["sentence_span"] = norm[sent[0]:sent[1]].strip()

    cands = all_candidates(toks, limit, (sent[0], sent[1], anchor_idx))
    best, outer = pick_chunk(cands, anchor_idx)
    if best:
        res["phrase"] = {"kind": best["kind"],
                         "span": parts_text(toks, text, best["parts"]),
                         "split": len(best["parts"]) > 1,
                         "part_offsets": [(toks[a]["s"], toks[b]["e"]) for a, b in best["parts"]]}
    if outer:
        res["outer"] = {"kind": outer["kind"],
                        "span": parts_text(toks, text, outer["parts"])}
    if not best:
        res["notes"].append("no_chunk")

    cls = clause_spans(norm, sent[0], sent[1], toks)
    anchor_clause = next((c for c in cls if toks[anchor_idx]["s"] >= c[0] and
                          toks[anchor_idx]["e"] <= c[1]), (sent[0], sent[1]))

    m_spans = modifier_spans(toks, limit)

    def in_modifier(ch):
        return any(a <= min(ch) and max(ch) <= b for a, b in m_spans)

    main_clause, main_ch = None, None
    first_ch = None
    for c in cls:
        ch = chain_finite(toks, (c[0], c[1]), limit)
        if ch is None:
            continue
        if in_modifier(ch):
            alt = None
            for j, tk in enumerate(toks):
                if not tok_in_span(tk, c) or j <= max(ch):
                    continue
                if tk["tag"] in ("AUX", "MODAL", "VERB"):
                    cand = verb_chain_at(toks, j, limit)
                    if cand and chain_has_finite(toks, cand[0]) and not in_modifier(cand[0]):
                        alt = cand[0]
                        break
            if alt is not None:
                ch = alt
            else:
                continue
        if first_ch is None:
            first_ch = (c, ch)
        first_tok = next((t for t in toks if tok_in_span(t, c) and t["tag"] != "PUNCT"), None)
        fragment = first_tok is not None and (
            first_tok["tag"] == "SUB" or first_tok["l"] in ("when", "while", "where", "once",
                                                            "until", "whenever", "wherever")
            or first_tok["l"] in ("because", "although", "though",
                                                            "while", "if", "unless", "since")
            or (first_tok["tag"] == "PREP" and first_tok["l"] in ("because", "due", "despite")))
        if not fragment:
            main_clause, main_ch = c, ch
            break
    if main_clause is None and first_ch is not None:
        main_clause, main_ch = first_ch
    if main_clause is None:
        main_clause, main_ch = anchor_clause, chain_finite(toks, anchor_clause, limit)

    role = None
    if any(a <= anchor_idx <= b for a, b in m_spans):
        role = "relative"
    elif anchor_clause != main_clause:
        role = clause_role(toks, anchor_clause)
    else:
        # "She said THAT she would come" — không có dấu phẩy, vẫn phải thấy mệnh đề phụ
        sub = None
        for j, tk in enumerate(toks):
            if tk["tag"] == "PUNCT" or j <= (max(main_ch) if main_ch else -1):
                continue
            if tk["e"] <= anchor_idx and tk["tag"] in ("SUB", "WH") or tk["l"] == "that":
                if tk["s"] >= main_clause[0] and tk["s"] < toks[anchor_idx]["s"]:
                    sub = tk
        if sub is not None:
            role = clause_role(toks, (sub["s"], sent[1]))
    res["clause_role"] = role
    stype, qkind = sentence_type(norm, toks, (sent[0], sent[1]), main_ch)
    pol, negword = polarity(toks, main_clause, main_ch, norm)
    if stype == "imperative":
        seg_low = norm[main_clause[0]:main_clause[1]].strip().lower()
        if seg_low.startswith("never"):
            pol, negword = "negative", "never"
    if main_ch:
        tense, aspect, voice, modal, _, _ = read_verb_group(toks, main_ch)
    else:
        tense, aspect, voice, modal = "none", "none", "active", None
    res["conditional"] = conditional_type(norm, sent)
    res["sentence"] = {"type": stype, "question": qkind, "polarity": pol, "negator": negword,
                       "tense": tense, "aspect": aspect, "voice": voice, "modal": modal,
                       "pattern": pattern_of(toks, main_clause, main_ch, norm),
                       "span": norm[main_clause[0]:main_clause[1]].strip()}
    return res
