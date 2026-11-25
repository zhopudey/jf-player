"""service.trackpicker: at playback start, select audio = original language, subtitles = English, from tracks.json.

tracks.json (Cinephage task "Kodi Track List") is keyed by Jellyfin item id; each entry has audio{lang,nth} and sub{lang,nth}
where nth = ordinal among streams of the same language (Kodi lists streams in the same order). No network at play time.
Missing item / no entry = leave Kodi's defaults. Every decision is logged to kodi.log ("[trackpicker] ...").
"""
import json, os, re
import xbmc, xbmcaddon, xbmcvfs

ADDON = xbmcaddon.Addon()
DATA = xbmcvfs.translatePath("special://profile/addon_data/service.trackpicker/")
TRACKS = os.path.join(DATA, "tracks.json")
GROUPS = [{"fre", "fra"}, {"ger", "deu"}, {"chi", "zho", "cmn", "yue"}, {"cze", "ces"}, {"dut", "nld"}, {"gre", "ell"},
          {"per", "fas"}, {"rum", "ron"}, {"ice", "isl"}, {"nor", "nob"}, {"eng", "en"}, {"und", ""}]
ID_RES = (re.compile(r"[?&]id=([0-9a-f]{32})"), re.compile(r"/Videos/([0-9a-f]{32})/"), re.compile(r"/Items/([0-9a-f]{32})/"))


def log(msg):
    xbmc.log("[trackpicker] " + msg, xbmc.LOGINFO)


def same_lang(a, b):
    a, b = (a or "und").lower(), (b or "und").lower()
    return a == b or any(a in g and b in g for g in GROUPS)


class Cache:
    mtime, data = None, {}

    @classmethod
    def get(cls):
        try:
            m = os.path.getmtime(TRACKS)
        except OSError:
            return {}
        if m != cls.mtime:
            try:
                with open(TRACKS, encoding="utf-8") as f:
                    cls.data, cls.mtime = json.load(f), m
            except (OSError, ValueError) as e:  # half-written or unreadable: keep what we had
                log("tracks.json unreadable: %s" % e)
        return cls.data


def rpc(method, **params):
    r = json.loads(xbmc.executeJSONRPC(json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params})))
    return r.get("result")


def item_id(player):
    cands = []
    for fn in (player.getPlayingFile, lambda: xbmc.getInfoLabel("Player.Filenameandpath"),
               lambda: player.getPlayingItem().getPath()):
        try:
            cands.append(fn() or "")
        except RuntimeError:
            pass
    for c in cands:
        for rx in ID_RES:
            m = rx.search(c)
            if m:
                return m.group(1)
    log("no Jellyfin id in %r" % cands)
    return None


def nth_match(streams, lang, nth):
    hits = [s for s in streams if same_lang(s.get("language"), lang)]
    if not hits:
        return None
    return hits[nth] if nth < len(hits) else hits[0]


class Picker(xbmc.Player):
    def onAVStarted(self):
        try:
            self.pick()
        except Exception as e:  # never break playback
            log("error: %r" % e)

    def pick(self):
        if not self.isPlayingVideo():
            return
        iid = item_id(self)
        entry = Cache.get().get(iid) if iid else None
        if not entry or not entry.get("audio"):
            log("%s: no entry, Kodi defaults" % iid)
            return
        pid = (rpc("Player.GetActivePlayers") or [{}])[0].get("playerid")
        if pid is None:
            return
        props = rpc("Player.GetProperties", playerid=pid,
                    properties=["audiostreams", "currentaudiostream", "subtitles", "currentsubtitle"]) or {}
        said = []
        a = entry["audio"]
        t = nth_match(props.get("audiostreams", []), a.get("lang"), a.get("nth", 0))
        if t is None:
            said.append("audio %s not found" % a.get("lang"))
        elif t["index"] != props.get("currentaudiostream", {}).get("index"):
            rpc("Player.SetAudioStream", playerid=pid, stream=t["index"])
            said.append("audio -> %s #%s" % (a.get("lang"), t["index"]))
        else:
            said.append("audio already %s" % a.get("lang"))
        s = entry.get("sub")
        if s:
            t = nth_match(props.get("subtitles", []), s.get("lang"), s.get("nth", 0))
            if t is None:
                said.append("sub %s not found" % s.get("lang"))
            else:
                rpc("Player.SetSubtitle", playerid=pid, subtitle=t["index"], enable=True)
                said.append("sub -> %s #%s" % (s.get("lang"), t["index"]))
        log("%s (%s): %s" % (iid, entry.get("name"), "; ".join(said)))


if __name__ == "__main__":
    xbmcvfs.mkdirs(DATA)
    picker = Picker()
    log("started")
    monitor = xbmc.Monitor()
    while not monitor.abortRequested():
        monitor.waitForAbort(60)
