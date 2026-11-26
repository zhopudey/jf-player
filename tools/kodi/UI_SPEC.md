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
| S1 | **Home** | tasks 1 + entry to 2-4 | Menu: **Movies · Animated · TV · Find · More**. Under it, poster rows: Continue Watching, Next Up, Recently Added. Rows hide when empty. |
| S2 | **Movies** | task 2, then 4 | Opens on picking rows: Top rated unwatched, Under 2 hours, Added this month, 10 random (reshuffled daily). Under the rows, a filter strip: **All · English · Hindi · Indian · Foreign**, then genre. Every row / filter opens S3. |
| S3 | **Wall** (InfoWall 51) | browse | Poster grid on the left, info panel on the right (rules above). Number keys jump A-Z. **Left from the first column = side menu, the ONE place for refining any wall:** sort (rating, year, added, A-Z), Unwatched only, Filter (genre, actor, director, rating, year). Same menu on every wall. |
| S4 | **Info** (i key / long OK) | details | Same block order as the panel, larger; Play/Resume first, then cast -> their films, trailer. |
| S5 | **TV** | tasks 1, 4 | Shows wall (S3) -> seasons wall (S3) -> episodes: landscape thumbs + the same panel. Language groups as in S2 if the counts justify them (22 shows today: probably just one wall). |
| S6 | **Find** | task 3 | Search box opens straight away (mic key lands here too); results on a wall (S3). Typing from the phone via Kore. "Surprise me" = a random unwatched film opened in S4. |
| S7 | **Playback** | task 5 | Right tracks automatically (trackpicker). CC key opens one Audio + Subtitles panel. Minimal OSD: title, time, progress. |
| S8 | **More** | rare | Add-ons, Settings, Power. Nothing else. |
| S9 | **Idle** | power | Screensaver / idle sleep: open (h, A10). |

**Animated** = S2 with the same rows and strip, animated films only (84).

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
| Item | Screens | Done = | Status |
|---|---|---|---|
| Media flags in the panel | S3 | flag row shows on every wall | done in kodi-lab 11-26 |
| Rating badge on posters | S3 | badge on every wall poster | done in kodi-lab 11-26 (TMDb) |
| u2 IMDb ratings | all | 5 random films match imdb.com on a wall and on Home | blocked: OMDb key (Rohan) |
| Badge + card on Home rows | S1 | Home rows use the same card as walls | |
| o Home rows | S1 | Continue Watching / Next Up / Recently Added on Home; resume from a row works | |
| Home menu (5 items) | S1, S8 | the 5 items open the right screens | |
| u1 Language groups | S2, S5 | counts per group shown and confirmed | |
| p Movies page | S2 | any language+genre film in <=3 clicks | |
| Animated page | S2 | same as Movies, animated only | |
| InfoWall everywhere | S3, S5, S6 | every list in the box opens as InfoWall | |
| Episode layout | S5 | episodes show thumbs + the same panel | |
| v Find + Surprise me | S6 | known title in <=4 presses; mic lands in search | |
| s Remote contract | all | every key in the table works on the TV | partly built, untested |
| q0/q2 Tracks + CC panel | S7 | wrong default fixed in 2 presses | trackpicker built, untested |
| g Scene-marks row | S1 | row shows when marks exist | later |
| Review + deploy | all | Rohan OKs the screenshots; box updated once | |

**Out of the picture (not screens):** w collections. x decade/runtime filters now live in the S3 side menu. Re-enter only by
naming the screen they change.

## Open, for Rohan (big-picture only)
1. Idle: screensaver or straight to sleep (S9).
