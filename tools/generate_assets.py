#!/usr/bin/env python3
"""Генератор пиксель-арт ассетов для LowerTale (Godot).
Создаёт PNG в project/sprites/: тайлы, персонажей, монстров, UI.
Запуск: python3 tools/generate_assets.py
"""
import os, math, random
from PIL import Image, ImageDraw

random.seed(7)
OUT = os.path.join(os.path.dirname(__file__), "..", "project", "sprites")
os.makedirs(OUT, exist_ok=True)

def new(w, h, color=(0, 0, 0, 0)):
    return Image.new("RGBA", (w, h), color)

def save(img, name):
    img.save(os.path.join(OUT, name))

# ---------------- Тайлы 16x16 ----------------
def tile_floor(base, dot, name):
    t = new(16, 16, base)
    d = ImageDraw.Draw(t)
    for y in range(16):
        for x in range(16):
            if random.random() < 0.08:
                d.point((x, y), dot)
    for _ in range(2):
        x0 = random.randint(0, 12); y0 = random.randint(0, 12)
        d.line([(x0, y0), (x0 + random.randint(1, 4), y0 + random.randint(1, 3))], fill=dot, width=1)
    save(t, name)

def tile_wall(top, body, edge, name):
    t = new(16, 16, body)
    d = ImageDraw.Draw(t)
    d.rectangle([0, 0, 15, 3], fill=top)
    d.line([(0, 4), (15, 4)], fill=edge)
    for y in range(6, 16, 5):
        d.line([(0, y), (15, y)], fill=edge)
    for x in (3, 11):
        d.line([(x, 5), (x, min(15, 9))], fill=edge)
    save(t, name)

def tile_grass(base, blade, name):
    t = new(16, 16, base)
    d = ImageDraw.Draw(t)
    for _ in range(22):
        x = random.randint(0, 15); y = random.randint(2, 15)
        d.line([(x, y), (x + random.choice([-1, 0, 1]), y - random.randint(2, 4))], fill=blade)
    save(t, name)

tile_floor((46, 42, 54), (58, 54, 68), "ruins_floor.png")
tile_wall((92, 86, 108), (60, 56, 72), (30, 28, 38), "ruins_wall.png")
tile_floor((84, 60, 48), (100, 74, 58), "cave_floor.png")
tile_wall((120, 88, 64), (86, 62, 46), (52, 36, 28), "cave_wall.png")
tile_grass((42, 74, 46), (66, 110, 66), "moss_floor.png")
tile_wall((58, 96, 58), (38, 66, 42), (22, 40, 26), "moss_wall.png")
tile_floor((36, 58, 84), (48, 74, 104), "ice_floor.png")
tile_wall((110, 160, 200), (60, 96, 140), (36, 60, 92), "ice_wall.png")
tile_floor((52, 46, 74), (66, 60, 92), "void_floor.png")
tile_wall((88, 78, 120), (56, 50, 80), (30, 26, 46), "void_wall.png")

t = new(16, 16, (30, 50, 90))
d = ImageDraw.Draw(t)
for i in range(6):
    d.arc([i, i, 15 - i, 15 - i], 0, 360, fill=(70, 120, 180))
save(t, "water.png")

# ---------------- Персонаж игрока 16x24 ----------------
def make_human(hair, shirt, skin=(240, 200, 170)):
    p = new(16, 24)
    d = ImageDraw.Draw(p)
    d.rectangle([4, 2, 11, 9], fill=skin)
    d.rectangle([3, 1, 12, 4], fill=hair)
    d.rectangle([3, 2, 4, 7], fill=hair)
    d.rectangle([11, 2, 12, 7], fill=hair)
    d.point((6, 6), fill=(20, 20, 30)); d.point((9, 6), fill=(20, 20, 30))
    d.rectangle([4, 10, 11, 17], fill=shirt)
    d.rectangle([2, 10, 3, 15], fill=shirt)
    d.rectangle([12, 10, 13, 15], fill=shirt)
    d.rectangle([4, 18, 11, 21], fill=(50, 50, 90))
    d.rectangle([4, 22, 6, 23], fill=(30, 30, 40))
    d.rectangle([9, 22, 11, 23], fill=(30, 30, 40))
    return p

save(make_human((90, 60, 40), (60, 130, 90)), "player.png")
save(make_human((200, 180, 60), (200, 60, 60)), "asgore_kid.png")

def heart(color):
    h = new(16, 16)
    d = ImageDraw.Draw(h)
    d.ellipse([2, 2, 7, 7], fill=color)
    d.ellipse([8, 2, 13, 7], fill=color)
    d.polygon([(2, 5), (13, 5), (8, 14)], fill=color)
    return h
save(heart((255, 40, 40)), "soul_red.png")
save(heart((255, 255, 255)), "soul_white.png")

# ---------------- Монстры ----------------
def glow_circle(img, cx, cy, r, color, alpha_step=24):
    d = ImageDraw.Draw(img)
    for i in range(r, 0, -1):
        a = max(10, int(alpha_step * (1 - i / r)))
        c = tuple(color[:3]) + (a,)
        d.ellipse([cx - i, cy - i, cx + i, cy + i], fill=c)

g = new(32, 32)
glow_circle(g, 16, 16, 15, (255, 240, 120), 14)
d = ImageDraw.Draw(g)
d.ellipse([10, 10, 22, 22], fill=(255, 230, 90))
d.ellipse([12, 6, 19, 12], fill=(255, 250, 200))
d.point((14, 15), fill=(30, 30, 30)); d.point((18, 15), fill=(30, 30, 30))
d.arc([13, 16, 19, 20], 0, 180, fill=(30, 30, 30))
save(g, "glim.png")

e = new(48, 40)
d = ImageDraw.Draw(e)
d.rounded_rectangle([8, 14, 36, 30], radius=6, fill=(120, 60, 40))
d.polygon([(36, 20), (46, 16), (44, 24), (36, 26)], fill=(100, 50, 35))
d.ellipse([2, 10, 16, 24], fill=(140, 70, 45))
d.point((6, 15), fill=(255, 200, 60)); d.point((11, 15), fill=(255, 200, 60))
for (x, y) in [(14, 12), (20, 16), (26, 12), (30, 18)]:
    glow_circle(e, x, y, 4, (255, 120, 40), 40)
d.rectangle([12, 30, 16, 36], fill=(90, 45, 30)); d.rectangle([28, 30, 32, 36], fill=(90, 45, 30))
save(e, "ember.png")

c = new(40, 48)
d = ImageDraw.Draw(c)
d.rounded_rectangle([8, 16, 32, 42], radius=4, fill=(120, 130, 150))
d.rectangle([12, 8, 28, 18], fill=(150, 160, 180))
d.rectangle([15, 11, 19, 15], fill=(80, 220, 255)); d.rectangle([22, 11, 26, 15], fill=(80, 220, 255))
d.line([(20, 4), (20, 8)], fill=(200, 200, 200)); d.ellipse([18, 0, 22, 4], fill=(255, 80, 80))
d.rectangle([2, 20, 8, 34], fill=(100, 110, 130)); d.rectangle([32, 20, 38, 34], fill=(100, 110, 130))
d.rectangle([14, 26, 26, 34], fill=(60, 70, 90))
d.line([(16, 28), (24, 28)], fill=(255, 255, 255)); d.line([(16, 31), (22, 31)], fill=(255, 255, 255))
save(c, "cog.png")

h = new(56, 64)
glow_circle(h, 28, 30, 26, (150, 140, 255), 12)
d = ImageDraw.Draw(h)
body = (180, 175, 240, 140)
d.rounded_rectangle([16, 26, 40, 46], radius=8, fill=body)
d.ellipse([20, 12, 32, 26], fill=body)
d.polygon([(22, 14), (18, 2), (20, 12)], fill=body); d.polygon([(30, 14), (34, 2), (32, 12)], fill=body)
d.line([(18, 6), (14, 0)], fill=body); d.line([(34, 6), (38, 0)], fill=body)
d.point((24, 18), fill=(255, 255, 255)); d.point((29, 18), fill=(255, 255, 255))
for y in range(46, 60, 4):
    d.line([(20, y), (36, y)], fill=(180, 175, 240, max(20, 120 - (y - 46) * 12)))
save(h, "echo_deer.png")

t = new(56, 64)
d = ImageDraw.Draw(t)
d.polygon([(16, 60), (20, 24), (28, 20), (36, 24), (40, 60)], fill=(70, 90, 60))
d.ellipse([12, 4, 44, 34], fill=(50, 110, 50))
d.ellipse([6, 14, 26, 36], fill=(60, 120, 60)); d.ellipse([30, 14, 50, 36], fill=(60, 120, 60))
d.point((22, 20), fill=(220, 255, 120)); d.point((34, 20), fill=(220, 255, 120))
d.arc([22, 24, 34, 32], 0, 180, fill=(30, 60, 30))
for x in (14, 42):
    d.line([(x, 40), (x + (6 if x < 28 else -6), 52)], fill=(70, 90, 60), width=3)
save(t, "thorn.png")

l = new(48, 56)
glow_circle(l, 24, 28, 22, (255, 250, 180), 16)
d = ImageDraw.Draw(l)
d.ellipse([18, 10, 30, 22], fill=(250, 240, 200))
d.polygon([(24, 20), (14, 46), (34, 46)], fill=(255, 250, 210))
d.polygon([(16, 24), (2, 16), (14, 32)], fill=(255, 255, 255, 120))
d.polygon([(32, 24), (46, 16), (34, 32)], fill=(255, 255, 255, 120))
d.point((21, 15), fill=(60, 60, 90)); d.point((27, 15), fill=(60, 60, 90))
save(l, "lumen.png")

k = new(64, 72)
d = ImageDraw.Draw(k)
d.polygon([(32, 2), (24, 14), (40, 14)], fill=(150, 180, 230))
d.rectangle([28, 10, 36, 16], fill=(150, 180, 230))
d.ellipse([22, 14, 42, 34], fill=(200, 215, 240))
d.point((28, 24), fill=(30, 40, 80)); d.point((36, 24), fill=(30, 40, 80))
d.polygon([(22, 30), (42, 30), (48, 68), (16, 68)], fill=(70, 90, 150))
d.polygon([(16, 68), (22, 40), (10, 46)], fill=(60, 80, 140))
d.polygon([(48, 68), (42, 40), (54, 46)], fill=(60, 80, 140))
for i in range(3):
    d.line([(26 + i * 6, 30), (24 + i * 6, 66)], fill=(90, 110, 170))
save(k, "hollow_king.png")

gu = new(72, 72)
d = ImageDraw.Draw(gu)
d.ellipse([10, 10, 62, 62], outline=(180, 160, 90), width=4)
d.ellipse([22, 22, 50, 50], fill=(60, 55, 40))
d.point((30, 34), fill=(255, 220, 80)); d.point((42, 34), fill=(255, 220, 80))
d.arc([26, 38, 46, 50], 0, 180, fill=(255, 220, 80))
for ang in range(0, 360, 45):
    x = 36 + int(30 * math.cos(math.radians(ang)))
    y = 36 + int(30 * math.sin(math.radians(ang)))
    d.rectangle([x - 3, y - 3, x + 3, y + 3], fill=(180, 160, 90))
save(gu, "guardian.png")

def mushy(cap, spot, name, angry=False):
    m = new(32, 32)
    d = ImageDraw.Draw(m)
    d.ellipse([4, 6, 28, 24], fill=cap)
    d.rectangle([10, 20, 22, 28], fill=(230, 220, 200))
    for (x, y) in [(10, 12), (18, 10), (22, 16)]:
        d.ellipse([x, y, x + 4, y + 4], fill=spot)
    ey = 22 if angry else 23
    d.point((13, ey), fill=(40, 40, 40)); d.point((19, ey), fill=(40, 40, 40))
    if angry:
        d.line([(11, 20), (15, 22)], fill=(40, 40, 40)); d.line([(21, 20), (17, 22)], fill=(40, 40, 40))
    save(m, name)
mushy((200, 90, 90), (250, 220, 220), "shroomu.png")
mushy((90, 140, 200), (220, 240, 255), "froggit_blue.png", True)

def bat(name):
    b = new(36, 24)
    d = ImageDraw.Draw(b)
    d.ellipse([14, 6, 22, 16], fill=(90, 70, 110))
    d.polygon([(14, 8), (2, 2), (6, 14), (14, 14)], fill=(70, 55, 90))
    d.polygon([(22, 8), (34, 2), (30, 14), (22, 14)], fill=(70, 55, 90))
    d.point((16, 10), fill=(255, 80, 80)); d.point((20, 10), fill=(255, 80, 80))
    d.polygon([(15, 4), (16, 8), (18, 5)], fill=(90, 70, 110))
    d.polygon([(18, 5), (20, 8), (21, 4)], fill=(90, 70, 110))
    save(b, name)
bat("batty.png")

def snail(name):
    s = new(36, 28)
    d = ImageDraw.Draw(s)
    d.ellipse([4, 14, 30, 26], fill=(180, 150, 110))
    d.ellipse([10, 4, 28, 20], fill=(140, 100, 70))
    d.ellipse([14, 8, 24, 16], fill=(170, 130, 90))
    d.line([(8, 16), (4, 8)], fill=(180, 150, 110), width=2)
    d.point((4, 7), fill=(40, 40, 40))
    d.point((7, 20), fill=(60, 50, 40))
    save(s, name)
snail("snaily.png")

def ghost(name):
    g2 = new(32, 36)
    d = ImageDraw.Draw(g2)
    col = (220, 220, 240, 200)
    d.ellipse([6, 4, 26, 24], fill=col)
    d.polygon([(6, 20), (10, 32), (14, 22), (18, 32), (22, 22), (26, 32), (26, 20)], fill=col)
    d.point((12, 12), fill=(60, 60, 90)); d.point((20, 12), fill=(60, 60, 90))
    d.ellipse([14, 16, 18, 20], fill=(60, 60, 90))
    save(g2, name)
ghost("whisp.png")

def crystal_crab(name):
    cr = new(40, 28)
    d = ImageDraw.Draw(cr)
    d.polygon([(8, 18), (14, 6), (26, 6), (32, 18)], fill=(120, 200, 220))
    d.polygon([(14, 6), (20, 0), (26, 6)], fill=(180, 240, 255))
    for x in (6, 34):
        d.line([(x, 18), (x + (-4 if x < 20 else 4), 24)], fill=(90, 160, 190), width=3)
    d.point((16, 12), fill=(30, 30, 60)); d.point((24, 12), fill=(30, 30, 60))
    d.polygon([(2, 12), (8, 10), (6, 16)], fill=(90, 160, 190))
    d.polygon([(38, 12), (32, 10), (34, 16)], fill=(90, 160, 190))
    save(cr, name)
crystal_crab("crabbly.png")

im = new(32, 24)
d = ImageDraw.Draw(im)
d.ellipse([8, 8, 24, 20], fill=(150, 80, 50))
d.polygon([(24, 12), (31, 8), (28, 16)], fill=(120, 60, 40))
glow_circle(im, 12, 6, 3, (255, 140, 60), 60)
d.point((12, 12), fill=(255, 220, 100)); d.point((18, 12), fill=(255, 220, 100))
save(im, "cinder.png")

ge = new(32, 32)
d = ImageDraw.Draw(ge)
d.ellipse([8, 8, 24, 24], fill=(140, 150, 170))
d.ellipse([12, 12, 20, 20], fill=(70, 80, 100))
for ang in range(0, 360, 60):
    x = 16 + int(12 * math.cos(math.radians(ang)))
    y = 16 + int(12 * math.sin(math.radians(ang)))
    d.rectangle([x - 3, y - 3, x + 3, y + 3], fill=(140, 150, 170))
d.point((14, 15), fill=(255, 100, 100)); d.point((19, 15), fill=(255, 100, 100))
save(ge, "cogling.png")

v = new(32, 40)
d = ImageDraw.Draw(v)
d.line([(16, 38), (16, 12)], fill=(70, 130, 70), width=4)
d.ellipse([8, 2, 24, 18], fill=(90, 160, 90))
d.polygon([(8, 20), (2, 26), (10, 24)], fill=(70, 130, 70))
d.polygon([(24, 20), (30, 26), (22, 24)], fill=(70, 130, 70))
d.point((13, 9), fill=(230, 255, 150)); d.point((19, 9), fill=(230, 255, 150))
save(v, "sprig.png")

f = new(40, 32)
d = ImageDraw.Draw(f)
d.ellipse([10, 12, 30, 28], fill=(170, 210, 240))
d.polygon([(12, 14), (8, 4), (18, 12)], fill=(170, 210, 240))
d.polygon([(28, 14), (32, 4), (22, 12)], fill=(170, 210, 240))
d.polygon([(30, 20), (39, 24), (30, 26)], fill=(140, 180, 220))
d.point((16, 18), fill=(40, 60, 100)); d.point((24, 18), fill=(40, 60, 100))
save(f, "frostfox.png")

w = new(48, 36)
d = ImageDraw.Draw(w)
d.ellipse([12, 12, 38, 30], fill=(50, 45, 70))
d.polygon([(14, 14), (10, 4), (22, 12)], fill=(50, 45, 70))
d.polygon([(34, 14), (38, 4), (28, 12)], fill=(50, 45, 70))
d.polygon([(38, 20), (47, 16), (40, 26)], fill=(40, 36, 60))
d.point((20, 18), fill=(255, 60, 60)); d.point((30, 18), fill=(255, 60, 60))
save(w, "shadowhound.png")

def npc_mushroom_villager(name, col):
    m = new(28, 32)
    d = ImageDraw.Draw(m)
    d.ellipse([2, 2, 26, 18], fill=col)
    d.ellipse([8, 12, 20, 28], fill=(235, 225, 205))
    d.point((11, 20), fill=(40, 40, 40)); d.point((17, 20), fill=(40, 40, 40))
    d.arc([11, 22, 17, 26], 0, 180, fill=(40, 40, 40))
    for (x, y) in [(8, 6), (16, 4), (20, 10)]:
        d.ellipse([x, y, x + 4, y + 4], fill=(255, 255, 255, 200))
    save(m, name)
npc_mushroom_villager("villager_red.png", (200, 80, 80))
npc_mushroom_villager("villager_blue.png", (80, 110, 200))
npc_mushroom_villager("mira.png", (200, 120, 220))

sr = new(48, 48)
d = ImageDraw.Draw(sr)
d.ellipse([4, 4, 44, 28], fill=(120, 90, 60))
d.rectangle([16, 24, 32, 44], fill=(220, 205, 180))
d.point((21, 32), fill=(60, 45, 30)); d.point((27, 32), fill=(60, 45, 30))
d.line([(18, 38), (30, 38)], fill=(60, 45, 30))
d.arc([6, 8, 20, 20], 0, 360, fill=(90, 65, 40))
save(sr, "old_root.png")

wr = new(36, 40)
d = ImageDraw.Draw(wr)
d.ellipse([10, 4, 26, 18], fill=(150, 100, 160))
d.polygon([(10, 8), (2, 2), (12, 14)], fill=(150, 100, 160))
d.polygon([(26, 8), (34, 2), (24, 14)], fill=(150, 100, 160))
d.polygon([(18, 16), (8, 36), (28, 36)], fill=(90, 60, 110))
d.point((15, 10), fill=(255, 230, 100)); d.point((21, 10), fill=(255, 230, 100))
save(wr, "wren.png")

asp = make_human((230, 230, 230), (240, 240, 250))
overlay = Image.new("RGBA", asp.size, (255, 255, 255, 60))
asp = Image.alpha_composite(asp, overlay)
save(asp, "asriel_ghost.png")

# ---------------- Предметы 16x16 ----------------
def item_draw(name, fn):
    it = new(16, 16)
    fn(ImageDraw.Draw(it))
    save(it, name)

item_draw("item_cider.png", lambda d: (d.rectangle([4, 3, 12, 14], fill=(180, 100, 60)), d.rectangle([4, 2, 12, 4], fill=(220, 220, 220))))
item_draw("item_mushroom_pie.png", lambda d: (d.ellipse([2, 6, 14, 14], fill=(200, 160, 90)), d.rectangle([2, 4, 14, 8], fill=(230, 200, 120)), d.point((6, 6), fill=(150, 60, 60)), d.point((10, 5), fill=(150, 60, 60))))
item_draw("item_star_candy.png", lambda d: d.polygon([(8, 1), (10, 6), (15, 6), (11, 9), (13, 15), (8, 11), (3, 15), (5, 9), (1, 6), (6, 6)], fill=(255, 240, 120)))
item_draw("item_watch.png", lambda d: (d.ellipse([3, 3, 13, 13], fill=(200, 200, 210)), d.ellipse([5, 5, 11, 11], fill=(250, 250, 250)), d.line([(8, 8), (8, 5)], fill=(40, 40, 40)), d.line([(8, 8), (11, 9)], fill=(40, 40, 40))))
item_draw("item_scarf.png", lambda d: (d.rectangle([2, 4, 14, 8], fill=(220, 60, 60)), d.rectangle([4, 8, 8, 14], fill=(220, 60, 60)), d.line([(2, 6), (14, 6)], fill=(250, 150, 150))))
item_draw("item_butter.png", lambda d: (d.rectangle([3, 6, 13, 12], fill=(250, 220, 120)), d.rectangle([3, 6, 13, 8], fill=(255, 240, 180))))
item_draw("item_ramen.png", lambda d: (d.rectangle([4, 4, 12, 13], fill=(230, 230, 240)), d.polygon([(8, 1), (5, 5), (11, 5)], fill=(220, 80, 80)), d.rectangle([6, 13, 10, 15], fill=(250, 160, 60))))
item_draw("item_photograph.png", lambda d: (d.rectangle([2, 3, 14, 13], fill=(240, 240, 240)), d.rectangle([4, 5, 12, 11], fill=(120, 150, 180)), d.point((7, 8), fill=(240, 200, 160)), d.point((10, 8), fill=(200, 220, 240))))
item_draw("item_artifact.png", lambda d: (d.polygon([(8, 0), (13, 8), (8, 16), (3, 8)], fill=(160, 220, 255)), d.polygon([(8, 3), (11, 8), (8, 13), (5, 8)], fill=(230, 250, 255))))
item_draw("item_shard.png", lambda d: (d.polygon([(4, 1), (12, 5), (9, 15), (2, 10)], fill=(200, 160, 255)), d.line([(4, 1), (9, 15)], fill=(240, 220, 255))))
item_draw("item_rope.png", lambda d: (d.arc([2, 2, 14, 14], 0, 360, fill=(180, 150, 90)), d.arc([4, 4, 12, 12], 0, 360, fill=(200, 170, 110))))
item_draw("item_note.png", lambda d: (d.rectangle([3, 2, 13, 14], fill=(235, 230, 200)), d.line([(5, 5), (11, 5)], fill=(120, 110, 90)), d.line([(5, 8), (11, 8)], fill=(120, 110, 90)), d.line([(5, 11), (9, 11)], fill=(120, 110, 90))))
item_draw("item_donut.png", lambda d: (d.ellipse([1, 3, 15, 13], fill=(200, 120, 160)), d.ellipse([6, 6, 10, 10], fill=(0, 0, 0)), d.line([(3, 5), (4, 4)], fill=(255, 255, 255)), d.line([(11, 9), (12, 8)], fill=(255, 255, 255))))
item_draw("coin.png", lambda d: (d.ellipse([2, 2, 14, 14], fill=(240, 200, 80)), d.ellipse([4, 4, 12, 12], outline=(180, 140, 40))))

p = new(8, 8); d = ImageDraw.Draw(p)
d.ellipse([0, 0, 7, 7], fill=(255, 255, 255)); d.ellipse([2, 2, 5, 5], fill=(255, 220, 120))
save(p, "bullet_white.png")
p = new(10, 10); d = ImageDraw.Draw(p)
d.polygon([(5, 0), (10, 5), (5, 10), (0, 5)], fill=(160, 220, 255))
save(p, "bullet_diamond.png")
p = new(12, 6); d = ImageDraw.Draw(p)
d.rectangle([0, 0, 11, 5], fill=(120, 255, 120)); d.point((2, 2), fill=(20, 60, 20)); d.point((8, 2), fill=(20, 60, 20))
save(p, "bullet_leaf.png")
p = new(8, 12); d = ImageDraw.Draw(p)
d.polygon([(4, 0), (8, 6), (4, 12), (0, 6)], fill=(200, 240, 255))
save(p, "bullet_icicle.png")
p = new(10, 10); d = ImageDraw.Draw(p)
d.ellipse([1, 1, 9, 9], fill=(255, 120, 60)); d.ellipse([3, 3, 7, 7], fill=(255, 220, 80))
save(p, "bullet_ember.png")
p = new(10, 10); d = ImageDraw.Draw(p)
d.line([(0, 0), (10, 10)], fill=(200, 80, 220), width=2); d.line([(10, 0), (0, 10)], fill=(200, 80, 220), width=2)
save(p, "bullet_gear.png")

sv = new(24, 28)
d = ImageDraw.Draw(sv)
d.line([(12, 14), (12, 27)], fill=(80, 160, 80), width=2)
for ang in range(0, 360, 60):
    x = 12 + int(8 * math.cos(math.radians(ang))); y = 10 + int(8 * math.sin(math.radians(ang)))
    d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=(255, 240, 120))
d.ellipse([8, 6, 16, 14], fill=(255, 200, 60))
save(sv, "save_flower.png")

tp = new(24, 28)
d = ImageDraw.Draw(tp)
d.rectangle([10, 14, 14, 27], fill=(120, 90, 60))
d.ellipse([2, 2, 22, 20], fill=(100, 60, 160))
d.ellipse([6, 6, 18, 16], fill=(180, 120, 255))
save(tp, "teleport_marker.png")

dr = new(32, 48)
d = ImageDraw.Draw(dr)
d.rectangle([2, 2, 30, 47], fill=(90, 60, 40))
d.rectangle([6, 6, 26, 47], fill=(140, 100, 60))
d.ellipse([20, 24, 24, 28], fill=(240, 220, 100))
save(dr, "door.png")

save(heart((255, 40, 40)), "heart_ui.png")

print("DONE ->", os.path.abspath(OUT), "| files:", len(os.listdir(OUT)))
