# Kodi UI spec: the whole picture (PLAN 8.11 Part B)

Written 2026-11-26. This is the ONE design for the Kodi box. Every UI item in PLAN 8.11 Part B is a
line in the build list at the bottom. A new idea must name the screen here that it changes, or
this file gets rewritten first. Principles: `UX_PRINCIPLES.md` (Apple tvOS rules).

**Base:** Aeon Nox SiLVO 10.0.3, UI at 1080p, 75" Hisense at 8-9 ft, Homatics IR remote.
**Workflow:** build everything in kodi-lab (`http://10.0.10.40:8595/`), then ONE review with a
screenshot of every screen, then ONE deploy to the box (skin auto-update off first). The box
is only touched after Rohan's go.

## What the box is for (task list, 5 lines; nothing else gets a screen)
1. Carry on with what I'm watching.
2. Pick a film when I don't know what I'm in the mood for.
3. Find a film I already know.
4. Browse by language and genre.
5. Watch it: right audio + English subs from the first frame, simple controls.

## Consistency rules (apply to EVERY screen)
- **One poster card.** 2:3 poster, no title under it. Rating badge bottom-right (gold on dark,
  IMDb once u2 lands). Watched tick top-right (SiLVO overlay). Same card on walls and Home rows.
- **One list view: the InfoWall (51).** Every list of films or shows uses it: language walls, genre
  walls, Home "see all", Animated, TV shows, seasons, search results. No text lists, ever.
  Exception: episodes (see S5) use the same panel with landscape thumbs.
- **One info panel.** Right side of the wall, the same block order everywhere: backdrop, title +
  resolution tag, genre, year · rating · runtime, tagline + plot (scrolls), flag row
  (resolution, HDR, video codec, audio codec, channels). The full info dialog (S4) repeats the
  same order, larger.
- **One focus style.** SiLVO's theme-coloured border + small zoom. No other highlight colours.
- **Same keys everywhere.** The remote contract below; no screen re-binds a key.
- **First focus is predictable:** Home = first menu item; walls = first poster (or last-watched
  position when coming back); dialogs = the main action (Play/Resume).
- **Fast first.** Nothing ships that makes scrolling or opening a wall feel slow on the box
  (Mali-G31). Fanart behind everything stays OFF unless it passes the feel test on the TV.

## Screens
| # | Screen | What it does | What it shows |
|---|---|---|---|
| S1 | **Home** | tasks 1 + entry to 2-4 | Menu: **Movies · Animated · TV · Find · More**. Above it, two poster rows that follow the focused item (SiLVO allows 2): Movies = Continue watching + Top rated unwatched; Animated = Continue watching + Random picks; TV = Next up + Recently added shows. Down from Movies = the filter strip (S2). |
| S2 | **Movies** | task 2, then 4 | The picking rows are the Home rows (S1). The filter strip is the Movies submenu on Home: **English · Hindi · Indian · Foreign · Under 2 hours · Added this month · 10 random picks**. Movies itself / a language = genre tiles (SiLVO colour genre images, same wall) -> film wall. |
| S3 | **Wall** (InfoWall 51) | browse | Poster grid on the left, info panel on the right (rules above). Number keys jump A-Z. **Left from the first column = side menu, the ONE place for refining any wall:** sort (rating, year, added, A-Z), Unwatched only, Filter (genre, actor, director, rating, year). Same menu on every wall. |
| S4 | **Info** (i key / long OK) | details | Same block order as the panel, larger; Play/Resume first, then cast -> their films, trailer. |
| S5 | **TV** | tasks 1, 4 | Shows wall (S3) -> seasons -> episodes, both in SiLVO's MyFlix view (509): plot top-left, a row of season posters / episode thumbs, flag row on episodes (Rohan 2026-11-26). Seasons stay separate, no flattening (Friends, The Mentalist). Show tiles carry no flags: flags are per file. |
| S6 | **Find** | task 3 | Global Search: keyboard opens straight away (mic key lands here too; Kore types from the phone); results = posters by Movies / TV / Episodes with plot + flag row. "Surprise me" = the "10 random picks" strip entry. |
| S7 | **Playback** | task 5 | Right tracks automatically (trackpicker). CC key opens one Audio + Subtitles panel. Minimal OSD: title, time, progress. |
| S8 | **More** | rare | Add-ons, Settings, Power. Nothing else. |
| S9 | **Idle** | power | Screensaver / idle sleep: open (h, A10). |

**Animated** opens straight on the film wall (84 films; a genre step would be noise).

## Remote contract (fixed; item s)
Settled 2026-11-26 (Rohan: none of the suggestions "feel right"): spare keys stay unbound. A key gets a
meaning only when a real, repeated need shows up while using the box. Retire this when one does.
| Key | Everywhere | In playback |
|---|---|---|
| OK | open / play | pause |
| Back | up one level | stop |
| Home | Home | stop + Home |
| i | info (S4) | info |
| mic | Find (S6) | — |
| CC | — | audio + subs panel |
| 0-9 | A-Z jump on walls | — |
| colour keys, CH +/-, bookmark, TV | unbound (do nothing) | unbound |

## Build list (one list; tick here and in PLAN)
Built in kodi-lab 2026-11-26 (review shots `/projects/jf-player/kodi/review-2026-11-26/`). Source: `skin_patch.py`
(all skin edits, applied to pristine files), `ui-menu/build_menu.py` (Home menu + rows), `gen_ui_playlists.py`
(language / picks playlists). Default view = InfoWall (51), then MyFlix (509) for episodes; saved SiLVO view
states cleared so the default applies.
| Item | Screens | Done = | Status |
|---|---|---|---|
| Media flags in the panel | S3 | flag row shows on every wall | done (lab) |
| Rating badge, one shared definition | S1, S3 | same badge on walls and Home rows | done (lab), TMDb until u2 |
| u2 IMDb ratings | all | 5 random films match imdb.com on a wall and on Home | blocked: OMDb key (Rohan) |
| o Home rows | S1 | rows per menu item; resume from a row works | built (lab); resume needs the TV |
| Home menu (5 items) + More submenu | S1, S8 | the 5 items open the right screens | done (lab) |
| u1 Language groups | S2 | counts: English 249, Hindi 106, Indian 60, Foreign 23 (Kabali has no language yet) | done (lab); Rohan to sanity-check counts |
| p Movies strip + genre tiles | S2 | Home -> language -> genre -> film = 3 presses of OK | done (lab) |
| Animated wall | S2 | opens on the wall | done (lab) |
| InfoWall everywhere | S3, S5 | movies, genres, shows open as the wall | done (lab) |
| Seasons + episodes layout | S5 | MyFlix view by default on any show | done (lab) |
| v Find | S6 | keyword gives poster results | done (lab); mic + Kore on the TV |
| Language playlists stay current | S2 | a new film lands in its language wall without me | **open**: run `gen_ui_playlists.py` next to the 5-min tracks push |
| s Remote contract | all | every key in the table works on the TV | built on box earlier, untested |
| q0/q2 Tracks + CC panel | S7 | wrong default fixed in 2 presses | trackpicker built, untested |
| g Scene-marks row | S1 | row shows when marks exist | later |
| Review + deploy | all | Rohan OKs the shots; box updated once: skin auto-update off, files + playlists + menu copied, folder view states cleared, `showparentdiritems` + `showallitems` off, ReloadSkin, then set the view once per screen type with kodi-send (51 on a movie wall, genre tiles, TV wall; 509 on a seasons and an episodes list; Kodi keeps these as per-type defaults); no restart | waiting for Rohan |

**Known rough edges (my calls, say if any bother you):** genre-tile screens have an empty right panel on a
black background; Find results show titles under posters and no rating badge (it is Global Search's own
window); SiLVO remembers the last focused Home item instead of always starting on Movies.

**Out of the picture (not screens):** w collections. x decade/runtime filters now live in the S3 side menu. Re-enter only by
naming the screen they change.

## Open, for Rohan (big-picture only)
1. Idle: screensaver or straight to sleep (S9).
