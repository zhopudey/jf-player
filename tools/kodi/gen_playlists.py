#!/usr/bin/env python3
"""Generate Kodi smart playlists (language x genre) from the live Kodi library.

Language = the Jellyfin library tag the add-on syncs onto every item (movies-hindi, tv-english, ...).
Reads Kodi over JSON-RPC, writes XML into --out. Deploy step is separate (scp to
/storage/.kodi/userdata/playlists/video/). Password comes from KODI_PASS, never from the file.

  KODI_PASS='...' ./gen_playlists.py --host 10.0.10.124 --out ./out [--min 3]
"""
import argparse, collections, json, os, re, urllib.request, base64
from xml.sax.saxutils import escape

p = argparse.ArgumentParser()
p.add_argument("--host", default="10.0.10.124")
p.add_argument("--port", type=int, default=8080)
p.add_argument("--user", default="kodi")
p.add_argument("--out", required=True)
p.add_argument("--min", type=int, default=3, help="skip language x genre combos with fewer titles")
a = p.parse_args()

def rpc(method, params):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    r = urllib.request.Request(f"http://{a.host}:{a.port}/jsonrpc", body, {"Content-Type": "application/json"})
    tok = base64.b64encode(f"{a.user}:{os.environ['KODI_PASS']}".encode()).decode()
    r.add_header("Authorization", "Basic " + tok)
    return json.load(urllib.request.urlopen(r, timeout=30))["result"]

LIB = re.compile(r"^(movies|tv)-(.+)$", re.I)
KINDS = {"movies": ("movies", "VideoLibrary.GetMovies", "movies"),
         "tv": ("tvshows", "VideoLibrary.GetTVShows", "tvshows")}

def xml(ptype, name, rules):
    rs = "".join(f'<rule field="{f}" operator="is"><value>{escape(v)}</value></rule>' for f, v in rules)
    return (f'<?xml version="1.0" encoding="UTF-8"?>\n<smartplaylist type="{ptype}">\n'
            f'<name>{escape(name)}</name><match>all</match>{rs}'
            f'<order direction="ascending">sorttitle</order></smartplaylist>\n')

os.makedirs(a.out, exist_ok=True)
written = []
def put(fname, ptype, name, rules):
    open(os.path.join(a.out, fname), "w").write(xml(ptype, name, rules)); written.append(fname)

for kind, (ptype, method, key) in KINDS.items():
    items = rpc(method, {"properties": ["genre", "tag"], "limits": {"start": 0, "end": 100000}}).get(key, [])
    langs = collections.defaultdict(list)
    for it in items:
        for t in it.get("tag", []):
            m = LIB.match(t)
            if m and m.group(1).lower() == kind:
                langs[t].append(it)
    for tag, its in sorted(langs.items()):
        lang = LIB.match(tag).group(2).title()
        label = f"{'Movies' if kind == 'movies' else 'TV'} {lang}"
        put(f"{kind}-{lang.lower()}.xsp", ptype, label, [("tag", tag)])
        gc = collections.Counter(g for it in its for g in it.get("genre", []))
        for g, n in sorted(gc.items()):
            if n >= a.min:
                put(f"{kind}-{lang.lower()}--{g.lower().replace(' ', '-')}.xsp", ptype, f"{label}: {g}",
                    [("tag", tag), ("genre", g)])
    allg = collections.Counter(g for it in items for g in it.get("genre", []))
    for g, n in sorted(allg.items()):
        if n >= a.min:
            put(f"{kind}-all--{g.lower().replace(' ', '-')}.xsp", ptype,
                f"{'Movies' if kind == 'movies' else 'TV'}: {g}", [("genre", g)])
print(f"{len(written)} playlists -> {a.out}")
