#!/usr/bin/env python3
"""Generates assets/seed.json (demo users, posts, comments, notifications).
Run:  python3 tools/gen_seed.py
"""
import json, os, random

random.seed(2026)
NAMES = ["Aria Moon", "Leo Park", "Maya Cruz", "Noah Reed", "Zara Khan", "Eli Stone",
         "Luna Vega", "Kai Tanaka", "Ivy Brooks", "Omar Hale", "Nina Fox", "Theo Grant",
         "Sana Ali", "Jude Rivers"]
BIOS = ["Designer & coffee addict", "Building things at night", "Photos, music, repeat",
        "Dev. Dreamer. Dog person.", "Chasing sunsets", "Minimalist | Reader",
        "Gym, code, sleep", "Making tiny apps", "Travel notes", "Plants and playlists"]
TAGS = ["intly", "design", "flutter", "morning", "music", "travel", "coffee", "code",
        "photo", "fitness", "books", "nightowl"]
TEXTS = [
    "Just shipped something small but it feels great #{t}",
    "Golden hour hits different today #{t} #{u}",
    "Hot take: simple apps win every time #{t}",
    "Who else is up this late? #{t}",
    "Tried a new routine this week and it actually works #{t}",
    "Found a hidden gem in my city today #{t} #{u}",
    "Sunday reset: clean desk, clear mind #{t}",
    "Learning something new every single day #{t}",
    "This playlist is on repeat #{t}",
    "Small steps still count #{t} #{u}",
    "Coffee first, everything else later #{t}",
    "Made something with my own hands today #{t}",
]
COMMENTS = ["Love this!", "So true", "Needed this today", "Haha same", "This is awesome",
            "Great shot!", "Following for more", "Can you share more?", "Facts", "Beautiful"]

users = []
for i, n in enumerate(NAMES):
    users.append({"id": f"u{i+1}", "name": n, "handle": n.lower().replace(" ", "."),
                  "bio": random.choice(BIOS), "hue": random.randint(0, 359),
                  "followers": random.randint(120, 9800), "following": random.randint(40, 900)})

REPLIES = ["Thank you!", "Appreciate it", "Glad you liked it", "Haha right?", "Exactly!", "Thanks for stopping by"]
posts, comments = [], []
cid = 0
minutes = 3
for i in range(60):
    minutes += random.choice([4, 9, 17, 35, 60, 120, 240])
    t, u = random.sample(TAGS, 2)
    p = {"id": f"p{i+1}", "user": random.choice(users)["id"],
         "text": random.choice(TEXTS).format(t=t, u=u), "minutes": minutes,
         "media": random.randint(0, 40) if random.random() < 0.45 else -1,
         "likes": random.randint(2, 900), "shares": random.randint(0, 120)}
    cs = random.sample(COMMENTS, random.randint(0, 4))
    n = 0
    for c in cs:
        cid += 1
        top = {"id": f"c{cid}", "post": p["id"], "user": random.choice(users)["id"],
               "text": c, "minutes": random.randint(30, 600), "parent": None}
        comments.append(top); n += 1
        if random.random() < 0.5:
            cid += 1
            who = p["user"] if random.random() < 0.6 else random.choice(users)["id"]
            comments.append({"id": f"c{cid}", "post": p["id"], "user": who,
                             "text": random.choice(REPLIES),
                             "minutes": max(1, top["minutes"] - random.randint(5, 25)),
                             "parent": top["id"]}); n += 1
    p["comments"] = n + random.randint(0, 30)
    posts.append(p)

NT = [("like", "liked your post"), ("follow", "started following you"),
      ("comment", "commented: Love this!"), ("mention", "mentioned you in a post"),
      ("like", "liked your post"), ("comment", "commented: So true")]
notifs = []
m = 2
for i in range(18):
    k, txt = random.choice(NT)
    m += random.choice([5, 14, 40, 90, 300])
    n = {"type": k, "user": random.choice(users)["id"], "text": txt, "minutes": m}
    if k != "follow":
        # every non-follow notification points at a real post (opens it when tapped)
        target = random.choice([x for x in posts if x["minutes"] > m] or posts)
        n["post"] = target["id"]
        if k == "comment":
            # ...and a comment notification points at a real comment in that post,
            # so the app can scroll to it and highlight it
            cid += 1
            comments.append({"id": f"c{cid}", "post": target["id"], "user": n["user"],
                             "text": txt.split(": ", 1)[1], "minutes": m, "parent": None})
            target["comments"] += 1
            n["comment"] = f"c{cid}"
    notifs.append(n)

os.makedirs("assets", exist_ok=True)
with open("assets/seed.json", "w", encoding="utf-8") as f:
    json.dump({"users": users, "posts": posts, "comments": comments, "notifs": notifs},
              f, ensure_ascii=False, separators=(",", ":"))
print(f"seed.json: {len(users)} users, {len(posts)} posts, {len(comments)} comments, {len(notifs)} notifs")
