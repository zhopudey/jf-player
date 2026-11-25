#!/usr/bin/env python3
"""Build the Kodi track list: for every Jellyfin film/episode, which audio track and which subtitle to use.

Rule (Rohan 2026-11-25): audio = the title's ORIGINAL language (TMDb original_language); subs = English, full
(not forced, not SDH when there is a choice), always on. Jellyfin has already probed every file, so no ffprobe.

Reads Jellyfin (/Items with MediaStreams + ProviderIds) and TMDb. Writes into --out:
  tracks.json      {jellyfin_item_id: {...}}   read by the Kodi service script (Kodi's plugin:// URL carries id=<item id>)
  unresolved.txt   one readable line per title it could not resolve, with the reason
  status.json      last run, counts (the "I ain't dead" line)
Default run is incremental: items changed since the last run + every unresolved item (streams and TMDb ids can land
after an item is added). --full does everything (weekly safety net).

Keys: ~/.config/kodi-tracks/jellyfin.key and tmdb.key (or env JF_KEY / TMDB_KEY). Jellyfin 12 needs the
`Authorization: MediaBrowser Token=` header form.

  ./track_list.py --out ./out [--full] [--jellyfin http://10.0.10.40:8096]
"""
import argparse, urllib.error, datetime, json, os, sys, time, urllib.parse, urllib.request

p = argparse.ArgumentParser()
p.add_argument("--out", required=True)
p.add_argument("--jellyfin", default="http://10.0.10.40:8096")
p.add_argument("--full", action="store_true")
a = p.parse_args()

def key(env, fname):
    if os.environ.get(env):
        return os.environ[env].strip()
    return open(os.path.expanduser("~/.config/kodi-tracks/" + fname)).read().strip()

JF = key("JF_KEY", "jellyfin.key")
TM = key("TMDB_KEY", "tmdb.key")

def jf(path, **q):
    url = a.jellyfin + path + ("?" + urllib.parse.urlencode(q) if q else "")
    r = urllib.request.Request(url, headers={"Authorization": f'MediaBrowser Token="{JF}"'})
    return json.load(urllib.request.urlopen(r, timeout=60))

def tmdb(kind, tid):
    url = f"https://api.themoviedb.org/3/{kind}/{tid}?api_key={TM}"
    for wait in (1, 3, 8, 20):  # TMDb resets connections under bursts: back off and retry
        try:
            return json.load(urllib.request.urlopen(url, timeout=20)).get("original_language")
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            time.sleep(wait)
        except OSError:
            time.sleep(wait)
    raise RuntimeError("TMDb unreachable")

# TMDb (ISO 639-1) -> the 3-letter codes Jellyfin may carry (both B and T variants)
L3 = {"en": {"eng"}, "hi": {"hin"}, "mr": {"mar"}, "te": {"tel"}, "ta": {"tam"}, "ml": {"mal"}, "kn": {"kan"},
      "bn": {"ben"}, "pa": {"pan"}, "gu": {"guj"}, "ur": {"urd"}, "ja": {"jpn"}, "ko": {"kor"},
      "zh": {"chi", "zho", "cmn"}, "cn": {"yue", "chi", "zho"}, "fr": {"fre", "fra"}, "de": {"ger", "deu"},
      "es": {"spa"}, "it": {"ita"}, "pt": {"por"}, "ru": {"rus"}, "tr": {"tur"}, "ar": {"ara"}, "th": {"tha"},
      "sv": {"swe"}, "da": {"dan"}, "no": {"nor", "nob"}, "nb": {"nob", "nor"}, "fi": {"fin"}, "nl": {"dut", "nld"},
      "pl": {"pol"}, "cs": {"cze", "ces"}, "el": {"gre", "ell"}, "he": {"heb"}, "fa": {"per", "fas"},
      "id": {"ind"}, "vi": {"vie"}, "uk": {"ukr"}, "hu": {"hun"}, "ro": {"rum", "ron"}, "is": {"ice", "isl"}}

os.makedirs(a.out, exist_ok=True)
TP, UP, SP = (os.path.join(a.out, n) for n in ("tracks.json", "unresolved.txt", "status.json"))
tracks = json.load(open(TP)) if os.path.exists(TP) else {}
status = json.load(open(SP)) if os.path.exists(SP) else {}
langcache = status.get("tmdb_lang", {})  # "movie:894803" -> "te"; original language never changes

t0 = time.time()
FIELDS = "MediaStreams,ProviderIds,Path,SeriesId,ProductionYear"
q = dict(Recursive="true", IncludeItemTypes="Movie,Episode", Fields=FIELDS)
since = status.get("last_run_utc")
items = {}
if a.full or not since:
    for it in jf("/Items", **q)["Items"]:
        items[it["Id"]] = it
else:
    # a little overlap so a run that raced a library write still sees it
    ms = (datetime.datetime.fromisoformat(since) - datetime.timedelta(minutes=10)).strftime("%Y-%m-%dT%H:%M:%SZ")
    for it in jf("/Items", MinDateLastSaved=ms, **q)["Items"]:
        items[it["Id"]] = it
    retry = [i for i, t in tracks.items() if t["status"] != "ok"]
    for i in range(0, len(retry), 50):
        for it in jf("/Items", Ids=",".join(retry[i:i + 50]), Fields=FIELDS)["Items"]:
            items[it["Id"]] = it

series_tmdb = {}
def series_id(sid):
    if sid not in series_tmdb:
        series_tmdb[sid] = jf("/Items", Ids=sid, Fields="ProviderIds")["Items"][0].get("ProviderIds", {}).get("Tmdb")
    return series_tmdb[sid]

def orig_lang(it):
    kind, tid = ("movie", (it.get("ProviderIds") or {}).get("Tmdb")) if it["Type"] == "Movie" else ("tv", series_id(it.get("SeriesId")))
    if not tid:
        return None, None
    k = f"{kind}:{tid}"
    if k not in langcache:
        langcache[k] = tmdb(kind, tid)
    return langcache[k], tid

def nth(streams, s):
    """Ordinal of stream s among streams of the same type and language (Kodi lists them in this order)."""
    same = [x for x in streams if x["Type"] == s["Type"] and (x.get("Language") or "und") == (s.get("Language") or "und")]
    return same.index(s)

def pick(it):
    st = it.get("MediaStreams") or []
    aud = [s for s in st if s["Type"] == "Audio"]
    sub = [s for s in st if s["Type"] == "Subtitle"]
    if not aud:
        return dict(status="no_probe", why="Jellyfin has no stream info yet")
    lang, tid = orig_lang(it)
    if not tid:
        return dict(status="no_tmdb", why="no TMDb id on the item")
    if not lang or lang not in L3:
        return dict(status="unknown_lang", why=f"TMDb original_language {lang!r} not in the language table", orig=lang)
    want = L3[lang]
    cand = [s for s in aud if (s.get("Language") or "und").lower() in want]
    cand = [s for s in cand if "commentary" not in (s.get("Title") or "").lower()] or cand
    out = dict(orig=lang, tmdb=tid)
    if not cand and len(aud) == 1:  # only one track: nothing to choose, and it may just be mislabelled ("und", "eng")
        cand = aud
    if not cand:
        have = ",".join(sorted({(s.get("Language") or "und") for s in aud}))
        return dict(out, status="no_orig_track", why=f"original is {lang}, file has audio: {have}")
    best = max(cand, key=lambda s: (bool(s.get("IsDefault")), s.get("Channels") or 0))
    out["audio"] = dict(lang=best.get("Language"), nth=nth(st, best), title=best.get("Title"), codec=best.get("Codec"))
    eng = [s for s in sub if (s.get("Language") or "").lower() in ("eng", "en")]
    full = [s for s in eng if not s.get("IsForced")]
    nosdh = [s for s in full if not any(w in ((s.get("Title") or "") + (s.get("DisplayTitle") or "")).lower() for w in ("sdh", "hearing", "cc"))]
    s = (nosdh or full or [None])[0]
    if s:
        out["sub"] = dict(lang="eng", nth=nth(st, s), title=s.get("Title"), external=bool(s.get("IsExternal")))
        out["status"] = "ok"
    else:
        out.update(status="no_eng_sub", why="no full English subtitle (audio is resolved)")
    return out

n_ok = 0
for i, (iid, it) in enumerate(items.items(), 1):
    name = it["Name"] + (f" ({it['ProductionYear']})" if it.get("ProductionYear") else "")
    if it["Type"] == "Episode":
        name = f"{it.get('SeriesName', '?')} - {name}"
    try:
        r = pick(it)
    except Exception as e:  # one bad item must not stop the run
        r = dict(status="error", why=str(e)[:100])
    r.update(name=name, path=it.get("Path"))
    tracks[iid] = r
    n_ok += r["status"] == "ok"
    if i % 50 == 0:
        print(f"  {i}/{len(items)} checked", flush=True)

# drop items Jellyfin no longer has (full run only: we saw everything)
if a.full or not since:
    for gone in set(tracks) - set(items):
        del tracks[gone]

json.dump(tracks, open(TP, "w"), indent=1, ensure_ascii=False)
bad = sorted((t for t in tracks.values() if t["status"] != "ok"), key=lambda t: (t["status"], t["name"]))
with open(UP, "w") as f:
    for t in bad:
        f.write(f"{t['status']:14} {t['name']}  -- {t.get('why', '')}\n")
now = datetime.datetime.now(datetime.timezone.utc)
status = dict(last_run_utc=now.strftime("%Y-%m-%dT%H:%M:%S"), mode="full" if a.full or not since else "incremental",
              checked=len(items), total=len(tracks), ok=sum(t["status"] == "ok" for t in tracks.values()),
              unresolved=len(bad), seconds=round(time.time() - t0, 1), tmdb_lang=langcache)
json.dump(status, open(SP, "w"))
print(f"{status['mode']}: checked {len(items)}, total {status['total']}, ok {status['ok']}, unresolved {status['unresolved']} "
      f"({status['seconds']}s) -> {a.out}")
