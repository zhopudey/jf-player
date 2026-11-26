#!/usr/bin/env python3
"""Writes the SiLVO Home menu (script.skinshortcuts data) per UI_SPEC.md S1/S2/S8."""
import json
from xml.sax.saxutils import escape
PL="special://profile/playlists/video/ui/"
def sc(label, action, icon=""):
    return f"\t<shortcut>\n\t\t<label>{escape(label)}</label>\n\t\t<label2 />\n\t\t<icon>{icon}</icon>\n\t\t<thumb />\n\t\t<action>{escape(action)}</action>\n\t</shortcut>\n"
def menu(items): return '<?xml version="1.0" encoding="UTF-8"?>\n<shortcuts>\n'+"".join(sc(*i) for i in items)+"</shortcuts>\n"
I="special://skin/extras/icons/"
wall=lambda f:f"ActivateWindow(Videos,{PL}{f},return)"
files={
 "mainmenu.DATA.xml":menu([
  ("Movies",wall("movies-all.xsp"),I+"DefaultMovies.png"),
  ("Animated",wall("animated-all.xsp"),I+"DefaultMovies.png"),
  ("TV","ActivateWindow(Videos,videodb://tvshows/titles/,return)",I+"DefaultTVShows.png"),
  ("Find","RunScript(script.globalsearch,movies=true&tvshows=true&episodes=true)",I+"DefaultAddonsSearch.png"),
  ("More","ActivateWindow(Settings)",I+"DefaultAddonService.png")]),
 "movies.DATA.xml":menu([
  ("English",wall("movies-english.xsp")),("Hindi",wall("movies-hindi.xsp")),
  ("Indian",wall("movies-indian.xsp")),("Foreign",wall("movies-foreign.xsp")),
  ("Under 2 hours",wall("movies-under-2h.xsp")),("Added this month",wall("movies-new.xsp")),
  ("10 random picks",wall("movies-random.xsp"))]),
 "more.DATA.xml":menu([
  ("Add-ons","ActivateWindow(Videos,Addons,return)"),("Settings","ActivateWindow(Settings)"),
  ("Power","ActivateWindow(shutdownmenu)")]),
}
for f,b in files.items(): open(f,"w").write(b)
def w(group, lid, n, name, path, typ="movies"):
    s="" if n==1 else ".2"
    return [[group,lid,"widget"+s,"Library"],[group,lid,"widgetName"+s,name],[group,lid,"widgetType"+s,typ],
            [group,lid,"widgetTarget"+s,"videos"],[group,lid,"widgetPath"+s,path],
            [group,lid,"widgetStyle"+s,"Panel"],[group,lid,"widgetArt"+s,"Poster"]]
P=[]
P+=w("mainmenu","movies",1,"Continue watching",PL+"movies-continue.xsp")
P+=w("mainmenu","movies",2,"Top rated, unwatched",PL+"movies-toprated-unwatched.xsp")
P+=w("mainmenu","animated",1,"Continue watching",PL+"animated-continue.xsp")
P+=w("mainmenu","animated",2,"Random picks",PL+"animated-random.xsp")
P+=w("mainmenu","tv",1,"Next up","special://skin/extras/playlists/inprogressepisodes.xsp","episodes")
P+=w("mainmenu","tv",2,"Recently added","special://skin/extras/playlists/recenttvshows.xsp","tvshows")
for lid,bg in [("movies","Kodi.Movie.Fanart"),("animated","Kodi.Movie.Fanart"),("tv","Kodi.TV.Fanart"),("find","Kodi.Movie.Fanart"),("more","Kodi.Movie.Fanart")]:
    P.append(["mainmenu",lid,"background",bg])
json.dump(P,open("skin.aeon.nox.silvo.properties","w"),indent=4)
