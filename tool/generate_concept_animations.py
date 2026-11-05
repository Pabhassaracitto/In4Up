#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""PLAN-041 / LOTTIE-LIB-001 Pha 2 — sinh gói animation khái niệm.

Chạy:  python3 tool/generate_concept_animations.py

Sinh ra:
  * assets/animations/concept_animation_pack.json — chỉ mục 100 khái niệm
    cốt lõi (đã được owner duyệt 2026-11-05, xem
    docs/plans/PLAN-041-animation-core-concepts.md).
  * assets/animations/files/<slug>.json — animation Lottie PICTOGRAM GỐC
    tự vẽ bằng hình học tham số cho các khái niệm hợp (thiên nhiên, thời
    tiết, cảm xúc đơn giản…). Đây là tác phẩm gốc cho In4Up (CC0) nên
    không vướng bản quyền; khái niệm hành động/động vật phức tạp để
    `animations: []` chờ tuyển file giấy phép mở (ghi URL + license vào
    chỉ mục theo schema `type: "url"`).

Mọi file sinh ra đều deterministic — sửa DATA/hàm vẽ rồi chạy lại.
"""
import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_PACK = os.path.join(ROOT, "assets", "animations", "concept_animation_pack.json")
OUT_DIR = os.path.join(ROOT, "assets", "animations", "files")

# ───────────────────────── palette ─────────────────────────
SUN = (1.0, 0.62, 0.15)
GOLD = (1.0, 0.80, 0.25)
MOONC = (0.98, 0.85, 0.45)
BLUE = (0.25, 0.60, 1.0)
DBLUE = (0.15, 0.35, 0.75)
SKY = (0.55, 0.80, 1.0)
CLOUDC = (0.92, 0.95, 1.0)
RED = (0.95, 0.30, 0.35)
PINK = (1.0, 0.45, 0.62)
GREEN = (0.30, 0.75, 0.40)
DGREEN = (0.16, 0.52, 0.28)
BROWN = (0.55, 0.38, 0.25)
DARK = (0.16, 0.18, 0.25)
ORANGE = (1.0, 0.50, 0.20)
YELLOW = (1.0, 0.85, 0.30)
PURPLE = (0.62, 0.50, 1.0)
WHITE = (1.0, 1.0, 1.0)
GRAY = (0.55, 0.60, 0.70)

# ───────────────────────── lottie helpers ─────────────────────────
def K(v):
    return {"a": 0, "k": v}

def A(pts, linear=False):
    """Animated property từ [(frame, [values]), ...]."""
    out = []
    for i, (t, v) in enumerate(pts):
        if i < len(pts) - 1:
            ii = {"x": [1], "y": [1]} if linear else {"x": [0.5], "y": [1]}
            oo = {"x": [0], "y": [0]} if linear else {"x": [0.5], "y": [0]}
            out.append({"t": t, "s": list(v), "e": list(pts[i + 1][1]), "i": ii, "o": oo})
        else:
            out.append({"t": t, "s": list(v)})
    return {"a": 1, "k": out}

def TR(p=(0, 0), a=(0, 0), s=(100, 100), r=0, o=100):
    return {"ty": "tr", "nm": "tr", "p": K(list(p)), "a": K(list(a)),
            "s": K(list(s)), "r": K(r), "o": K(o)}

def GRP(items, name="g", tr=None):
    it = list(items) + [tr if tr is not None else TR()]
    return {"ty": "gr", "nm": name, "cix": 2, "np": len(it), "it": it}

def FL(rgb, o=100):
    return {"ty": "fl", "nm": "f", "cix": 2,
            "c": K([rgb[0], rgb[1], rgb[2], 1]), "o": K(o), "r": 1}

def ST(rgb, w, o=100):
    return {"ty": "st", "nm": "s", "cix": 2,
            "c": K([rgb[0], rgb[1], rgb[2], 1]), "o": K(o), "w": K(w),
            "lc": 2, "lj": 2}

def EL(p, s):
    return {"ty": "el", "nm": "e", "cix": 2, "p": K(list(p)), "s": K(list(s))}

def RC(p, s, r=0):
    return {"ty": "rc", "nm": "r", "cix": 2, "p": K(list(p)), "s": K(list(s)), "r": K(r)}

def SR(points, outer, inner=None, p=(0, 0), rot=0):
    d = {"ty": "sr", "nm": "star", "cix": 2, "sy": 1 if inner is not None else 2,
         "pt": K(points), "p": K(list(p)), "r": K(rot), "or": K(outer),
         "os": K(0), "is": K(0)}
    if inner is not None:
        d["ir"] = K(inner)
    return d

def SH(pts, closed=True):
    vs = [[round(x, 1), round(y, 1)] for x, y in pts]
    return {"ty": "sh", "nm": "p", "cix": 2,
            "ks": K({"i": [[0, 0]] * len(vs), "o": [[0, 0]] * len(vs),
                     "v": vs, "c": closed})}

def LYR(ind, name, shapes, p=(120, 120), r=None, s=None, o=None, op=60):
    ks = {"o": o if o is not None else K(100),
          "r": r if r is not None else K(0),
          "p": p if isinstance(p, dict) else K([p[0], p[1], 0]),
          "a": K([0, 0, 0]),
          "s": s if s is not None else K([100, 100, 100])}
    return {"ddd": 0, "ind": ind, "ty": 4, "nm": name, "sr": 1, "ks": ks,
            "ao": 0, "shapes": shapes, "ip": 0, "op": op, "st": 0, "bm": 0}

def DOC(name, layers, op=60):
    return {"v": "5.7.4", "fr": 30, "ip": 0, "op": op, "w": 240, "h": 240,
            "nm": name, "ddd": 0, "assets": [], "layers": layers}

def QB(p0, p1, p2, n=14):
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append(((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
                    (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]))
    return pts

def ARC(c, r, a0, a1, n=24):
    return [(c[0] + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             c[1] + r * math.sin(math.radians(a0 + (a1 - a0) * i / n)))
            for i in range(n + 1)]

def SXY(sx, sy):
    return A([(0, [sx, sy, 100]), (10 ** 9, [sx, sy, 100])]) if False else K([sx, sy, 100])

def loop_scale(op, peak, mid=None):
    return A([(0, [100, 100, 100]), (op // 4, [peak, peak, 100]),
              (op // 2, [100, 100, 100]),
              (3 * op // 4, [peak, peak, 100]), (op, [100, 100, 100])])

def cloud_group(name="cloud", color=CLOUDC):
    return GRP([EL((-38, 10), (76, 52)), EL((0, -6), (92, 68)),
                EL((40, 12), (70, 46)), FL(color)], name)

# ───────────────────────── draw functions ─────────────────────────
def d_sun():
    op = 120
    rays = LYR(1, "rays", [GRP([SR(8, 82, 54), FL(SUN)], "rays")],
               r=A([(0, [0]), (op, [45])], linear=True), op=op)
    core = LYR(2, "core", [GRP([EL((0, 0), (88, 88)), FL(GOLD)], "core")],
               s=loop_scale(op, 106), op=op)
    return DOC("sun", [core, rays], op)

def _crescent(scale=1.0):
    r_out = 64 * scale
    p1 = (r_out * math.cos(math.radians(55)), r_out * math.sin(math.radians(55)))
    p2 = (r_out * math.cos(math.radians(-55)), r_out * math.sin(math.radians(-55)))
    cx = 30 * scale
    r_in = math.hypot(p1[0] - cx, p1[1])
    outer = ARC((0, 0), r_out, 55, 305, 40)
    a_end = math.degrees(math.atan2(p2[1], p2[0] - cx))      # ~-82.7
    a_start = math.degrees(math.atan2(p1[1], p1[0] - cx))    # ~82.7
    inner = ARC((cx, 0), r_in, a_end, a_start - 360, 28)
    return outer + inner

def d_moon():
    op = 120
    moon = LYR(1, "moon", [GRP([SH(_crescent()), FL(MOONC)], "moon")],
               r=A([(0, [-6]), (60, [6]), (120, [-6])]), op=op)
    tw = []
    for i, (x, y, ph) in enumerate([(66, -52, 0), (84, 6, 30), (52, 58, 60)]):
        tw.append(LYR(3 + i, "tw", [GRP([SR(4, 13, 5), FL(GOLD)], "tw")],
                      p=(120 + x, 120 + y),
                      o=A([(ph, [20]), (ph + 30, [100]), (ph + 60, [20])]),
                      s=A([(ph, [70, 70, 100]), (ph + 30, [110, 110, 100]),
                           (ph + 60, [70, 70, 100])]), op=op))
    return DOC("moon", [moon] + tw, op)

def d_star():
    op = 90
    star = LYR(1, "star", [GRP([SR(5, 74, 32), FL(GOLD)], "star")],
               r=A([(0, [-8]), (45, [8]), (90, [-8])]),
               s=loop_scale(op, 112), op=op)
    s1 = LYR(2, "s1", [GRP([SR(4, 15, 6), FL(YELLOW)], "s")], p=(52, 58),
             o=A([(0, [100]), (45, [15]), (90, [100])]), op=op)
    s2 = LYR(3, "s2", [GRP([SR(4, 12, 5), FL(YELLOW)], "s")], p=(196, 172),
             o=A([(0, [15]), (45, [100]), (90, [15])]), op=op)
    return DOC("star", [star, s1, s2], op)

def d_cloud():
    op = 120
    c = LYR(1, "cloud", [cloud_group()],
            p=A([(0, [104, 118, 0]), (60, [136, 112, 0]), (120, [104, 118, 0])]), op=op)
    return DOC("cloud", [c], op)

def d_rain():
    op = 60
    layers = []
    layers.append(LYR(1, "cloud", [cloud_group()], p=(120, 72),
                      s=A([(0, [100, 100, 100]), (30, [104, 104, 100]),
                           (60, [100, 100, 100])]), op=op))
    for i, x in enumerate([74, 98, 122, 146, 168]):
        ph = (i * 11) % op
        y0, y1 = 118, 196
        # keyframes gói quanh vòng lặp bằng 2 đoạn
        seg = [(ph, [x, y0, 0]), (min(ph + 26, op), [x - 8, y1, 0])]
        if ph + 26 > op:
            seg.append((op, [x - 8, y1, 0]))
        seg = sorted({(t, tuple(v)) for t, v in seg})
        seg = [(t, list(v)) for t, v in seg]
        opat = [(ph, [0]), (ph + 5 if ph + 5 <= op else op, [100])]
        layers.append(LYR(2 + i, "drop",
                          [GRP([RC((0, 0), (7, 20), 3.5), FL(BLUE)], "d")],
                          p=A([(0, [x, y0, 0])] + seg + [(op, [x - 8, y1, 0])], linear=True),
                          o=A([(0, [0])] + opat + [(op, [0])]), op=op))
    return DOC("rain", layers, op)

def _flake(name):
    items = []
    for ang in (0, 60, 120):
        items.append(GRP([RC((0, 0), (8, 96), 4)], "bar", tr=TR(r=ang)))
    items.append(GRP([SR(6, 16), FL(SKY)], "core"))
    return GRP(items + [], name)  # fill áp ở từng bar? thêm fill chung dưới

def d_snow():
    op = 180
    def flake(scale):
        bars = []
        for ang in (0, 60, 120):
            bars.append(GRP([RC((0, 0), (9, 100), 4.5), FL(SKY)], "b", tr=TR(r=ang)))
        bars.append(GRP([EL((0, 0), (22, 22)), FL(WHITE)], "c"))
        return bars
    f1 = LYR(1, "f1", flake(1), p=A([(0, [100, 108, 0]), (90, [118, 132, 0]),
                                     (180, [100, 108, 0])]),
             r=A([(0, [0]), (180, [360])], linear=True), op=op)
    f2 = LYR(2, "f2", flake(1), p=A([(0, [172, 150, 0]), (90, [158, 128, 0]),
                                     (180, [172, 150, 0])]),
             r=A([(0, [360]), (180, [0])], linear=True),
             s=K([55, 55, 100]), o=K(80), op=op)
    return DOC("snow", [f1, f2], op)

def d_wind():
    op = 90
    layers = []
    for i, (y, w, ph) in enumerate([(84, 130, 0), (120, 170, 18), (156, 120, 36)]):
        pts = [(x, 8 * math.sin(math.radians(x * 2.4))) for x in range(-w // 2, w // 2 + 1, 8)]
        layers.append(LYR(1 + i, "w",
                          [GRP([SH(pts, closed=False), ST(SKY, 9)], "w")],
                          p=A([(ph, [112, y, 0]), (ph + 45 if ph + 45 <= op else op, [132, y, 0]),
                               (op, [112, y, 0])]),
                          o=A([(0, [70]), (45, [100]), (90, [70])]), op=op))
    return DOC("wind", layers, op)

def d_lightning():
    op = 60
    bolt = SH([(14, -84), (-30, 6), (-4, 6), (-16, 84), (34, -12), (6, -12)])
    b = LYR(1, "bolt", [GRP([bolt, FL(YELLOW)], "bolt")],
            p=(120, 118),
            o=A([(0, [100]), (8, [25]), (14, [100]), (30, [100]), (38, [20]),
                 (46, [100]), (60, [100])]),
            s=A([(0, [100, 100, 100]), (14, [108, 108, 100]),
                 (30, [100, 100, 100]), (46, [106, 106, 100]),
                 (60, [100, 100, 100])]), op=op)
    c = LYR(2, "cloud", [cloud_group(color=(0.75, 0.80, 0.92))], p=(120, 58),
            s=K([88, 88, 100]), op=op)
    return DOC("lightning", [b, c], op)

def _flame_pts(h=118, w=66):
    right = QB((0, -h), (w * 0.75, -h * 0.25), (w * 0.46, 0), 16)
    bottom = QB((w * 0.46, 0), (0, 14), (-w * 0.46, 0), 12)
    left = QB((-w * 0.46, 0), (-w * 0.75, -h * 0.25), (0, -h), 16)
    return right + bottom + left

def d_fire():
    op = 48
    outer = LYR(1, "outer", [GRP([SH(_flame_pts()), FL(ORANGE)], "f")],
                p=(120, 192),
                r=A([(0, [-3]), (24, [3]), (48, [-3])]),
                s=A([(0, [100, 100, 100]), (12, [94, 110, 100]),
                     (24, [100, 100, 100]), (36, [96, 108, 100]),
                     (48, [100, 100, 100])]), op=op)
    inner = LYR(2, "inner", [GRP([SH(_flame_pts(72, 42)), FL(YELLOW)], "f")],
                p=(120, 194),
                r=A([(0, [3]), (24, [-3]), (48, [3])]),
                s=A([(0, [100, 104, 100]), (16, [92, 114, 100]),
                     (32, [100, 104, 100]), (48, [100, 104, 100])]), op=op)
    return DOC("fire", [inner, outer], op)

def _wave_layer(ind, color, ybase, amp, op, reverse=False, alpha=100):
    pts = [(x, amp * math.sin(math.radians(x * 3))) for x in range(-240, 241, 10)]
    pts = pts + [(240, 130), (-240, 130)]
    dx = 120 if not reverse else -120
    return LYR(ind, "wave", [GRP([SH(pts), FL(color, alpha)], "w")],
               p=A([(0, [120, ybase, 0]), (op, [120 + dx, ybase, 0])], linear=True), op=op)

def d_wave():
    op = 90
    back = _wave_layer(2, SKY, 128, 12, op, reverse=True, alpha=70)
    front = _wave_layer(1, BLUE, 148, 14, op)
    return DOC("water-wave", [front, back], op)

def d_tree():
    op = 120
    trunk = LYR(2, "trunk", [GRP([RC((0, 0), (20, 64), 6), FL(BROWN)], "t")],
                p=(120, 188), op=op)
    canopy = [EL((-40, 20), (78, 66)), EL((40, 20), (78, 66)),
              EL((0, -18), (96, 82)), FL(GREEN)]
    top = LYR(1, "canopy", [GRP(canopy, "c")], p=(120, 160),
              r=A([(0, [-2.5]), (60, [2.5]), (120, [-2.5])]), op=op)
    return DOC("tree", [top, trunk], op)

def d_flower():
    op = 240
    petals = []
    for i in range(6):
        petals.append(GRP([EL((0, -34), (34, 52)), FL(PINK)], "p",
                          tr=TR(r=i * 60)))
    petals.append(GRP([EL((0, 0), (34, 34)), FL(YELLOW)], "c"))
    head = LYR(1, "head", petals, p=(120, 102),
               r=A([(0, [0]), (240, [360])], linear=True), op=op)
    stem = LYR(2, "stem",
               [GRP([RC((0, 0), (10, 78), 5), FL(DGREEN)], "s"),
                GRP([SH(QB((0, 0), (34, -6), (40, -30), 10) +
                        QB((40, -30), (16, -22), (0, 0), 10)), FL(GREEN)], "leaf",
                    tr=TR(p=(2, 8)))],
               p=(120, 182), op=op)
    return DOC("flower", [head, stem], op)

def _heart_pts(scale=3.0, n=64):
    pts = []
    for i in range(n + 1):
        t = 2 * math.pi * i / n
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x * scale, -y * scale))
    return pts

def d_heart():
    op = 60
    main = LYR(1, "heart", [GRP([SH(_heart_pts(3.1)), FL(RED)], "h")],
               p=(120, 126),
               s=A([(0, [100, 100, 100]), (8, [116, 116, 100]),
                    (16, [100, 100, 100]), (24, [110, 110, 100]),
                    (34, [100, 100, 100]), (60, [100, 100, 100])]), op=op)
    mini = LYR(2, "mini", [GRP([SH(_heart_pts(1.1)), FL(PINK)], "h")],
               p=A([(10, [172, 128, 0]), (50, [182, 72, 0]), (60, [184, 64, 0])]),
               o=A([(0, [0]), (14, [90]), (46, [90]), (58, [0]), (60, [0])]),
               s=K([80, 80, 100]), op=op)
    return DOC("love-heart", [main, mini], op)

def _face(mood):
    op = 90
    shapes = [GRP([EL((0, 0), (150, 150)), FL(YELLOW)], "face")]
    if mood == "happy":
        shapes.append(GRP([EL((-30, -18), (17, 24)), EL((30, -18), (17, 24)), FL(DARK)], "eyes"))
        smile = ARC((0, 6), 40, 25, 155, 16)
        shapes.append(GRP([SH(smile, closed=False), ST(DARK, 9)], "mouth"))
        shapes.append(GRP([EL((-50, 16), (26, 16)), FL(PINK, 55)], "c1"))
        shapes.append(GRP([EL((50, 16), (26, 16)), FL(PINK, 55)], "c2"))
    else:
        shapes.append(GRP([EL((-30, -10), (17, 20)), EL((30, -10), (17, 20)), FL(DARK)], "eyes"))
        frown = ARC((0, 62), 36, 205, 335, 16)
        shapes.append(GRP([SH(frown, closed=False), ST(DARK, 9)], "mouth"))
    face = LYR(1, mood, shapes,
               s=A([(0, [100, 100, 100]), (45, [104, 104, 100]), (90, [100, 100, 100])]),
               r=A([(0, [-3]), (45, [3]), (90, [-3])]), op=op)
    layers = [face]
    if mood == "sad":
        drop = [(0, -16)] + QB((0, -16), (12, 6), (8, 14), 8) + \
               QB((8, 14), (0, 24), (-8, 14), 8) + QB((-8, 14), (-12, 6), (0, -16), 8)
        tear = LYR(2, "tear", [GRP([SH(drop), FL(BLUE)], "t")],
                   p=A([(20, [152, 116, 0]), (70, [152, 178, 0]), (90, [152, 186, 0])], linear=True),
                   o=A([(0, [0]), (24, [100]), (66, [100]), (80, [0]), (90, [0])]), op=op)
        layers = [tear, face]
    return DOC(mood, layers, op)

def d_updown():
    op = 60
    up_poly = [(0, -52), (34, -14), (13, -14), (13, 44), (-13, 44), (-13, -14), (-34, -14)]
    down_poly = [(x, -y) for x, y in up_poly]
    up = LYR(1, "up", [GRP([SH(up_poly), FL(GREEN)], "u")],
             p=A([(0, [82, 128, 0]), (30, [82, 104, 0]), (60, [82, 128, 0])]), op=op)
    dn = LYR(2, "down", [GRP([SH(down_poly), FL(RED)], "d")],
             p=A([(0, [158, 112, 0]), (30, [158, 136, 0]), (60, [158, 112, 0])]), op=op)
    return DOC("up-down", [up, dn], op)

def d_daynight():
    op = 180
    orbit_items = [
        GRP([SR(8, 30, 20, p=(0, -62)), EL((0, -62), (34, 34)), FL(GOLD)], "sun"),
        GRP([SH([(x, y + 62) for x, y in _crescent(0.42)]), FL(MOONC)], "moon"),
    ]
    orbit = LYR(1, "orbit", orbit_items,
                r=A([(0, [0]), (180, [360])], linear=True), op=op)
    earth = LYR(2, "earth", [GRP([EL((0, 0), (44, 44)), FL(BLUE)], "e"),
                             GRP([EL((-8, -6), (18, 12)), EL((10, 8), (14, 10)), FL(GREEN)], "land")], op=op)
    return DOC("day-night", [orbit, earth], op)

def _note(color):
    flag = QB((26, -52), (52, -40), (46, -8), 10) + QB((46, -8), (40, -26), (26, -34), 8)
    return [GRP([EL((0, 18), (34, 25)), FL(color)], "head"),
            GRP([RC((22, -18), (8, 76), 3), FL(color)], "stem"),
            GRP([SH(flag), FL(color)], "flag")]

def d_music():
    op = 90
    n1 = LYR(1, "n1", _note(PURPLE), p=A([(0, [104, 126, 0]), (45, [110, 106, 0]),
                                         (90, [104, 126, 0])]),
             r=A([(0, [-7]), (45, [7]), (90, [-7])]), op=op)
    n2 = LYR(2, "n2", _note(BLUE), p=A([(0, [168, 104, 0]), (45, [162, 124, 0]),
                                        (90, [168, 104, 0])]),
             r=A([(0, [7]), (45, [-7]), (90, [7])]), s=K([62, 62, 100]), op=op)
    return DOC("music", [n1, n2], op)

def d_check():
    op = 120
    ring = LYR(3, "ring", [GRP([EL((0, 0), (150, 150)), ST(GRAY, 7, 45)], "r")], op=op)
    chk = LYR(1, "check", [GRP([SH([(-40, 2), (-11, 32), (44, -30)], closed=False),
                                ST(GREEN, 15)], "c")],
              o=A([(0, [100]), (54, [100]), (66, [0]), (114, [0]), (120, [100])]),
              s=A([(0, [90, 90, 100]), (12, [108, 108, 100]), (22, [100, 100, 100]),
                   (120, [90, 90, 100])]), op=op)
    x = LYR(2, "x", [GRP([SH([(-26, -26), (26, 26)], closed=False),
                          SH([(26, -26), (-26, 26)], closed=False), ST(RED, 14)], "x")],
            o=A([(0, [0]), (54, [0]), (66, [100]), (114, [100]), (120, [0])]),
            s=A([(60, [90, 90, 100]), (74, [108, 108, 100]), (84, [100, 100, 100]),
                 (120, [100, 100, 100])]), op=op)
    return DOC("check-yes-no", [chk, x, ring], op)

def _leaf_pts(w=40, h=58):
    return QB((0, -h), (w, -h * 0.2), (0, h), 16) + QB((0, h), (-w, -h * 0.2), (0, -h), 16)

def d_fall():
    op = 120
    leaf = LYR(1, "leaf",
               [GRP([SH(_leaf_pts()), FL(ORANGE)], "leaf"),
                GRP([SH([(0, -52), (0, 58)], closed=False), ST(DARK, 3, 35)], "vein")],
               p=A([(0, [92, 50, 0]), (35, [136, 96, 0]), (70, [96, 142, 0]),
                    (105, [140, 184, 0]), (120, [144, 196, 0])]),
               r=A([(0, [0]), (120, [250])]),
               o=A([(0, [0]), (10, [100]), (104, [100]), (118, [0]), (120, [0])]), op=op)
    return DOC("fall", [leaf], op)

def d_grow():
    op = 120
    ground = LYR(4, "ground", [GRP([RC((0, 0), (150, 16), 8), FL(BROWN)], "g")],
                 p=(120, 198), op=op)
    stem = LYR(3, "stem", [GRP([RC((0, -34), (9, 68), 4), FL(DGREEN)], "s")],
               p=(120, 192),
               s=A([(0, [100, 4, 100]), (34, [100, 100, 100]), (120, [100, 100, 100])]), op=op)
    l1 = LYR(2, "leaf1", [GRP([SH(_leaf_pts(26, 38)), FL(GREEN)], "l")],
             p=(120, 128), r=K(-38),
             s=A([(26, [0, 0, 100]), (48, [100, 100, 100]), (120, [100, 100, 100])]), op=op)
    l2 = LYR(1, "leaf2", [GRP([SH(_leaf_pts(26, 38)), FL(GREEN)], "l")],
             p=(120, 128), r=K(38),
             s=A([(34, [0, 0, 100]), (56, [100, 100, 100]), (120, [100, 100, 100])]), op=op)
    return DOC("grow", [l1, l2, stem, ground], op)

def d_clock():
    op = 360
    face = LYR(4, "face",
               [GRP([EL((0, 0), (156, 156)), FL(WHITE), ST(DARK, 9)], "rim"),
                GRP([EL((0, -62), (8, 14)), EL((62, 0), (14, 8)),
                     EL((0, 62), (8, 14)), EL((-62, 0), (14, 8)), FL(DARK)], "ticks")], op=op)
    hour = LYR(2, "hour", [GRP([RC((0, -22), (11, 48), 5), FL(DARK)], "h")],
               r=A([(0, [0]), (360, [360])], linear=True), op=op)
    minute = LYR(1, "minute", [GRP([RC((0, -32), (8, 68), 4), FL(RED)], "m")],
                 r=A([(0, [0]), (360, [4320])], linear=True), op=op)
    dot = LYR(3, "dot", [GRP([EL((0, 0), (14, 14)), FL(DARK)], "d")], op=op)
    return DOC("clock", [dot, minute, hour, face], op)

def d_light():
    op = 90
    glow = LYR(3, "glow", [GRP([SR(8, 82, 58), FL(YELLOW)], "g")], p=(120, 108),
               o=A([(0, [22]), (45, [55]), (90, [22])]),
               s=A([(0, [92, 92, 100]), (45, [108, 108, 100]), (90, [92, 92, 100])]), op=op)
    bulb = LYR(1, "bulb", [GRP([EL((0, 0), (86, 86)), FL(YELLOW)], "b")], p=(120, 108), op=op)
    base = LYR(2, "base",
               [GRP([RC((0, 0), (34, 12), 4), FL(GRAY)], "b1"),
                GRP([RC((0, 14), (28, 10), 4), FL(GRAY)], "b2"),
                GRP([RC((0, 26), (14, 10), 4), FL(DARK)], "b3")], p=(120, 158), op=op)
    return DOC("light-lamp", [bulb, base, glow], op)

def d_eye():
    op = 120
    outline = QB((-84, 0), (0, -78), (84, 0), 20) + QB((84, 0), (0, 62), (-84, 0), 20)
    eye = LYR(1, "eye",
              [GRP([SH(outline), FL(WHITE), ST(DARK, 7)], "shape"),
               GRP([EL((0, 0), (58, 58)), FL(DBLUE)], "iris"),
               GRP([EL((0, 0), (26, 26)), FL(DARK)], "pupil"),
               GRP([EL((10, -10), (10, 10)), FL(WHITE)], "glint")],
              s=A([(0, [100, 100, 100]), (52, [100, 100, 100]), (57, [100, 8, 100]),
                   (62, [100, 100, 100]), (120, [100, 100, 100])]), op=op)
    return DOC("eye", [eye], op)

def d_fish():
    op = 60
    body_pts = QB((66, 0), (10, -44), (-42, 0), 16) + QB((-42, 0), (10, 44), (66, 0), 16)
    tail = LYR(2, "tail",
               [GRP([SH([(0, 0), (-38, -28), (-30, 0), (-38, 28)]), FL(ORANGE)], "t")],
               p=(76, 120), r=A([(0, [-16]), (15, [16]), (30, [-16]),
                                  (45, [16]), (60, [-16])]), op=op)
    body = LYR(1, "body",
               [GRP([SH(body_pts), FL((1.0, 0.62, 0.30))], "b"),
                GRP([EL((38, -8), (11, 11)), FL(DARK)], "eye"),
                GRP([SH(QB((6, -30), (-6, 0), (6, 30), 10), closed=False),
                     ST(DARK, 4, 30)], "gill")],
               p=A([(0, [118, 120, 0]), (30, [130, 114, 0]), (60, [118, 120, 0])]), op=op)
    bubbles = []
    for i, (x, ph) in enumerate([(196, 0), (210, 22), (188, 40)]):
        bubbles.append(LYR(3 + i, "b", [GRP([EL((0, 0), (13, 13)), ST(SKY, 4, 80)], "b")],
                           p=A([(ph, [x, 128, 0]), (min(ph + 30, 60), [x + 6, 64, 0]),
                                (60, [x + 6, 64, 0])], linear=True),
                           o=A([(0, [0]), (ph, [0]), (ph + 6 if ph + 6 <= 60 else 60, [100]),
                                (58, [0]), (60, [0])]), op=op))
    return DOC("fish", bubbles + [body, tail], op)

def d_butterfly():
    op = 48
    def wing(side):
        return [GRP([EL((side * 36, -26), (62, 46)), EL((side * 32, 22), (52, 42)),
                     FL(PURPLE)], "w"),
                GRP([EL((side * 36, -26), (20, 14)), FL(PINK, 80)], "spot")]
    flap = lambda sgn: A([(0, [100 * sgn, 100, 100]), (12, [34 * sgn, 100, 100]),
                           (24, [100 * sgn, 100, 100]), (36, [34 * sgn, 100, 100]),
                           (48, [100 * sgn, 100, 100])])
    wl = LYR(1, "wl", wing(-1), s=flap(1), op=op)
    wr = LYR(2, "wr", wing(1), s=flap(1), op=op)
    body = LYR(3, "body",
               [GRP([EL((0, 6), (16, 84)), FL(DARK)], "b"),
                GRP([SH([(-3, -34), (-20, -56)], closed=False),
                     SH([(3, -34), (20, -56)], closed=False), ST(DARK, 5)], "ant")],
               p=A([(0, [120, 124, 0]), (24, [120, 112, 0]), (48, [120, 124, 0])]), op=op)
    return DOC("butterfly", [body, wl, wr], op)

def d_airplane():
    op = 90
    plane_pts = [(78, 0), (-58, -40), (-30, 2), (-58, 44)]
    fold_pts = [(78, 0), (-30, 2), (-8, 34)]
    plane = LYR(1, "plane",
                [GRP([SH(plane_pts), FL((0.94, 0.96, 1.0))], "p"),
                 GRP([SH(fold_pts), FL(SKY)], "fold")],
                p=A([(0, [112, 126, 0]), (45, [130, 106, 0]), (90, [112, 126, 0])]),
                r=A([(0, [-6]), (45, [5]), (90, [-6])]), op=op)
    trails = []
    for i, (x, y, ph) in enumerate([(38, 150, 0), (58, 166, 20), (78, 180, 40)]):
        trails.append(LYR(2 + i, "t", [GRP([RC((0, 0), (22, 7), 3.5), FL(SKY)], "t")],
                          p=(x, y), o=A([(ph, [15]), (ph + 22 if ph + 22 <= 90 else 90, [95]),
                                          (90, [15])]), op=op))
    return DOC("airplane", [plane] + trails, op)

def d_original_icon(group, slug):
    """Những pictogram hình học gốc cho các mục chưa cần animation riêng.

    Một số biểu tượng dùng mô-típ hình học của cùng nhóm (người/động vật/
    vật dụng/đồ ăn/phương tiện), nhưng mỗi khái niệm có file độc lập và
    chuyển động nhẹ do In4Up tự vẽ; không chứa nội dung bên thứ ba.
    """
    op = 90
    colors = [BLUE, GREEN, ORANGE, PURPLE, RED, SKY]
    color = colors[sum(ord(c) for c in slug) % len(colors)]
    bounce = A([(0, [120, 124, 0]), (22, [120, 112, 0]),
                 (45, [120, 124, 0]), (68, [120, 112, 0]),
                 (90, [120, 124, 0])])
    turn = A([(0, [-5]), (45, [5]), (90, [-5])])
    layers = []

    if group == "A":  # người que với tư thế/chuyển động theo động từ
        head = GRP([EL((0, -56), (38, 38)), FL(YELLOW), ST(DARK, 4)], "head")
        body = GRP([SH([(0, -36), (0, 30)], False), ST(DARK, 9)], "body")
        poses = {
            "run": ([-32, -16], [28, 38]), "walk": ([-25, -25], [22, 24]),
            "jump": ([-40, -35], [40, 35]), "swim": ([-45, 8], [45, 8]),
            "climb": ([-30, -20], [30, -20]), "dance": ([-45, -25], [45, -30]),
            "sit": ([-34, 8], [38, 40]), "stand": ([-25, 0], [25, 0]),
            "sleep": ([-24, 6], [24, 6]), "wake-up": ([-40, -15], [26, -28]),
            "eat": ([-30, 4], [28, -30]), "drink": ([-28, 4], [28, -28]),
            "cook": ([-34, -8], [32, -10]), "read": ([-28, -18], [28, -18]),
            "write": ([-28, 0], [28, -16]), "speak": ([-28, 0], [28, -8]),
            "listen": ([-28, 0], [32, -18]), "think": ([-28, 0], [28, -28]),
        }
        left, right = poses.get(slug, ([-28, 0], [28, 0]))
        arm_l = GRP([SH([(0, 0), left], False), ST(DARK, 8)], "arm")
        arm_r = GRP([SH([(0, 0), right], False), ST(DARK, 8)], "arm")
        leg_l = GRP([SH([(0, 0), (-24, 44)], False), ST(DARK, 9)], "leg")
        leg_r = GRP([SH([(0, 0), (24, 44)], False), ST(DARK, 9)], "leg")
        props = []
        if slug in ("read", "write"):
            props = [GRP([RC((0, 0), (46, 34), 3), FL(WHITE), ST(BROWN, 3)], "book",
                         tr=TR(p=(0, -8)))]
        elif slug in ("eat", "drink"):
            props = [GRP([RC((0, 0), (26, 34), 5), FL(SKY), ST(BLUE, 3)], "cup",
                         tr=TR(p=(18, -8)))]
        elif slug == "think":
            props = [GRP([EL((0, 0), (30, 30)), FL(WHITE), ST(PURPLE, 3)], "idea",
                         tr=TR(p=(48, -50)))]
        elif slug in ("speak", "listen"):
            props = [GRP([EL((0, 0), (42, 30)), FL(WHITE), ST(BLUE, 3)], "bubble",
                         tr=TR(p=(48, -48)))]
        person = LYR(1, "person", [head, body, arm_l, arm_r, leg_l, leg_r] + props,
                     p=bounce, r=turn, op=op)
        layers = [person]

    elif group == "B":  # mặt biểu cảm gốc
        eye_shapes = [EL((-28, -16), (15, 20)), EL((28, -16), (15, 20)), FL(DARK)]
        if slug in ("surprised", "afraid"):
            mouth = GRP([EL((0, 32), (25, 32)), FL(DARK)], "mouth")
        elif slug in ("angry",):
            mouth = GRP([SH([(-25, 33), (0, 23), (25, 33)], False), ST(DARK, 7)], "mouth")
        elif slug in ("laugh",):
            mouth = GRP([EL((0, 24), (52, 40)), FL(DARK)], "mouth")
        else:
            mouth = GRP([SH(ARC((0, 2), 38, 25, 155, 16), False), ST(DARK, 8)], "mouth")
        brows = []
        if slug in ("angry", "afraid"):
            brows = [GRP([SH([(-43, -38), (-12, -26)], False),
                          SH([(43, -38), (12, -26)], False), ST(DARK, 7)], "brows")]
        cheeks = [] if slug not in ("happy", "laugh") else [
            GRP([EL((-49, 18), (25, 14)), EL((49, 18), (25, 14)), FL(PINK, 60)], "cheeks")]
        face = LYR(1, "face", [GRP([EL((0, 0), (150, 150)), FL(YELLOW), ST(ORANGE, 4)], "base"),
                               GRP(eye_shapes, "eyes"), mouth] + brows + cheeks,
                   s=loop_scale(op, 104), op=op)
        layers = [face]

    elif group == "C":  # thân + đầu + tai/đuôi — mô-típ động vật
        body_color = BROWN if slug in ("horse", "cow", "pig", "elephant") else color
        torso = GRP([EL((-6, 12), (100, 58)), FL(body_color), ST(DARK, 3)], "body")
        head = GRP([EL((44, -18), (54, 52)), FL(body_color), ST(DARK, 3)], "head")
        eyes = GRP([EL((58, -26), (8, 8)), FL(DARK)], "eye")
        legs = GRP([RC((-32, 48), (10, 38), 4), RC((8, 48), (10, 38), 4), FL(DARK)], "legs")
        ears = []
        if slug in ("cat", "dog", "horse", "pig", "elephant"):
            ears = [GRP([SH([(25, -38), (24, -66), (46, -43)]),
                        SH([(55, -43), (74, -66), (76, -34)]),
                        FL(body_color), ST(DARK, 3)], "ears")]
        tail_pts = [(0, 0), (-18, -12), (-28, 0), (-20, 12)]
        extras = [GRP([SH(tail_pts, False), ST(DARK, 5)], "tail", tr=TR(p=(-52, 8)))]
        if slug == "elephant":
            extras.append(GRP([SH([(62, -8), (78, 8), (72, 28)], False), ST(DARK, 8)], "trunk"))
        if slug == "bird":
            extras.extend([GRP([SH([(60, -22), (84, -12), (60, -4)]), FL(ORANGE)], "beak"),
                           GRP([EL((0, 10), (44, 20)), FL(WHITE)], "wing")])
        if slug == "bee":
            extras.extend([GRP([EL((4, -34), (24, 34)), FL(WHITE, 80), ST(SKY, 2)], "wing"),
                           GRP([RC((0, 0), (16, 45), 5), FL(GOLD), ST(DARK, 2)], "stripe")])
        if slug == "snake":
            extras = [GRP([SH(QB((-56, 34), (0, 68), (70, 34), 18), False), ST(GREEN, 14)], "coil"),
                      GRP([SH([(68, 34), (82, 28), (87, 35)], False), ST(RED, 4)], "tongue")]
        animal = LYR(1, "animal", [torso, head, ears[0] if ears else GRP([], "ears"), legs, eyes] + extras,
                     p=bounce, r=turn, op=op)
        layers = [animal]

    elif group == "E":  # đồ vật gia dụng
        if slug == "house":
            parts = [GRP([RC((0, 20), (110, 80), 2), FL(SKY), ST(DARK, 5)], "wall"),
                     GRP([SH([(-66, -15), (0, -72), (66, -15)]), FL(RED), ST(DARK, 5)], "roof"),
                     GRP([RC((0, 34), (28, 52), 2), FL(BROWN)], "door"),
                     GRP([RC((-36, 4), (24, 24), 2), FL(WHITE), ST(BLUE, 3)], "window")]
        elif slug in ("book", "phone", "computer"):
            parts = [GRP([RC((0, 0), (112, 144), 9), FL(DARK)], "frame"),
                     GRP([RC((0, -3), (94, 122), 4), FL(SKY)], "screen")]
            if slug == "book":
                parts = [GRP([RC((-27, 0), (58, 126), 3), RC((27, 0), (58, 126), 3),
                              FL(WHITE), ST(BROWN, 4)], "pages"),
                         GRP([SH([(0, -60), (0, 60)], False), ST(BROWN, 4)], "spine")]
        elif slug == "key":
            parts = [GRP([EL((-35, 0), (52, 52)), ST(GOLD, 10),
                          RC((25, 0), (78, 12), 4), RC((55, 12), (10, 18), 2),
                          RC((78, 11), (10, 16), 2), FL(GOLD)], "key")]
        elif slug == "door":
            parts = [GRP([RC((0, 0), (90, 150), 3), FL(BROWN), ST(DARK, 5)], "door"),
                     GRP([EL((28, 10), (10, 10)), FL(GOLD)], "knob")]
        elif slug in ("chair", "bed"):
            parts = [GRP([RC((0, -10), (116, 28), 6), FL(color), ST(DARK, 4)], "seat"),
                     GRP([RC((-44, 36), (10, 66), 3), RC((44, 36), (10, 66), 3), FL(BROWN)], "legs")]
            if slug == "bed": parts.append(GRP([RC((0, -34), (116, 36), 7), FL(WHITE), ST(SKY, 3)], "pillow"))
            if slug == "chair": parts.append(GRP([RC((0, -54), (116, 22), 6), FL(color)], "back"))
        elif slug == "cup":
            parts = [GRP([SH([(-44, -44), (44, -44), (34, 54), (-34, 54)]), FL(WHITE), ST(DARK, 5)], "cup"),
                     GRP([EL((48, 4), (35, 52)), ST(DARK, 6)], "handle"),
                     GRP([RC((0, -25), (78, 6), 3), FL(BROWN)], "drink")]
        elif slug == "car":
            parts = [GRP([SH([(-72, 15), (-54, -24), (24, -24), (62, 10), (70, 25), (-72, 25)]),
                          FL(RED), ST(DARK, 4)], "car"),
                     GRP([EL((-43, 30), (28, 28)), EL((42, 30), (28, 28)), FL(DARK)], "wheels")]
        else:
            parts = [GRP([RC((0, 0), (112, 116), 12), FL(color), ST(DARK, 4)], "object"),
                     GRP([EL((0, 0), (40, 40)), FL(WHITE)], "detail")]
        obj = LYR(1, "object", parts, r=turn, s=loop_scale(op, 104), op=op)
        layers = [obj]

    elif group == "F":  # đi lại và nơi chốn
        if slug in ("school", "hospital", "market-shop"):
            facade = [GRP([RC((0, 18), (128, 118), 4), FL(WHITE), ST(DARK, 4)], "wall"),
                      GRP([SH([(-76, -40), (0, -82), (76, -40)]), FL(color), ST(DARK, 4)], "roof"),
                      GRP([RC((0, 48), (32, 58), 2), FL(SKY), ST(DARK, 3)], "door"),
                      GRP([RC((-43, 2), (28, 28), 2), RC((43, 2), (28, 28), 2), FL(BLUE)], "windows")]
            if slug == "hospital": facade.append(GRP([RC((0, -41), (48, 12), 3), RC((0, -41), (12, 48), 3), FL(RED)], "cross"))
            if slug == "school": facade.append(GRP([SR(3, 20, p=(0, -35)), FL(GOLD)], "bell"))
            parts = facade
        elif slug == "boat":
            parts = [GRP([SH([(-72, 10), (72, 10), (42, 48), (-42, 48)]), FL(BLUE), ST(DARK, 4)], "hull"),
                     GRP([SH([(0, -70), (0, 0), (50, 0)]), FL(WHITE), ST(DARK, 4)], "sail")]
        elif slug in ("bus", "train"):
            parts = [GRP([RC((0, -3), (140, 72), 12), FL(YELLOW), ST(DARK, 4)], "body"),
                     GRP([RC((-42, -15), (31, 26), 3), RC((0, -15), (31, 26), 3), RC((42, -15), (31, 26), 3), FL(SKY)], "windows"),
                     GRP([EL((-45, 38), (24, 24)), EL((45, 38), (24, 24)), FL(DARK)], "wheels")]
            if slug == "train": parts.append(GRP([RC((78, -8), (20, 62), 5), FL(RED)], "carriage"))
        else: # bicycle
            parts = [GRP([EL((-47, 24), (52, 52)), EL((47, 24), (52, 52)), ST(BLUE, 5)], "wheels"),
                     GRP([SH([(-47, 24), (-12, -18), (8, 24), (-47, 24), (47, 24), (8, 24), (18, -20)], False), ST(RED, 6)], "frame")]
        vehicle = LYR(1, "place-vehicle", parts, p=bounce, op=op)
        layers = [vehicle]

    elif group == "G":  # đồ ăn
        if slug in ("apple", "egg"):
            fruit = GRP([EL((0, 6), (96, 112)), FL(RED if slug == "apple" else WHITE), ST(DARK, 4)], "food")
            extras = [GRP([SH([(0, -49), (2, -72)], False), ST(DGREEN, 7)], "stem"),
                      GRP([EL((19, -61), (34, 18)), FL(GREEN)], "leaf")]
            parts = [fruit] + extras
        elif slug == "banana":
            parts = [GRP([SH([(-58, -38), (-30, 32), (28, 54), (62, 12), (28, 34), (-20, 16), (-43, -45)]),
                          FL(YELLOW), ST(GOLD, 4)], "banana")]
        elif slug in ("bread", "cake"):
            parts = [GRP([RC((0, 6), (122, 84), 20), FL(BROWN if slug == "bread" else PINK), ST(DARK, 4)], "base"),
                     GRP([EL((-30, -24), (12, 12)), EL((0, -36), (12, 12)), EL((31, -24), (12, 12)), FL(YELLOW)], "topping")]
        elif slug == "milk":
            parts = [GRP([SH([(-42, -55), (-20, -78), (20, -78), (42, -55), (42, 60), (-42, 60)]), FL(WHITE), ST(SKY, 4)], "carton"),
                     GRP([RC((0, 10), (52, 34), 5), FL(SKY)], "label")]
        elif slug == "coffee":
            parts = [GRP([RC((0, 6), (88, 76), 12), FL(BROWN), ST(DARK, 4)], "cup"),
                     GRP([EL((48, 6), (34, 40)), ST(DARK, 5)], "handle"),
                     GRP([SH([(-25, -44), (-33, -62), (-24, -75)], False), SH([(0, -44), (-7, -62), (1, -75)], False), ST(GRAY, 4)], "steam")]
        elif slug == "rice":
            parts = [GRP([SH([(-62, -4), (-46, 46), (46, 46), (62, -4)]), FL(WHITE), ST(BLUE, 4)], "bowl"),
                     GRP([EL((-20, -22), (30, 22)), EL((14, -27), (30, 22)), FL(WHITE)], "rice")]
        else: # banana? all remaining: simple egg/cake style
            parts = [GRP([EL((0, 6), (100, 106)), FL(GOLD), ST(ORANGE, 4)], "food"),
                     GRP([SR(5, 15, p=(0, -3)), FL(WHITE)], "spark")]
        food = LYR(1, "food", parts, p=bounce, r=turn, op=op)
        layers = [food]

    elif group == "H":  # biểu tượng cơ thể người
        if slug == "hand":
            pts = [(-40, 55), (-42, -4), (-54, -32), (-43, -46), (-27, -15),
                   (-22, -68), (-5, -72), (2, -20), (7, -82), (25, -82),
                   (28, -19), (42, -65), (59, -58), (48, 8), (28, 56)]
            parts = [GRP([SH(pts), FL(YELLOW), ST(DARK, 4)], "hand")]
        elif slug == "ear":
            parts = [GRP([SH(ARC((0, 0), 58, -100, 100, 26) + QB((58, -10), (20, -14), (25, 38), 12), False), ST(BROWN, 11)], "ear"),
                     GRP([SH(ARC((8, 0), 28, -85, 85, 18), False), ST(ORANGE, 7)], "inner")]
        elif slug == "mouth":
            parts = [GRP([EL((0, 0), (112, 72)), FL(RED), ST(DARK, 4)], "mouth"),
                     GRP([SH([(-42, -8), (0, -2), (42, -8)]), FL(WHITE)], "teeth")]
        elif slug == "head":
            parts = [GRP([EL((0, 0), (122, 142)), FL(YELLOW), ST(DARK, 4)], "head"),
                     GRP([EL((-25, -14), (12, 18)), EL((25, -14), (12, 18)), FL(DARK)], "eyes"),
                     GRP([SH(ARC((0, 6), 28, 25, 155, 12), False), ST(DARK, 5)], "smile")]
        else: # baby/man/woman
            parts = [GRP([EL((0, -45), (68, 68)), FL(YELLOW), ST(DARK, 4)], "head"),
                     GRP([RC((0, 32), (78, 78), 24), FL(PINK if slug == "woman" else BLUE), ST(DARK, 4)], "body"),
                     GRP([EL((-16, -52), (8, 10)), EL((16, -52), (8, 10)), FL(DARK)], "eyes"),
                     GRP([SH(ARC((0, -35), 16, 25, 155, 9), False), ST(DARK, 4)], "smile")]
            if slug == "baby": parts.append(GRP([EL((0, -74), (76, 25)), FL(PINK)], "cap"))
        person = LYR(1, "body-part", parts, r=turn, s=loop_scale(op, 104), op=op)
        layers = [person]

    else:  # I: khái niệm động (mở/đóng, nhiệt, tiền, quà, câu hỏi)
        if slug == "open-close":
            parts = [GRP([RC((0, 0), (100, 148), 4), FL(BROWN), ST(DARK, 4)], "door"),
                     GRP([EL((30, 0), (11, 11)), FL(GOLD)], "knob")]
            layer = LYR(1, "door", parts, r=A([(0, [-8]), (45, [12]), (90, [-8])]), op=op)
        elif slug == "hot-cold":
            parts = [GRP([RC((0, -12), (34, 110), 17), FL(WHITE), ST(DARK, 4)], "tube"),
                     GRP([EL((0, 43), (45, 45)), FL(RED)], "bulb"),
                     GRP([RC((0, 12), (15, 70), 7), FL(RED)], "mercury"),
                     GRP([SR(8, 72, 53), FL(SKY, 65)], "cold")]
            layer = LYR(1, "temp", parts, s=loop_scale(op, 106), op=op)
        elif slug == "money":
            coin = [GRP([EL((0, 0), (85, 85)), FL(GOLD), ST(ORANGE, 5)], "coin"),
                    GRP([EL((0, 0), (28, 42)), ST(ORANGE, 5)], "mark")]
            layer = LYR(1, "coin", coin,
                        p=A([(0, [120, 58, 0]), (45, [120, 144, 0]), (90, [120, 198, 0])]),
                        r=A([(0, [0]), (90, [540])]), op=op)
        elif slug == "gift":
            parts = [GRP([RC((0, 17), (112, 74), 5), FL(RED), ST(DARK, 4)], "box"),
                     GRP([RC((0, -29), (128, 20), 5), FL(RED), ST(DARK, 4)], "lid"),
                     GRP([RC((0, 17), (17, 74), 3), RC((0, -29), (17, 20), 3), FL(GOLD)], "ribbon"),
                     GRP([EL((-12, -48), (34, 22)), EL((12, -48), (34, 22)), ST(GOLD, 6)], "bow")]
            layer = LYR(1, "gift", parts, s=A([(0, [0, 0, 100]), (18, [100, 100, 100]), (90, [100, 100, 100])]), op=op)
        elif slug == "question":
            parts = [GRP([SR(3, 72, p=(0, 0)), FL(PURPLE)], "burst"),
                     GRP([SH(QB((0, -35), (52, -48), (25, -6), 12) + QB((25, -6), (0, 8), (0, 30), 8), False), ST(WHITE, 12)], "q"),
                     GRP([EL((0, 51), (12, 12)), FL(WHITE)], "dot")]
            layer = LYR(1, "question", parts, r=turn, op=op)
        else:
            parts = [GRP([EL((0, 0), (112, 112)), FL(SKY), ST(BLUE, 5)], "disc"),
                     GRP([SH([(-48, 0), (48, 0)], False), SH([(0, -48), (0, 48)], False), ST(WHITE, 12)], "plus")]
            layer = LYR(1, "concept", parts, r=A([(0, [0]), (90, [360])], linear=True), op=op)
        layers = [layer]

    return DOC(slug, layers, op)


DRAW = {
    "sun": d_sun, "moon": d_moon, "star": d_star, "rain": d_rain,
    "snow": d_snow, "wind": d_wind, "cloud": d_cloud,
    "lightning": d_lightning, "fire": d_fire, "water-wave": d_wave,
    "tree": d_tree, "flower": d_flower, "love-heart": d_heart,
    "happy": lambda: _face("happy"), "sad": lambda: _face("sad"),
    "up-down": d_updown, "day-night": d_daynight, "music": d_music,
    "check-yes-no": d_check, "fall": d_fall, "grow": d_grow,
    "clock": d_clock, "light-lamp": d_light, "eye": d_eye,
    "fish": d_fish, "butterfly": d_butterfly, "airplane": d_airplane,
}

# ───────────────────────── pack data (100) ─────────────────────────
GROUPS = {
    "A": "Hành động cơ thể",
    "B": "Cảm xúc & trạng thái",
    "C": "Động vật",
    "D": "Thiên nhiên & thời tiết",
    "E": "Đồ vật & nhà cửa",
    "F": "Đi lại & nơi chốn",
    "G": "Ăn uống",
    "H": "Con người & cơ thể",
    "I": "Chuyển động đặc trưng",
}

# (group, slug, glossVi, [EN keywords])
CONCEPTS = [
    ("A", "run", "chạy", ["run", "running"]),
    ("A", "walk", "đi bộ", ["walk", "walking"]),
    ("A", "jump", "nhảy", ["jump", "jumping"]),
    ("A", "swim", "bơi", ["swim", "swimming"]),
    ("A", "climb", "leo, trèo", ["climb", "climbing"]),
    ("A", "dance", "nhảy múa", ["dance", "dancing"]),
    ("A", "sit", "ngồi", ["sit", "sitting"]),
    ("A", "stand", "đứng", ["stand", "standing"]),
    ("A", "sleep", "ngủ", ["sleep", "sleeping"]),
    ("A", "wake-up", "thức dậy", ["wake up", "alarm clock"]),
    ("A", "eat", "ăn", ["eat", "eating"]),
    ("A", "drink", "uống", ["drink", "drinking"]),
    ("A", "cook", "nấu ăn", ["cook", "cooking", "chef"]),
    ("A", "read", "đọc", ["read", "reading book"]),
    ("A", "write", "viết", ["write", "writing", "pencil"]),
    ("A", "speak", "nói", ["speak", "talking"]),
    ("A", "listen", "nghe", ["listen", "headphones"]),
    ("A", "think", "suy nghĩ", ["think", "thinking", "idea"]),
    ("B", "happy", "vui, hạnh phúc", ["happy", "smile"]),
    ("B", "sad", "buồn", ["sad"]),
    ("B", "angry", "giận", ["angry"]),
    ("B", "surprised", "ngạc nhiên", ["surprised", "wow"]),
    ("B", "afraid", "sợ", ["afraid", "scared"]),
    ("B", "love-heart", "yêu, trái tim", ["love", "heart"]),
    ("B", "laugh", "cười lớn", ["laugh", "laughing"]),
    ("B", "cry", "khóc", ["cry", "crying"]),
    ("B", "tired", "mệt", ["tired", "sleepy"]),
    ("B", "sick", "ốm, bệnh", ["sick", "ill"]),
    ("C", "dog", "con chó", ["dog", "puppy"]),
    ("C", "cat", "con mèo", ["cat", "kitten"]),
    ("C", "bird", "con chim", ["bird", "flying bird"]),
    ("C", "fish", "con cá", ["fish", "swimming fish"]),
    ("C", "butterfly", "con bướm", ["butterfly"]),
    ("C", "bee", "con ong", ["bee"]),
    ("C", "horse", "con ngựa", ["horse", "running horse"]),
    ("C", "cow", "con bò", ["cow"]),
    ("C", "pig", "con lợn, heo", ["pig"]),
    ("C", "chicken", "con gà", ["chicken", "hen"]),
    ("C", "snake", "con rắn", ["snake"]),
    ("C", "elephant", "con voi", ["elephant"]),
    ("D", "sun", "mặt trời", ["sun", "sunshine"]),
    ("D", "moon", "mặt trăng", ["moon", "night"]),
    ("D", "star", "ngôi sao", ["star", "twinkle"]),
    ("D", "rain", "mưa", ["rain", "rainy"]),
    ("D", "snow", "tuyết", ["snow", "snowflake"]),
    ("D", "wind", "gió", ["wind", "windy"]),
    ("D", "cloud", "mây", ["cloud"]),
    ("D", "lightning", "sét", ["lightning", "thunder"]),
    ("D", "fire", "lửa", ["fire", "flame"]),
    ("D", "water-wave", "nước, sóng", ["water", "wave", "sea"]),
    ("D", "tree", "cây", ["tree"]),
    ("D", "flower", "hoa", ["flower", "bloom"]),
    ("E", "house", "ngôi nhà", ["house", "home"]),
    ("E", "door", "cửa", ["door", "open door"]),
    ("E", "key", "chìa khoá", ["key"]),
    ("E", "book", "sách", ["book", "open book"]),
    ("E", "phone", "điện thoại", ["phone", "smartphone"]),
    ("E", "computer", "máy tính", ["computer", "laptop"]),
    ("E", "light-lamp", "đèn, ánh sáng", ["light bulb", "lamp"]),
    ("E", "clock", "đồng hồ", ["clock", "time"]),
    ("E", "chair", "ghế", ["chair"]),
    ("E", "bed", "giường", ["bed"]),
    ("E", "cup", "cốc, tách", ["cup", "mug"]),
    ("E", "car", "ô tô, xe hơi", ["car", "driving"]),
    ("F", "bicycle", "xe đạp", ["bicycle", "cycling"]),
    ("F", "bus", "xe buýt", ["bus"]),
    ("F", "train", "tàu hoả", ["train"]),
    ("F", "airplane", "máy bay", ["airplane", "plane flying"]),
    ("F", "boat", "thuyền, tàu", ["boat", "ship"]),
    ("F", "school", "trường học", ["school"]),
    ("F", "hospital", "bệnh viện", ["hospital"]),
    ("F", "market-shop", "chợ, cửa hàng", ["market", "shop", "store"]),
    ("G", "apple", "quả táo", ["apple"]),
    ("G", "banana", "quả chuối", ["banana"]),
    ("G", "bread", "bánh mì", ["bread"]),
    ("G", "egg", "trứng", ["egg", "fried egg"]),
    ("G", "milk", "sữa", ["milk"]),
    ("G", "coffee", "cà phê", ["coffee"]),
    ("G", "rice", "cơm, gạo", ["rice", "rice bowl"]),
    ("G", "cake", "bánh ngọt", ["cake", "birthday cake"]),
    ("H", "hand", "bàn tay", ["hand", "waving hand"]),
    ("H", "eye", "mắt", ["eye", "blinking eye"]),
    ("H", "ear", "tai", ["ear"]),
    ("H", "mouth", "miệng", ["mouth"]),
    ("H", "head", "đầu", ["head"]),
    ("H", "baby", "em bé", ["baby"]),
    ("H", "man", "người đàn ông", ["man"]),
    ("H", "woman", "người phụ nữ", ["woman"]),
    ("I", "grow", "lớn lên, mọc", ["grow", "growing plant", "sprout"]),
    ("I", "fall", "rơi", ["falling leaf", "fall"]),
    ("I", "fly", "bay", ["fly", "flying"]),
    ("I", "open-close", "mở, đóng", ["open close", "door open"]),
    ("I", "up-down", "lên, xuống", ["up down", "arrows"]),
    ("I", "hot-cold", "nóng, lạnh", ["hot cold", "thermometer"]),
    ("I", "day-night", "ngày, đêm", ["day night", "sun moon"]),
    ("I", "music", "âm nhạc", ["music", "music note"]),
    ("I", "money", "tiền", ["money", "coins"]),
    ("I", "gift", "quà", ["gift", "present box"]),
    ("I", "question", "câu hỏi (dấu ?)", ["question mark", "question"]),
    ("I", "check-yes-no", "đúng, sai (✓/✗)", ["check mark", "yes no"]),
]

def main():
    assert len(CONCEPTS) == 100, len(CONCEPTS)
    os.makedirs(OUT_DIR, exist_ok=True)
    concepts = []
    drawn = 0
    for group, slug, gloss, keywords in CONCEPTS:
        animations = []
        fn = DRAW.get(slug) or (lambda g=group, s=slug: d_original_icon(g, s))
        if fn is not None:
            doc = fn()
            blob = json.dumps(doc, separators=(",", ":"), ensure_ascii=False)
            # kiểm chứng tối thiểu theo đúng cổng kiểm của app
            head = blob[:2048]
            assert '"v"' in head and ('"layers"' in head or '"fr"' in head), slug
            assert len(blob) < 200 * 1024, slug
            path = os.path.join(OUT_DIR, slug + ".json")
            with open(path, "w", encoding="utf-8") as f:
                f.write(blob)
            drawn += 1
            animations.append({
                "type": "asset",
                "path": "assets/animations/files/%s.json" % slug,
                "license": "In4Up original · CC0",
                "author": "In4Up (tool/generate_concept_animations.py)",
            })
        concepts.append({
            "id": slug,
            "group": group,
            "glossVi": gloss,
            "keywords": keywords,
            "animations": animations,
        })
    pack = {
        "schema": "in4up.concept_animation_pack/1",
        "version": 1,
        "note": "Danh sach 100 khai niem duoc owner duyet 2026-11-05 "
                "(docs/plans/PLAN-041-animation-core-concepts.md). Cac "
                "animation deu la pictogram hinh hoc goc In4Up, CC0; khong "
                "chua tai nguyen/thumbnail cua ben thu ba.",
        "groups": GROUPS,
        "concepts": concepts,
    }
    with open(OUT_PACK, "w", encoding="utf-8") as f:
        json.dump(pack, f, ensure_ascii=False, indent=1)
    total_kb = sum(os.path.getsize(os.path.join(OUT_DIR, n))
                   for n in os.listdir(OUT_DIR) if n.endswith(".json")) / 1024
    print("concepts=%d drawn=%d pack=%s files=%.0fKB"
          % (len(concepts), drawn, OUT_PACK, total_kb))

if __name__ == "__main__":
    main()
