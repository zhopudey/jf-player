#!/usr/bin/env python3
"""Smart playlists behind the Kodi UI (UI_SPEC.md): language groups, picks, animated.

Language = TMDb original language from the kodi-tracks list (tracks.json, keyed by Jellyfin item id;
Kodi's file URL carries the same id). A smart playlist cannot filter on language, so language
groups are title lists. Everything else is a plain rule playlist.

  KODI_PASS=... ./gen_ui_playlists.py --host 10.0.10.40 --port 8596 --tracks tracks.json --out ./ui
Deploy: copy --out to userdata/playlists/video/ui/ on the Kodi box.
"""
import argparse, base64, collections, json, os, re, urllib.request
from xml.sax.saxutils import escape

p = argparse.ArgumentParser()
p.add_argument("--host", default="10.0.10.124")
p.add_argument("--port", type=int, default=8080)
p.add_argument("--user", default="kodi")
p.add_argument("--tracks", required=True)
p.add_argument("--out", required=True)
a = p.parse_args()

def rpc(method, params):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    r = urllib.request.Request(f"http://{a.host}:{a.port}/jsonrpc", body, {"Content-Type": "application/json"})
    r.add_header("Authorization", "Basic " + base64.b64encode(f"{a.user}:{os.environ['KODI_PASS']}".encode()).decode())
    return json.load(urllib.request.urlopen(r, timeout=60))["result"]

INDIAN = {"mr", "ta", "te", "ml", "kn", "bn", "pa", "gu", "or", "as"}
def group(lang):
    if lang == "en": return "english"
    if lang == "hi": return "hindi"
    if lang in INDIAN: return "indian"
    return "foreign"

ANIM = "movies-animated"
NOT_ANIM = ('tag', 'isnot', [ANIM])

def rule(field, op, vals):
    v = "".join(f"<value>{escape(x)}</value>" for x in vals)
    return f'<rule field="{field}" operator="{op}">{v}</rule>'

def xsp(name, rules, order=("sorttitle", "ascending"), limit=None, group_by=None, match="all"):
    s = f'<?xml version="1.0" encoding="UTF-8"?>\n<smartplaylist type="movies">\n<name>{escape(name)}</name><match>{match}</match>'
    s += "".join(rule(*r) for r in rules)
    if group_by: s += f"<group>{group_by}</group>"
    if limit: s += f"<limit>{limit}</limit>"
    s += f'<order direction="{order[1]}">{order[0]}</order></smartplaylist>\n'
    return s

tracks = json.load(open(a.tracks))
movies = rpc("VideoLibrary.GetMovies", {"properties": ["file", "tag"], "limits": {"start": 0, "end": 100000}})["movies"]
groups, missing = collections.defaultdict(set), []
for m in movies:
    if ANIM in m["tag"]: continue
    jid = re.search(r"[?&]id=([0-9a-f]{32})", m["file"])
    t = tracks.get(jid.group(1)) if jid else None
    if not t or not t.get("orig"):
        missing.append(m["label"]); continue
    groups[group(t["orig"])].add(m["label"])

os.makedirs(a.out, exist_ok=True)
files = {
    "movies-all.xsp": xsp("All movies", [NOT_ANIM], group_by="genres"),
    "movies-continue.xsp": xsp("Continue watching", [("inprogress", "true", []), NOT_ANIM], order=("lastplayed", "descending")),
    "movies-toprated-unwatched.xsp": xsp("Top rated, unwatched", [("playcount", "is", ["0"]), ("rating", "greaterthan", ["7"]), NOT_ANIM], order=("rating", "descending"), limit=40),
    "movies-under-2h.xsp": xsp("Under 2 hours", [("time", "lessthan", ["02:00:00"]), ("playcount", "is", ["0"]), NOT_ANIM], order=("rating", "descending")),
    "movies-new.xsp": xsp("Added this month", [("dateadded", "inthelast", ["30 days"]), NOT_ANIM], order=("dateadded", "descending")),
    "movies-random.xsp": xsp("10 random picks", [("playcount", "is", ["0"]), NOT_ANIM], order=("random", "ascending"), limit=10),
    "animated-all.xsp": xsp("Animated", [("tag", "is", [ANIM])]),   # 84 films: straight to the wall
    "animated-continue.xsp": xsp("Animated: continue", [("inprogress", "true", []), ("tag", "is", [ANIM])], order=("lastplayed", "descending")),
    "animated-random.xsp": xsp("Animated: random picks", [("playcount", "is", ["0"]), ("tag", "is", [ANIM])], order=("random", "ascending"), limit=15),
}
NAMES = {"english": "English", "hindi": "Hindi", "indian": "Indian", "foreign": "Foreign"}
for g, titles in groups.items():
    files[f"movies-{g}.xsp"] = xsp(NAMES[g], [("title", "is", sorted(titles))], group_by="genres")
for f, body in files.items():
    open(os.path.join(a.out, f), "w").write(body)
print({g: len(t) for g, t in sorted(groups.items())}, "| no language:", len(missing), missing[:10])
print("wrote", len(files), "playlists to", a.out)
