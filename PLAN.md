# jf-player — PLAN (living; tick items as they land)

**End goal:** downloads stay in step between Rohan's phone (Oppo Find X8 Pro, 512 GB) and tab
(OnePlus Pad 2, 256 GB). Updates install without Developer options or a PC, and an
update or reinstall never wipes downloads.

**⚠️ 2026-11-16: the fork is moving onto upstream Moonfin 3.1.0 (section 6).** The fork split off
around 2.2.0 and was 4,281 commits behind. Upstream now has local-first playback, a free-space
check, server-reachability retry and Smart downloads. Sections 2, 4 and 5 below are re-judged against
upstream in section 6. Branch `upstream-3.1` replaces `main` once 6.5 passes.

Each item states what **done** means: an observable fact, not "the code was written".
New discoveries go into this list (or are named as a blocker on an item). They never go
into a separate list.

## 0. Groundwork
- [x] **0.1 Repo reopened.** Done = GitHub `isArchived: false`. *(2026-11-16)*
- [x] **0.2 One permanent signing key.** Done = release builds sign with the key the tab's
      installed app already uses (cert SHA-256 `2372fadb…0b662c`, checked against the Aug 2026
      APK). The key is backed up off the build box. Passwords are kept in the lab's private
      secrets store, never in this repo. *(2026-11-16)*
- [x] **0.3 Build checkout clean.** Done = the build box's checkout is on `origin/main` with no
      stray changes. *(2026-11-16; the two Aug 2026 stashes are kept, not dropped.)*
- [ ] **0.4 A release APK installs over the existing app on the tab.** Done = the tab updates in
      place and its downloads are still there afterwards. This proves 0.2 end to end.
- [ ] **0.5 On-device test of the existing online/offline behaviour** (so far only read in code).
      Done = all of these pass on the tab: (a) play a downloaded title from the library and it plays
      from the device; (b) eps 1–3 downloaded, ep 4 not, and ep 4 streams with no prompt; (c) watch
      a download with no network, reconnect, and the server shows the new position; (d) watch online
      after watching offline, and the furthest position wins.

## 5. Seamless online/offline
Goal (Rohan, 2026-11-16): hit play on any title. Downloaded → play from device. Otherwise, if
online → stream. Mixed seasons play straight through. Watch progress syncs by itself
whenever the server is reachable. Already in code: the per-episode local-or-stream choice
(`OfflineFirstStreamResolver`, wired for every play path), mixed season queues (`c2fd99d3`),
and progress push/pull (`SyncService`). Verified by 0.5.
- [ ] **5.1 Re-sync when the server comes back, not only when the network changes.** Today the
      sync fires only on a connectivity transition (`connectivity_service.dart`), so if the network
      stays up while the server is unreachable, nothing syncs until the app restarts. Done = with
      Wi-Fi up, block the server, watch a download, unblock, and the server has the position
      within ~1 min without restarting the app.
- [ ] **5.2 Decision (Rohan): browsing while the server is unreachable.** Today only the Downloads
      screen works (`app_router.dart` `_isOfflineAllowed`). Options: keep that, or show the cached
      library pages with only downloaded titles playable. Done = decision recorded here.

## 1. Install without ADB
- [x] **1.1 Publish APKs to a fixed URL.** Done = the build is a GitHub release on this repo
      (Rohan chose GitHub Releases over the share on 2026-11-16). First one: `v2.2.0-30000140`.
      Flavor `mobile-beta` (`org.moonfin.androidtv.beta`). Each release needs a higher
      `--build-number` than the last, or Android refuses the update.
- [ ] **1.3 One-command release script on the build box.** Done = a script builds, bumps the build
      number, checks the signing cert, and publishes the release, so a new build needs no Claude.
- [ ] **1.2 Obtainium tracks it.** Done = phone and tab both get an update prompt for a new
      build without Developer options. Setup: Obtainium → Add app → `https://github.com/zhopudey/jf-player`.

## 2. Free space before downloading
- [ ] **2.1 Read real device free space** (Android `StatFs` on the download root). Done = the
      download dialog shows "≈ X GB needed · Y GB free".
- [ ] **2.2 Refuse what won't fit.** Done = a download (or a whole season, summed *before*
      queueing) larger than free space minus a reserve is refused with one short line, and
      nothing is half-queued. Today's check (`download_service.dart` `_checkStorageLimit`) only
      compares against the user's own storage-limit setting.

## 3. Custom download location — must be TESTED before sync relies on it
- [ ] **3.1 Test a custom download location on Android 16.** Done = on the tab, downloads
      written to a user-chosen folder outside `Android/data/<app>` play back, survive an app
      update, **and survive an uninstall + reinstall**. Why: the default
      `Android/data/<app>/files/Moonfin` is deleted on uninstall, and the public-Downloads
      ("mediastore") path is known broken on Android 16 (branch
      `downloads-public-folder-and-fast-copy`: raw-path writes are discarded).
- [ ] **3.2 Rescan / adopt existing files.** Done = after a reinstall (or on a new device) the
      app finds media already in the download folder and lists it as downloaded, without
      fetching it again. Blocked by 3.1.

## 4. Sync downloads between phone and tab
Design: a Jellyfin **playlist** ("Offline") is the shared list. Each device downloads whatever
is on it and missing locally, **from the server**, never device-to-device. Items can be added
from either device or from Jellyfin web.
- [x] **4.1 Decisions (Rohan, 2026-11-16):** (a) deletes are **not** mirrored; sync only adds.
      (b+c) when a season won't fit, the app says so ("Space low for full season") and the user
      **selects which episodes** to download. No automatic rule.
- [ ] **4.2 Sync on app open.** Done = add an item on the phone, open the app on the tab, and the
      item downloads there. If it won't fit (2.2), the app asks with the episode picker (4.5) instead of
      silently skipping.
- [ ] **4.5 Episode picker when space is low.** Done = queueing a season that exceeds free space
      shows "Space low for full season — select episodes", with a running total vs free space,
      and only the ticked episodes are queued. Used by manual downloads and by sync. Needs 2.1.
- [ ] **4.3 Per-device quality.** Done = each device can pick original or a transcode for synced items.
- [ ] **4.4 Background sync (optional).** Done = sync runs on Wi-Fi + charging without opening
      the app. A sleeping tab in Doze still won't react instantly; the ntfy wake idea
      ("push to sleeping tab") stays on the wishlist.

## 6. Move onto upstream 3.1.0 (decided 2026-11-16)
Approach: start from upstream tag `3.1.0` (branch `upstream-3.1`) and port only what upstream lacks.
Do not merge 4,281 commits into the old fork.
- [x] **6.0 Audit, fork vs upstream 3.1.0.** Already upstream, so dropped: local-first playback
      (`LocalFirstMediaStreamResolver`), mixed local/online queues, the free-space check (better than
      ours: it reserves space for concurrent downloads), the server-reachability retry (covers most
      of 5.1), offline progress sync on reopen, the download concurrency queue, Smart downloads (keep
      the next N episodes, delete watched), and "Play from Server". Our mpv buffer bump is dropped:
      upstream deliberately keeps the mpv default on phones (a bigger cache risks the OS killing the app).
- [ ] **6.1 Port swipe-to-seek + lock-button rework** (ours: `7f03b2a9`, spec §5–6) onto upstream's
      rebuilt player. Done = horizontal swipe seeks with a time preview on the tab, and vertical
      swipes still do brightness/volume.
- [ ] **6.2 Port the per-episode download picker** (ours: `667baee9`, `d57ce8f4`). Upstream only asks
      "all or unwatched". Done = Season/Series → Download opens the episode picker; downloaded
      episodes are badged.
- [ ] **6.3 "Space low — select episodes"** (Rohan's 4.1 decision) on the picker, using upstream's
      `storageHeadroomBytes()`. Done = a selection bigger than the headroom shows the warning and
      the running total.
- [ ] **6.4 Re-test our old fixes on upstream before porting any of them:** SRT/VTT rendering
      (`1bf7be58`), offline track switching (`7506af4c`), the DownloadManager speed path
      (`8aafc345`; re-measure against upstream's queue first, per the speed-ceiling finding). Done =
      each is either confirmed fixed upstream or ported.
- **Status 2026-11-16:** 6.1–6.3 are coded on `upstream-3.1` (commit `e6a70975`) and the analyzer
  passes. Released as `v3.1.0-30000163`. Nothing is ticked until it passes on the device.
  Build box toolchain for upstream: Flutter **3.47.2**, JDK **Temurin 17** (`~/jdk-17`, set with
  `flutter config --jdk-dir`; JDK 21 breaks `file_picker`), and Gradle forced onto IPv4.
- [ ] **6.5 Build, release and install on the tab** with the same signing key and package
      (`org.moonfin.androidtv.beta`, build number > 30000140). Done = it updates in place, downloads intact.
- [ ] **6.6 Re-judge sections 4–5 against Smart downloads.** Done = each item in 4–5 is marked
      covered by upstream, still wanted, or dropped (with Rohan).
- [ ] **6.7 Spec items not done yet:** quality pill (spec §1) and auto Media3 for HDR (spec §2).
      Upstream has neither. Done = Rohan decides whether they come into the plan.

## 7. Dune-grade playback on the Dune Homatics Box R 4K Plus (opened 2026-11-19)
**Goal:** on the box (Amlogic S905X4), Jellyfin browsing stays pretty (Moonfin) and playback is the
Dune app's, which Rohan tested earlier and plays everything (HDR10+, DV, TrueHD/Atmos, DTS:X, 24p).
**Why not decode in Moonfin:** Android's MediaCodec path cannot match the Dune pipeline. The Dune
app is tied to the box serial, so we call it and do not copy it.
**CoreELEC (superseded 2026-11-20):** Rohan decided to try CoreELEC first, as §8. The earlier "rejected" note rested on
forum reports (HDR10+ plays as HDR10, no DTS-HD MA/DTS:X bitstream) that nobody has tested on this box; Rohan believes
HDR10+ works and audio passes through. §8 settles it by test. §7 below is the fallback and stays open.
**§7 STATUS 2026-11-20 — PAUSED behind §8.** Done: box reachable, Dune package + intents known, hand-off launch works.
Answered (negative): Dune ignores position extras and keeps its own resume menu (7.6). Open: watched sync (7.7),
the Moonfin button (7.5), and quality on the living-room TV (7.3).
**Box is at `10.0.10.146:5555`** (was .136 on 2026-11-19; DHCP moved it, so pin a reservation) (adb from flutterdev `.37`, `~/Android/Sdk/platform-tools/adb`; probe output in
`~/dune-probe.txt` there). It is currently plugged into Rohan's 4K PC monitor (fake HDR), so ignore its HDR/display
readings. Quality tests (7.3, any CoreELEC trial) only count on the living-room TV + Denon.
**Box facts (2026-11-19/20):** SEI Robotics Box R 4K Plus, Android 12, build 7954, Amlogic decoder (log:
`AmlogicVideoDecoderAwesome2`). Dune app `com.dunehd.app` 1.0.1, accepts VIEW for http/https/smb/nfs/file/content.
**Stays on build 7954 on purpose.** An update to Android 14 (likely v14.8.8963) cannot be rolled back and CoreELEC
needs a different branch there. `settings global ota_disable_automatic_update=1` is set. Revisit only if a needed fix
ships and CoreELEC is no longer in play.

- [x] **7.1 Reach the box.** Done = `adb devices` lists it. Record IP in ACCESS.md; record Android TV
      version and `getprop ro.board.platform`.
- [x] **7.2 Find the Dune app.** Done = package name and its intent filters (`pm list packages | grep -i dune`,
      `dumpsys package <pkg>`) written here.
- [~] **7.3 Hand-off test.** 2026-11-20: Infinity War (4K HEVC DV 8.6, DD+ 7.1) from a stream URL started and plays in Dune on the monitor (`am start ... -p com.dunehd.app`). Still open: HDR/DV/audio mode and 24p, which only count on the living-room TV + Denon. `adb shell am start -a android.intent.action.VIEW -d <jellyfin direct URL> -t video/*`
      with a known DV/HDR10+/Atmos file. Done = Dune plays it with the right HDR/DV/audio mode on the Denon
      and 24p on the TV, or we know why not.
- [ ] **7.4 If 7.3 fails: share-path fallback.** Dune plays from SMB/NFS. Done = Moonfin maps a Jellyfin item to its
      share path and Dune plays it from there, or this is judged too fragile.
- [ ] **7.5 Moonfin "Play with Dune" action** (setting + button on the play screen, shown only where the Dune
      package is installed). Done = pressing it on the box starts Dune on that item, with a visible "Opening
      Dune…" state (operator rule: every UI says "I ain't dead").
- [x] **7.6 Resume position — ANSWERED: not possible.** 2026-11-20: `position`/`start_position` extras ignored; Dune shows its own "resume from 0:59 / from beginning" menu (needs a remote press, keeps its own position per file URL). Pass the Jellyfin resume offset if Dune accepts one. Done = resuming an item starts
      at the saved position, or we record that Dune can't.
- [ ] **7.7 Watched/progress sync back to Jellyfin.** Dune plays outside Moonfin, so Jellyfin doesn't know.
      Options to test: Dune returns a result with position on exit; otherwise a "Mark watched" button or
      a prompt on return. Done = an item played through Dune shows correct watched state in Jellyfin.
- [ ] **7.8 Decide with Rohan** what the default Play action is on the box (Dune vs in-app) and whether
      subtitles/audio-track choice carry across. Done = recorded here.

## 8. CoreELEC trial on the Box R 4K Plus (opened 2026-11-20)
**Goal:** find out whether CoreELEC + Jellyfin for Kodi gives Dune-grade playback on this box: DV, HDR10+, TrueHD/Atmos,
DTS-HD/DTS:X passthrough, 24p, with Jellyfin watched sync. FEL is not required (Rohan, 2026-11-19).
**Why it is safe:** it boots from a USB stick and leaves the Android install (and the Dune app) on internal storage.
**Where the steps come from:** CoreELEC wiki `coreelec:homatics`, and the community guide thread 28659 (edited 2023,
so treat details as dated). The old `Amlogic-ne` folder is gone from relkai; the stable NE image is on GitHub releases.
**Facts checked 2026-11-20:** latest stable NE image = **21.3-Omega** (2025-11-04). Device tree `sc2_s905x4_sei_smb_280.dtb`
is inside the image (read from its FAT partition). The box is on Android 12 build 7954, newer than the guide's v5310
floor for Dolby Vision. 22.0 "Piers" is NO-branch prerelease only, so not used.

- [x] **8.1 Files ready.** Image `CoreELEC-Amlogic-ne.aarch64-21.3-Omega-Generic.img.gz` (247 MB), sha256
      `6e5ef07bfad1fa85b9f30f440db1f80b0cdb9549960dbfa4688301947906a4b4`, in the share at
      `/mnt/user/projects/jf-player/coreelec/` (copyparty `/projects/jf-player/coreelec`) with `SHA256SUM` and a
      step sheet `README.md`. Done = checksum verified on the share (it was, 2026-11-20).
- [~] **8.2 Hardware ready.** Stick: the 16 GB SanDisk (slow, ~5 MB/s write). Still to confirm: flasher not needed (done on spotipi), toothpick for the reset pin, TV/Denon access. Original text:  Rohan has a fast USB 3 stick or SSD (the guide recommends Samsung FIT Plus; some sticks and
      USB-SATA adapters fail on this box), a flasher (balenaEtcher, Windows or Mac), and a toothpick for the reset pin.
      Done = Rohan confirms what he has.
- [ ] **8.3 Pre-flight on Android.** Turn Dolby Vision on in Android once (guide). Box on the living-room TV + Denon,
      TV and Denon powered on before the box (guide: avoids a distorted picture at boot). Done = Rohan confirms.
- [x] **8.4 Flash and prepare the stick — DONE 2026-11-20** on spotipi (`/dev/sda`, SanDisk 3.2 Gen1 16 GB; it held a Proxmox VE installer, now overwritten). Image checksums verified on the stick, `dtb.img` is byte-identical to `sc2_s905x4_sei_smb_280.dtb`. ⚠️ The stick wrote at only ~5 MB/s, so expect a slow first boot; the guide recommends a fast stick. Original text:  Flash the `.img.gz` (Etcher accepts it as is). Open the `COREELEC` partition,
      copy `device_trees/sc2_s905x4_sei_smb_280.dtb` to the root, rename it **`dtb.img`**. Done = stick has `dtb.img` at root.
- [x] **8.5 Boot into CoreELEC — DONE 2026-11-20** (Rohan booted it himself; CoreELEC 21.3-Omega, Wi-Fi works on 5 GHz). Original text:  Stick in the blue USB 3 port. Then either `adb reboot update` from flutterdev
      (`10.0.10.146:5555`) or the reset-button method (unplug power, hold reset, power on, keep holding until the CoreELEC
      boot screen). First boot can look frozen for 2+ minutes. Done = Kodi home screen.
- [x] **8.6 Basics — DONE.** Wi-Fi 5 GHz, SSH works (`root`, see 8.8). Bluetooth remote not tested. Original text:  Wi-Fi on the 5 GHz SSID (or ethernet), Bluetooth remote paired (Back + Home held), SSH on with
      a changed password. Done = `ssh root@<ip>` works and `ping` is fine.
- [ ] **8.7 Playback matrix on the living-room TV + Denon.** Play each title below; for each write PASS/FAIL and
      what the Denon and TV show (DV or HDR10+ badge, Dolby Atmos/TrueHD/DTS-HD MA readout, TV Hz). Done = the table
      is filled in here. Titles (all on disk, all 23.976 fps, from Sanchalak + Jellyfin 2026-11-20):
      | test | title | file |
      |---|---|---|
      | DV P8 + DD+ 7.1 (reference, plays in Dune) | Avengers: Infinity War (2018) | 21.2 GB |
      | DV P8, smallest 4K | Spider-Man: Into the Spider-Verse (2018) | 11.3 GB |
      | DV P8 + **TrueHD Atmos** | Spider-Man: Across the Spider-Verse (2023) | 34.1 GB |
      | DV + **HDR10+** + **TrueHD Atmos** (+ DD+ Atmos track) | Guardians of the Galaxy Vol. 3 (2023) | 34.5 GB |
      | **HDR10+** only (no DV) | Alien (1979) 20.5 GB, or Die Hard (1988) 6.4 GB | |
      | DV + HDR10+ + **DD+ Atmos** | Iron Man (2008) | 13.8 GB |
      | **DTS-HD MA** + HDR10+ | Predator (1987) | 23.5 GB |
      | DTS-HD MA + DV P8 | No Country for Old Men (2007) | 47.2 GB |
      | **DTS:X** | none in the library (Jellyfin shows only DTS-HD MA) — Rohan to name one or skip | |
      | FEL, info only | Dune: Part Two (2024) (DV profile 7 with EL) | 69 GB |
- [~] **8.8 Jellyfin on CoreELEC — WORKING on the Acer (2026-11-20), TV re-test pending.** Jellyfin for Kodi 2.2.0 in add-on mode,
      signed in as `rohan` on `10.0.10.40:8096`, **only `movies-english` synced** (250 movies, 18 s). Skin: Arctic Zephyr Mod 3.0.3.
      Tested: Infinity War plays 4K HEVC, output switched to **3840x2160 @ 23.98 Hz** by itself, Kodi reports `dolbyvision`
      (the Acer has no DV, so no real DV check), server shows no transcode. **Watched sync both ways works**: Kodi to Jellyfin
      (stop at 10:00 gave a 609 s resume point; needs a stop past ~5% or Jellyfin ignores it) and Jellyfin to Kodi (mark
      unplayed, Kodi followed in 12 s). The test overwrote Infinity War's play history; restored exactly (4 plays, 2026-10-10).
      Still open: sync the other 7 libraries (movies-hindi/animated/others, TV-*), Kodi Sync Queue plugin on the server (not
      installed; live updates worked without it for watched state), and the playback matrix on the TV (8.7).
      **Gotchas hit:** (1) the official repo zip points at a dead URL, so the add-on was installed by hand from
      `repo.jellyfin.org/releases/client/kodi/py3/plugin.video.jellyfin/` (md5 checked), deps from Kodi's repo;
      (2) Arctic Zephyr's menu builder failed until `ln -s 1080i xml` inside `/storage/.kodi/addons/skin.arctic.zephyr.mod/`;
      (3) Kodi reverts a skin change unless "keep?" is answered within ~10 s.
      **Box access (CoreELEC):** `ssh root@10.0.10.146` (password has a trailing `!`: `me2go4it!`), flutterdev's key is installed.
      Kodi remote API on `:8080`, user `kodi`, same password. Backup of the original `guisettings.xml` in `/storage/backup-pre-jf/`.
      **Before the TV test:** audio passthrough is OFF in Kodi (`audiooutput.passthrough` false) and must be turned on, with
      the Dolby/DTS capability boxes, or the Denon will get PCM. Refresh-rate switching is already on.
**2026-11-22 (IST), first living-room session — findings, all measured:**
- **Denon HDMI input 5 shows no signal from the box; input 3 works.** The box is on input 3, which the Denon auto-renamed "CoreELEC" (HA still calls it "Blu-ray"; the HA CoreELEC button selects it).
- **Passthrough ON, HDMI device** (it was on S/PDIF, which only carries AC3/DTS core). Denon reported "Dolby Atmos - TrueHD", 4K24, Dolby Vision on Spider-Man: No Way Home. Refresh matching works (3840x2160 @ 23.98).
- **OPEN: the overlay layer is not scaled up at 4K output.** At 4K24 the subtitles sit at about half size in the top-left quarter (photo + Kodi screenshot disagree). Setting the Kodi GUI to 3840x2160 put the whole interface in the top-left quarter, so it was reverted to 1920x1080 (option 28). Does not affect 1080p60 menus.
  **Researched 2026-11-22: this is a known CoreELEC 21.3-Omega regression on the Homatics Box R 4K Plus.** Forum (discourse.coreelec.org): thread 57707 post 18 (aka, 9 Nov 2025: "21.2 behaves fine; 21.3, upgraded or clean, leaves the UI in a quarter of the screen at 4K"); thread 55688 (WeLikeChasen: GUI at 1080p still goes top-left once 4K plays; "downgraded to the latest stable CoreELEC 21 and it's working"); thread 55970 (Portisch blames calibration values in guisettings.xml and points to CE-NO; deleting guisettings.xml did not help the reporter). No staff fix or fixed release found. **Candidate fix to test: go back to CoreELEC 21.2-Omega** (reflash the stick, or a manual `.tar` update; downgrade-in-place is unverified). Kodi settings tried and ruled out: subtitle align, override styles, vertical shift, GUI 4K.
- **OPEN: Bluetooth remote "B25"** bonds in bluez but bluez's HID layer fails ("input-hog profile accept failed"), so no input device; no IR key events reach the box either. A 2.4 GHz USB keyboard works.
- Kodi web/remote enabled on :8080 (user `kodi`). Toggling `services.esallinterfaces` crashed Kodi once (segfault): do not toggle it.
- **Not yet answered: judder** (output matches 23.976, no dropped-frame evidence). Playback matrix 8.7 still not run.
- Main menu: Music and Pictures removed (backup `mainmenu.DATA.xml.orig-2026-11-22` in the skin's `shortcuts/`).
- HA now has a Sofa dashboard (`/dash-sofa`) with Denon controls, signal info and a Kodi remote; Redmi Pad is the sofa tablet.
- [~] **8.11 Kodi fun setup on 21.3 (reframed 2026-11-23).** Why: Apple TV serves the family; Kodi is Rohan's hobby box, so the point is how it is set up, navigation first. Context: the 21.2 regression test is **lost** (the 21.2 stick, `.124`, was upgraded in place to 21.3 by an accepted prompt; both sticks are 21.3; Rohan runs one at a time; live stick is `.124`, Kodi web `:8080` user `kodi`). Overlay bug stays open on 8.10 only if it annoys him. Dropped by Rohan: lights, Denon automation (AVR already auto-switches), pre-roll. Codec/bitrate readout goes to the Redmi Pad HA panel, not Kodi. Language + genre are the filters; navigation must be very easy.
      - [x] a. Check smart-playlist viability. Done 2026-11-23: all 250 `movies-english` titles sit in Kodi's library (paths `plugin://plugin.video.jellyfin/...`), 16 clean genres, every item carries its library tag (`movies-english`), plus extra tags (sequel, superhero, based on comic...). Language = library tag, not audio track tags (98% `eng`, useless for Hindi/Marathi).
      - [x] b. Generator `tools/kodi/gen_playlists.py` (JSON-RPC in, `.xsp` out, `KODI_PASS` env, `--min` skips tiny combos). Done = runs; dry run gave 33 playlists from the 1 synced library.
      - [x] c. Backup done 2026-11-23: `userdata` + skin `xml` (28 MB tgz) taken before the sync; library sync lives in `/storage/.kodi`, so it survives OS version changes (same Kodi 21 DB).
      - [x] d. All 8 libraries synced 2026-11-23 (Jellyfin vs Kodi): movies-english 253/252, animated 84/84, hindi 106/106, others 58/58; TV-anime 8, english 9, hindi 3, others 1. Method: `Addons.ExecuteAddon plugin.video.jellyfin params {mode:synclib,id:<viewid>}`, ONE id per call (a comma list gets mangled). `Cinephage Test TV` deliberately not synced. No Marathi library exists; Marathi would sit in `movies-others`.
      - [x] e. 89 playlists deployed 2026-11-23 to `/storage/.kodi/userdata/playlists/video/` (8 existing files untouched). Checked over JSON-RPC: `movies-hindi--drama` lists 3 Idiots, 12th Fail, 78 titles. SSH: on at `.124`, my key (ananta_mesh) added; ⚠️ root password is still the CoreELEC default `coreelec`. Regenerate with `tools/kodi/gen_playlists.py`.
      - [~] f. Home menu v1 done 2026-11-24 (Rohan's ask: "movie libraries easily accessible"): main menu is now Recently Added, English, Hindi, Animated, Others (each opens its smart playlist poster wall), Genres (the playlists folder, sorted so each language's genres group together), TV Shows, Add-ons, Settings, Power. Videos and Live TV dropped. File `/storage/.kodi/addons/skin.arctic.zephyr.mod/shortcuts/mainmenu.DATA.xml` on `.124`; undo = copy `mainmenu.DATA.xml.orig-2026-11-24` over it, delete `userdata/addon_data/script.skinshortcuts/*.hash`, `systemctl restart kodi`. Still open: confirm each tile on the TV (Rohan), widget rows on Home (Continue Watching, Next Up), a proper language -> genre second level, and TV language tiles. Original text: Home screen: rows Continue Watching, Next Up, Recently Added, one per language; language -> genres -> poster wall. Skin route open (keep Arctic Zephyr and rearrange / Arctic Fuse / custom). Done = Rohan finds any film in <=3 clicks.
      - [ ] g. Scene-marks row, hidden while empty (marking takes weeks; blocks nothing).
      - [ ] h. Open: idle art screensaver (Rohan undecided).
      - [x] l. Back stops full-screen video (2026-11-24): keymap `/storage/.kodi/userdata/keymaps/back-stops-video.xml` on `.124` (remote back, backspace, esc, browser_back -> Stop; OSD still closes first). Not yet tested on a film; undo = delete file + `kodi-send --action=reloadkeymaps`. All stick config files are copied to `tools/kodi/stick-config/` with restore notes.
      - [~] m. CEC, Apple TV constraint (2026-11-25). Finding: the Kodi box follows the TV: `standby_pc_on_tv_standby` was Suspend (TV off -> box sleeps; TV on -> box wakes via `wakeup_cec_auto_power`), `activate_source=1`, `standby_tv_on_pc_standby=1`. **Temporary, Rohan OK'd:** set `standby_pc_on_tv_standby` = 36028 (Ignore) in `/storage/.kodi/userdata/peripheral_data/cec_CEC_Adapter.xml` (backup `.orig-2026-11-25`) so the box stays awake for the working day. **REVERT TONIGHT** (Kodi stopped, restore the `.orig`, start Kodi). Tonight's test, Rohan present: the real risk is the other direction, TV powered on by an Apple TV remote button -> does the Kodi box wake and grab the HDMI input? Then re-run mom's one-button start. Goal stated by Rohan: TV/AVR switch off when unused (power), any Apple TV remote button brings it all back on and selects the Apple TV. Not changed: Denon, TV, Apple TV, HA scripts.
      ## PART A: POWER AND INPUTS (critical, tested before any Part B work). Rohan's rule 2026-11-25: wake, sleep and input switching must be thoroughly tested.
      **Design principle (Rohan 2026-11-25):** for everyone else it is magic: they press a button on the remote in front of them and things just work, zero fuss, no step to know about. So the test of every power and input change is the family's first press, not the setup. Priority order: Apple TV remote wake/off and input (A1, A1b, A6, A11, A12), then Kodi remote (A2, A3, A4), then the rest.
      **Method:** Rohan does every physical action; I watch (read-only) the Kodi box log (CEC lines), the Denon signal and power sensors and HA entities, and the TV state, and write each result into the table. One test at a time, Rohan says go. Stop at the first failure, put the box back to its baseline, and ask. No settings on the Denon, TV, Apple TV or HA scripts change during testing; if a fix would need one, ask first. Only the Kodi box's own settings may change, and each change is backed up.
      **A0. Baseline before testing:** revert the temporary stay-awake setting (m: restore `cec_CEC_Adapter.xml.orig-2026-11-25`, Kodi stopped while restoring); snapshot Kodi's CEC settings, the Denon input and volume, and the TV input; confirm mom's flow works once before touching anything.
      **Pass rule:** every row below reads "as expected", and mom's flow (A1) passes again at the end.
      | # | Starting state | Action | Expected | Result |
      |---|---|---|---|---|
      | A1 | everything off, Kodi box asleep | any Apple TV remote button | TV + AVR on, input = Apple TV, Zee Marathi; the Kodi box does NOT take the input | PARTIAL 2026-11-25 08:10 (box not cleanly asleep: pinged, Kodi not running): AVR on, TV on, TV came up on CoreELEC first, moved to Apple TV after a few seconds by itself. Not yet zero-fuss; cause unknown (TV last-input vs box claiming). Open: did it land on Zee Marathi, what the screen showed meanwhile. Re-run with the box properly asleep. **FAIL 2026-11-25 22:39** (box truly off: no ping, and it cold-booted, uptime 0): Apple TV came up first, then the TV switched to Kodi by itself. The box was up ~25 s after the press (a CEC wake), Kodi's CEC adapter registered at 22:39:42, and then Kodi took the input (`activate_source=1` = send active source on startup, the likely cause). No fix applied; asked Rohan. **Fix applied 22:43 (Rohan: "do both"), Kodi box only:** `activate_source`=0 and `cec_func_config='27'` in `/flash/config.ini` (was default 7f; bits 3 auto-power, 4 stream path, 6 active route cleared; kernel shows `hdmitx=cec27`). Backups `cec_CEC_Adapter.xml.pre-nowake-2026-11-25`, `/storage/config.ini.pre-nowake-2026-11-25`. **Re-run 22:51, box asleep: box stayed asleep (no ping); TV went straight to Apple TV, then switched BY ITSELF to the CoreELEC input (blank, box asleep).** So the box no longer causes it; something else (Denon, TV or an HA automation) selects Blu-ray. HA (token now at `~/.config/ha_token` on sutra): Denon stayed on Apple TV (= Denon GAME) the whole time, no automation ran; the Denon's sensors dropped for 17 s at 22:51:21. Denon's own API at 22:56: input GAME. The banner said "CoreELEC", but the Denon never switched; the screen was blank until an Apple TV remote press brought the picture back. CoreELEC firmware (bl30 `hdmi_cec.c`) never claims the input while asleep, only answers OSD name/status. **Open:** a blank screen after Apple TV start, on the Apple TV/Denon side, not the Kodi box. Mom's flow needs a second press until this is solved. **Re-run 22:58: PASS** (straight to Apple TV, box stayed off). Watch log: Denon ON GAME 22:58:00, BD 22:58:04, GAME 22:58:06 (a ~2 s Blu-ray blip at power-on, no HA automation, box asleep; likely TV/Denon last-CEC-source memory). Rohan 2026-11-25: leave the blip (the fix, box CEC fully off, would break A2). The 22:51 blank screen = the same blip without the return to GAME; watch for repeats. |
      | A1b | everything off, Kodi box awake | same | same | 2026-11-25 22:47, after the fix: TV showed Kodi ~5 s, then Apple TV. Kodi log silent (no active-source sent). Same outside cause as A1 re-run. |
      | A2 | everything off | Kodi remote Power | TV + AVR on, input = Kodi box (Denon HDMI 3), Kodi box awake | FAIL 2026-11-25 23:00 with `activate_source`=0: box boots, TV + AVR stay off. With `activate_source`=1 (23:02, Kodi restart): TV + AVR on, Denon GAME -> BD 23:02:17 -> GAME 23:02:20 (the Apple TV, woken by the TV power-on, claims back and wins). **Rohan 2026-11-25: accepted; Kodi is started from the HA dashboard CoreELEC button, not the Kodi remote.** **PASS 23:04** (`activate_source`=1, box cold-booted by its remote): TV + AVR + Apple TV on, input stays Kodi (Denon BD). The 23:02 loss was a Kodi restart, not a remote start. |
      | A3 | Kodi active (idle on Home) | Kodi remote Power | Kodi box sleeps, TV + AVR off | PASS 2026-11-25 08:17 (Rohan, by eye: TV on Kodi, Power on Kodi remote, everything switched off). Not timed; box sleep not confirmed from the log. |
      | A4 | Kodi playing a film | Kodi remote Power | playback stops (resume saved), box sleeps, TV + AVR off | [ ] |
      | A4b | Apple TV active, Kodi box awake in the background | Kodi remote Power | LOW PRIORITY (Rohan 2026-11-25: he won't use the Kodi remote while on Apple TV; run it last, record only, no fix needed unless it hits the family). Wish: Kodi's Power acts ONLY when Kodi is the active input; with Apple TV active it must NOT switch the TV or AVR off (the box may sleep, the TV/AVR stay on). Likely to fail with the current CEC defaults (box standby sends standby to the TV): record it and ask before fixing | [ ] | PASS 2026-11-25 08:11 (Rohan, by eye; Apple TV active, Kodi remote Power: box powered off, Apple TV unaffected; the Kodi box was not running Kodi, repeat with Kodi running).
      | A4c | Apple TV active, Kodi box off | Kodi remote Power (turn on) | box powers on and the TV input switches to Kodi (expected CEC behaviour). Observed 2026-11-25 08:12, accepted by Rohan: he keeps the Kodi remote out of reach while the Apple TV is in use. | OBSERVED, accepted |
      | A5 | Apple TV active, Kodi box awake in the background | Apple TV "turn off" | TV + AVR off; Kodi box follows or stays awake (record which); nothing turns back on by itself | PASS 2026-11-25 22:45: TV + AVR off, Kodi box STAYED AWAKE (no TV-standby seen in its log). Earlier note: [ ] NOT RUN (a FAIL was recorded here by mistake at 08:13 and retracted 08:14: Rohan's last tests were the Kodi remote Power off then on, not an Apple TV turn-off). |
      | A6 | Apple TV active, Kodi box asleep | Apple TV "turn off" | TV + AVR off; nothing wakes | [ ] |
      | A7 | Kodi active | switch to Apple TV (its remote) | input switches, Kodi pauses or stops playback, Apple TV works | [ ] |
      | A8 | Apple TV active | switch to Kodi (HA CoreELEC button / Denon input 3) | input switches, Kodi shows | PASS but SLOW 2026-11-25 08:15 (Rohan, Redmi Pad HA dashboard button): switched after ~4-5 s. Cause (read from HA `scripts.yaml`, `denon_coreelec`): `media_player.turn_on`, fixed `delay: 6s`, then `select_source Blu-ray`. The 6 s is for a cold start and is paid even when the AVR is already on. Proposed fix, NOT applied (needs Rohan's go, it is an HA Denon script): skip the delay when the AVR is already on, keep it for cold start. The Apple TV script likely has the same shape (check). |
      | A9 | Kodi box asleep, TV off | TV powered on by TV's own remote | record what wakes and which input is selected | [ ] |
      | A10 | everything on, idle | wait for the TV's own auto power-off (if configured) | TV + AVR off, nothing wakes | OBSERVED 2026-11-25/26 night: TV on all night (living plug ~69 W 23:38-06:47 vs ~25 W floor). Rohan: started the box with the Kodi remote, switched the Denon off on its front panel, maybe pressed Apple TV off. The Denon's standby pass-through kept the dimmed Kodi screen on the TV, so the TV never saw "no signal"; Kodi stays awake idle. Proposed (not applied): Kodi idle-sleep ~30 min (TV follows via `standby_tv_on_pc_standby`), first test that it does NOT switch the TV off while the Apple TV is in use (A4b). |
      | A11 | Kodi box mid-boot or restarting | Apple TV button | still works; the box does not take the input when it finishes starting | [ ] |
      | A12 | A1 repeated at the very end | | mom's flow still passes | [ ] |
      | A13 | **Power-cut recovery** (opened 2026-11-27; 2026-11-26 real cut: TV came up on its VIDAA home, family could not switch, the Apple TV press did nothing) | cut power with the HA living-room plug, restore, wait, then ONE Apple TV remote press | TV + AVR on, input = Apple TV, Zee Marathi, no TV remote needed. Theory (untested): Apple TV CEC goes via the Denon, which has not re-handshaked with the TV after a cold boot, so the switch request dies there; it worked when the Apple TV was wired straight to the TV. **Before the test:** check what the plug actually powers (TV, Denon, Apple TV, Kodi box?) and that cutting it is safe for each. Rohan present, **planned 2026-11-28**. Record: what each device shows, timings, does a 2nd press or a 1-min wait fix it. | [ ] |
      **Answers from Rohan 2026-11-25:** Kodi's Power key acts only when Kodi is the active input (row A4b). TV's own auto power-off: unknown, he checks tonight (A10 waits for it). Report format: this table plus a line in vaikuntha-core for any Kodi-box change.
      ## PART B: UI/UX
      **The whole-picture design is `tools/kodi/UI_SPEC.md` (2026-11-26, Rohan: "take care that all screens have consistent ui/ux"). Its build list is THE list for Part B; the items below are detail behind it. **Handover 2026-11-26 13:21: Rohan stopped the Unraid array (power), so kodi-lab and /projects are down; all source is in git (`tools/kodi/skin_patch.py`, `ui-menu/`, `gen_ui_playlists.py`). Review done by Rohan: 01/02/05/06 great, 03/04 ok (now colour), seasons + episodes in MyFlix, NO flattening (Friends, Mentalist). Next: Rohan tests navigation with the remote, then one deploy to the box. Open: language playlists auto-regenerate.** **2026-11-26 11:12: whole spec built in kodi-lab; review shots `/projects/jf-player/kodi/review-2026-11-26/`; waiting for Rohan's OK, then one deploy to the box.** Build everything in kodi-lab, one review with screenshots, one deploy. Small calls are mine; only the spec's "Open, for Rohan" items go to him.**
      **Design talk 2026-11-25 (Rohan thinking aloud; a direction, not final; nothing built).**
      - Home menu, 5 items: **Movies · Animated · TV · Find · More** (More = Add-ons, Settings, Power). Language is NOT on Home: groups are lopsided (English ~250, Hindi ~106, the rest thin) and only 4 Marathi films exist, so a language tile wastes space. Under the menu: poster rows (Continue Watching, Next Up, Recently Added).
      - Inside Movies: first strip = language filter **All · English · Hindi · Indian (incl. Marathi) · Foreign**, then genre. Animated is its own top item.
      - Rohan: filters alone do not help when he does not know what mood he is in. So Movies opens on **browsing rows that pick for him** (ideas: highly rated + unwatched, under 2 h, added this month, 10 random picks reshuffled daily, "because you watched X", a taste-map row from `/projects/taste`); filters (language, genre, unwatched, IMDb 7+/8+, decade, runtime) sit one level below for when he does know.
      - Find = title search for a film he already knows: on-screen keyboard with the remote (slow, ~3-4 presses a letter; check if Zephyr search narrows live) or Kore on the phone (text box pops up automatically; phone keyboard mic = voice search). Plus Surprise me.
      - **Grid view (all walls):** optimise for the 75" Hisense at 8-9 ft. Dense poster grid on ~2/3 of the width, no titles under posters (8-10 across x 4 rows = 32-40 posters, ~11-13 cm each), selected film big in a side panel with poster/backdrop, title, year, IMDb, runtime, genres, plot, audio + subs line; optional dimmed backdrop behind everything. UI stays **1080p** (eye cannot tell 4K at 8-9 ft; Mali-G31 GPU would make scrolling sluggish; films still play 4K). Start from a built-in Zephyr view and adjust it, not a custom one: candidates Wall Small (517), Shift / Shift Modern (509/519), Side Cards (515), Extra Info (57).
      - Remote: Homatics stays for now (no transport keys: OK = pause, Back = stop). Fallback if that feels clumsy: Samsung BN59 IR clone (~Rs 399; CoreELEC/remotes has a ready `remote.conf`). Rejected: Sony RM-ED054 (SIRC protocol, no ready config, may not decode), Fire TV remote (Bluetooth, B25 never connected; no Stop/colour keys).
      **Handover 2026-11-26 09:58 (next session starts here):** UI work happens in kodi-lab (browser http://10.0.10.40:8595/, driver `tools/kodi/kodi-lab/kl.sh`, screenshots to `/projects/jf-player/kodi/`). Decided: SiLVO + InfoWall (51) for walls. Open, in order Rohan picks: (1) media-flag icons on InfoWall: **DONE in kodi-lab 10:34** (skin edit, `tools/kodi/kodi-lab/infowall_flags.py`: plot shortened, row of resolution/HDR/video codec/audio codec/channels at the bottom of the right panel; backup `View_51_InfoWall.xml.orig-2026-11-26`; screenshots `/projects/jf-player/kodi/infowall-flags-*-2026-11-26.png`). Not yet on the box `.124` (needs skin auto-update off + ReloadSkin, no restart). Audio flag shows Kodi's first audio stream (1917 shows DD+, not checked against the file); Rating badge on every InfoWall poster: **DONE in kodi-lab 10:37** (`infowall_rating.py`, bottom-right, ListItem.Rating = TMDb until u2 switches the source to IMDb; screenshot `/projects/jf-player/kodi/infowall-rating-badges-2026-11-26.png`). Plot on the wall scrolls via Right -> scrollbar; Enable.AutoScroll is off (Rohan tries tonight); (2) SiLVO home menu (Movies, Animated, TV, Find, More + poster rows, per the design talk); (3) u2 IMDb ratings; (4) untested remote keys on the TV; (5) remaining key brainstorm (Rohan rejected all 5 of my ideas). Rules learned: never restart Kodi on the box without asking (CEC turns the TV on); never send Enter in kodi-lab without a screenshot first. Kodi box `.124`: SiLVO active, Zephyr kept. **kodi-lab 2026-11-26 08:28:** Kodi 21.2 sandbox container on Unraid (source `tools/kodi/kodi-lab/`): browser `http://10.0.10.40:8595/` (noVNC), JSON-RPC `:8596` (kodi/kodilab). Populated 08:46 without the box: Jellyfin add-on (rohan, 523 movies / 22 shows), SiLVO, 91 playlists; English InfoWall matches the TV. Notes in `tools/kodi/kodi-lab/README.md`. Home menu not built yet. UI testing only (Rohan 2026-11-26): no playback, no data work there. Parked: the `kodi-tracks` Jellyfin API key on sutra returns 401 (found 09:55; check `track_list.py` / the Cinephage task later). **Handover 2026-11-26 08:19 (Rohan left, box off):** SiLVO active, Rohan: InfoWall "will work". Missing: media-flag icons in the InfoWall panel (only resolution shows; full flags only in the i dialog). Asked: (1) use i, or (2) skin edit adding the flag row to `View_51_InfoWall.xml` (+ disable skin auto-update). Also open: rebuild the home menu in SiLVO; IMDb rating (u2). **No box action while Rohan is away** (a Kodi restart switches the TV + AVR on). **Status 2026-11-26 07:35 (Rohan):** power/CEC works but "depends on luck" (the ~2 s Blu-ray blip, the 22:51 blank screen); built remote keys (mic, i, CC, Home) still untested; remaining keys need a brainstorm (item s); UI design (Part B) pending. **View check 2026-11-26 07:48-07:52 (Rohan at the TV, English wall, switched by kodi-send):** Side Cards 515 = 3 cards; Wall Small 517 = 35 posters, a bit small, no info; Shift 509 = 7 in a row, no info; Shift Modern 519 = 7 + info below, wasted space; Extra Info 57 = text list (Rohan: no text lists, ever); Wall 55 = 2 rows, no info; Poster 53 = 5.5 + zoomed selected with info; Cards 58 = 4 with basic info; Netflix 504 = 5 + info; BigWide 51 = single poster, no info. Toggles tried 08:00 (Google tip): Wall Small + `ShowPoster517` = 27 small posters + one big poster on the left, no text; Wall 55 + `showinfo`+`showposter` = 16 posters, media-flag icons at the bottom, no text (left ON); + `slideinfo` = text slides out, looks weird (reset). **Aeon Nox SiLVO 10.0.3 installed + active 2026-11-26 08:16** (official repo; skin set in `guisettings.xml` with Kodi stopped, backup `guisettings.xml.pre-silvo-2026-11-26`; undo = same with `skin.arctic.zephyr.mod`; Zephyr menu/settings kept on disk). InfoWall (view 51): 3x5 posters on the left 60%, right panel = fanart, title, genre, year, rating, runtime, plot, resolution flag; screenshot `/projects/jf-player/silvo-infowall-2026-11-26.png`. Scar: restarting Kodi (activate_source=1) switched the TV + AVR on; ask before any Kodi restart. Zephyr verdict: none matches the grid spec; closest base = Wall Small (density) + a side info panel = a modified view. **Handover addendum 2026-11-26 07:33:** TV left on overnight (see A10). Talked, nothing decided: (a) an HA watchdog (living plug ~60 W+ while Denon off 20 min -> CEC standby via Kodi, or notify first); (b) Kodi idle-sleep ~30 min, needs the A4b test first; (c) one remote for everything: Sofabaton X1S too expensive; free options = Homatics forwards keys to Apple TV via HA/pyatv when Apple TV is the active input (latency spike needed), Jellyfin on Apple TV (loses TrueHD/DTS:X bitstream), or phone/Redmi HA page. TEP Tuya IR blaster: not needed for this. Kore works (`kodi` @ .124:8080). Steve Jobs take on the keymap: CH +/-, numbers, colour keys stay unbound (Rohan still thinking). Library view: current Zephyr view leaves one row of 5-6 under a big poster; try Side Cards and Wall Small first. **Handover 2026-11-25 23:26:** done tonight: (1) m reverted (already, at 21:43); A1/A1b/A2/A5 run, CEC wake bits off (`cec_func_config='27'`), `activate_source` back to 1; (2) remote keys logged and the settled ones built (item s, untested). Not done: (3) one film (OK/Back/`[trackpicker]`), (4) view cycling, A10 TV auto power-off, A4, A6-A12. **Tonight 2026-11-25 (Rohan at the TV):** (1) revert m's stay-awake CEC setting first; (2) remote key presses for s; (3) one film: OK pauses, Back stops, `[trackpicker]` line (q2, l); (4) cycle the 4 candidate views via side menu -> Viewtype, say which is closest and what is missing.
      **Items (order to be re-agreed after the design talk; nothing starts without Rohan's go):**
      - [ ] u1. **Language groups (revised 2026-11-25).** Filter groups inside Movies: English, Hindi, Indian (Marathi + ta/te/ml/kn/bn/pa/gu...), Foreign. Animated separate. Source = TMDb `original_language` (already resolved per title by `tools/kodi/track_list.py`), NOT library tags. A smart playlist cannot filter on language, so `gen_playlists.py` must emit title-list playlists from that data, regenerated by the Cinephage task. Open: TV shows (same groups?). Done = counts per group shown to Rohan, he confirms, filter shows the right films on the TV.
      - [ ] u2. **IMDb ratings in every view (Rohan 2026-11-25).** Finding: Kodi shows TMDb (3 decimals, 0 votes, all 518 movies), not IMDb. Rohan OK'd option 1: enable Jellyfin's OMDb metadata provider so the IMDb rating reaches Jellyfin's community rating, and the Kodi add-on syncs it (Moonfin gets it too). Needs: a free OMDb API key (Rohan signs up, mail to his address) and a Jellyfin setting change (ask before applying, report to vaikuntha-core). Check first whether the OMDb provider really overwrites the rating, on one film. Fallback: script via OMDb by IMDb id into Jellyfin's community rating. Second half: Zephyr poster wall view that shows the rating badge, enabled on every wall and the Home rows. Done = 5 random films show the same rating as imdb.com, on a poster wall AND on Home.
      - [ ] o. Home rows: Continue Watching, Next Up (Zephyr widgets), with the rating badge from u2. Done = both rows on Home on the TV, resuming a film from the row works.
      - [ ] p. Movies page per the design talk: browsing rows first, then filters (u1 language, genre, unwatched, rating); replaces the flat Genres folder of 89 playlists. Done = from Home to any film in a language+genre in <=3 clicks, on the TV.
      - [ ] v. Quick find: (1) A-Z letter jump on every wall (number keys, Kodi built-in; check it works with the Homatics remote); (2) title search typed or spoken from the phone via Kore (voice = phone keyboard mic, no IR mic); (3) "Surprise me": a random unwatched film, per language group. Done = a known title reached in <=4 presses; a Kore voice search lands in Kodi's search box; Surprise me plays or opens a film.
      - [ ] w. Collections / franchises: Jellyfin collections as Kodi Sets, maybe tag tiles (sequel, superhero, based on comic). Decide after p, only if Rohan misses them. Actor/director: no home tile; use Zephyr's info dialog (cast -> their films).
      - [ ] x. Filters by year/decade and runtime inside the walls (not home tiles). Low priority.
      - [ ] s. Kodi remote contract (opened 2026-11-25; principles in `tools/kodi/UX_PRINCIPLES.md`). The remote is the Homatics Box R 4K Plus IR remote (photo seen): no transport keys; colour keys and app keys share codes (4 distinct); subtitle (CC), bookmark and TV keys are not in `remote.conf`. **Tonight, Rohan holding the remote:** press subtitle, bookmark, TV, mic once each while I read Kodi's key log (read-only); record which reach Kodi. **Result 2026-11-25 23:07 (amremote debug, dmesg):** all four keys reach the IR receiver but are `undefined` in `remote.conf`, so Kodi sees nothing: subtitle 0x58 (logged 3x), bookmark 0x74, TV 0x32, mic 0x46 (order as pressed; mapping assumed from order). Second pass 23:10: Home 0x47, Settings 0x0f, Red 0x4b, Green 0x4a, Yellow 0x49, Blue 0x4c, 0-9 0x01-0x0a, Source 0x60: all already defined in `remote.conf` and reach Kodi (colour keys share keycodes 398-401 with the 4 app keys). Fix = add the 4 undefined ones to `remote.conf` with Linux keycodes, then a Kodi keymap. **Keymap talk 2026-11-25 23:20 (Rohan):** Home = stop playback (and go Home); Bookmark = defer; Mic = open the search box; TV = defer; CH +/- and 0-9 = I suggest something better; colour keys = need more thinking. Draft table in the session, not built. **Built 23:25, UNTESTED on the TV:** `remote.conf` i 0x29 -> KEY_I (23, was 24 = O); mic 0x46 -> KEY_SEARCH (217); CC 0x58 -> F13 (183); bookmark 0x74 -> F14; TV 0x32 -> F15 (backup `remote.conf.pre-keys-2026-11-25`, box rebooted, custom_code loaded). Keymap `jf-remote.xml` + `jf_stop_home.py` (source `tools/kodi/stick-config/`): mic = global search (movies/TV), CC in playback = Kodi's subtitle dialog (stopgap until the q0 panel), Home in playback = stop + Home. Bookmark/TV reach Kodi, unbound (deferred). **Next session, test:** mic, i, CC, Home in playback + resume. Open with Rohan: CH +/-, numbers, colour keys (more thinking). Then decide the colour-key shortcuts and bind them in a keymap next to `back-stops-video.xml` (backup first). Open: task list (5 lines max), home-screen concept. Done = every remote key has one fixed meaning, written down, and checked on the TV.
      - [ ] q0. **Rule agreed by Rohan 2026-11-25:** subs ON for everything. **Audio = the film's ORIGINAL language, for everything** (Rohan: some dual-audio files do not flag the original as default, so Kodi's `original` setting alone is not enough; needs a script that knows the original language, source to decide: TMDb `original_language` via Jellyfin provider id or Cinephage). Subs language English. Two layers: (1) right by default (items below); (2) CC key opens one panel in playback with Audio and Subtitles lists (human labels, current focused, left/right switches list, up/down picks, OK confirms, Back closes), fallback a colour key if CC does not reach Kodi (item s). **Done =** any film starts with the right audio and subs on, and a wrong default is fixed in 2 key presses.
      - [x] q1. **Design agreed 2026-11-25: precomputed track list.** A job builds `path -> audio track, subtitle track` from the Jellyfin API (MediaStreams + TMDb id; ffprobe only as fallback) and TMDb `original_language`. Audio = original language, subs = English full, always on. A Kodi service script reads the list at playback start (no network at play time); missing film = Kodi defaults. Updates **as soon as Jellyfin picks a film up**: poll Jellyfin every ~5 min for new or changed items (no plugin, no server restart), retry unresolved ones on each pass (streams and TMDb id can land after the item is added), plus a weekly full pass as a safety net. Entries keyed by path + file size. Writes a status line (last run, count) and a readable `unresolved` list. Needs a TMDb key (check secrets). **Done =** a new film in Jellyfin is in the list within ~10 min, and the unresolved list is short and readable. **Built 2026-11-25 as Cinephage task `fork-kodi-tracks` ("Kodi Track List", 5-min poll, fork-f1490529); first full pass 1684 items, 1548 ok / 136 unresolved; output `/mnt/user/data/kodi-tracks/` on .40 (`tracks.json`, `unresolved.txt`, `status.json`). Still to prove: a NEW film appears within ~10 min. Delivery to the Kodi box is open (files are mode 600, owner nobody). `tools/kodi/track_list.py` kept as a reference.**
      - [~] q2. Builder done 2026-11-25: `tools/kodi/track_list.py` (Jellyfin API + TMDb; keys in `~/.config/kodi-tracks/` on the sutra container). First full run, 1683 titles in ~6 min: 1547 resolved, 136 unresolved (128 have no English sub, 8 have no original-language track); incremental pass takes ~6 s. Kodi's file URL carries `id=<Jellyfin item id>`, which is the list key. Unresolved list at `/projects/jf-player/kodi-tracks-unresolved.txt`. **Still open:** (a) Kodi service script that reads `tracks.json` at playback start and selects audio + subs (not written, needs a test film on the TV); (b) schedule: poll ~5 min + weekly `--full`, and where it runs; (c) deliver `tracks.json` to the Kodi box; (d) 128 no-English-sub titles: decide (fetch subs via the Whisper add-on / Bazarr, or leave off). **2026-11-25 17:31: (a) and (c) built, untested on a film:** Kodi service `service.trackpicker` (source `tools/kodi/service.trackpicker/`, installed + enabled on .124, logs `[trackpicker]` lines to kodi.log); Unraid User Script `kodi_tracks_push` copies `tracks.json` to the box every 5 min when it changed (key `/root/.ssh/id_ed25519` on .40 authorised on the box). (b) done as Cinephage task. **Done =** play one film with a wrong default, see correct audio + English subs, read the `[trackpicker]` line.
      - [ ] q. Default audio/subs: (1) set preferred subtitle language to English (now `original`; audio is already `mediadefault`); (2) optional Kodi service script that picks tracks at playback start from Jellyfin's stream data (language/default/forced) + the library tag, no database writes. Files stay untouched (seeding). Rejected: cron writing Kodi's `MyVideos131.db` (Kodi + the Jellyfin add-on write it; lock/corruption risk) and NFO edits (Kodi ignores NFO stream details).
      - [ ] r. Automatic Jellyfin sync: it already syncs new titles and watch state on its own (500 -> 516 movies, Golam resume 40.9 vs 40.8 min). Open: time a new title from Jellyfin to Kodi, and check deletions/edits. Kodi Sync Queue plugin only if a gap shows (needs a Jellyfin server restart; ask first).
      - [x] s. Remote buttons: spare keys (colour/app, CH +/-, bookmark, TV) stay UNBOUND (Rohan 2026-11-26: no suggestion feels right). Revisit only when a real repeated need shows up. 0-9 = A-Z jump per UI_SPEC.
      - [ ] t. Bluetooth remote: not worth buying anything; IR works, Kore works.
      - [x] k. Time zone set 2026-11-24: `/storage/.cache/timezone` = `TIMEZONE=Asia/Kolkata` on `.124` (was UTC; the `.cache` exclusion from the storage copy lost it), `tz-data` restarted; Kodi reports `Asia/Kolkata`.
      - [x] j. IR remote fix applied 2026-11-24: `remote.conf` (CoreELEC/remotes, Homatics Box R 4K plus, md5 `c1ea2a73...`) at `/storage/.config/remote.conf` on `.124`, rebooted; dmesg shows `add custom_code 0x00007788`. Rohan: worked, stuck once for a while, then worked again by itself (Kodi load was ~4.5 at the time, so it may be Kodi lag, not IR). Watch for repeats; undo = delete the file. B25 Bluetooth and the Portronics 2.4G USB keyboard (dongle enumerates, zero key events seen) still unresolved.
      - [ ] i. Housekeeping: Kea reservation for `.124` (MAC `50:41:1c:cd:eb:44`) done 2026-11-23 (in opnsense, hostname coreelec); HA Kodi entities already point at `.124`; `.146` is the other (off) stick. IR `remote.conf` fix still unapplied (see handover below).
- [ ] **8.9 Decide with Rohan.** *2026-11-22: Rohan rejected the Dune app outright ("UI is horrible, I am not using that"), so CoreELEC/Kodi is the path and the open issues above must be fixed, not routed around.* CoreELEC only, Dune hand-off (§7) only, or both (CoreELEC for movies, Dune app as
      a switch-back). Done = decision recorded here and §7 closed or reopened.
- [ ] **8.10 Back to Android.** Remove the stick and power-cycle (or "reboot to emmc" from the power menu). The guide has no
      explicit revert text, so this is unconfirmed until tried. Done = Android and the Dune app come up with the stick out.
**Remote findings 2026-11-22 (handover):** (1) **IR fix identified, NOT yet applied:** the box has an IR receiver but no keymap (`/storage/.config/remote.conf` missing; log says `using meson-ir`). Fix = copy `AmRemote/Homatics Box R 4K plus/remote.conf` from github.com/CoreELEC/remotes (fetched OK, NEC, `factory_code 0x77880001`) to `/storage/.config/remote.conf` on the live 21.3 box AND on the 21.2 stick's STORAGE (stick is on vaikuntha `/dev/sdg2`, unmounted), then reboot. Forum: thread 58179. Awaiting Rohan's go. (2) Bluetooth B25: bonded but not connected, HID-over-GATT, `input-hog profile accept failed`, no /dev/input event; no confirmed forum fix (one B21 anecdote: pair in Android + remote firmware 2.04 first). Low priority once IR works. (3) Tablet remote = **Kore** (Rohan's choice), host `.146` now, `.124` on the 21.2 stick, user `kodi`. (4) State: **old 21.3 stick is active on `.146`; HA still points at `.124`, so HA Kodi entities are dead until the 21.2 stick boots or HA is flipped back (ask Rohan).** (5) Kodi CEC review still open (see constraint below).
**HARD CONSTRAINT (Rohan, 2026-11-22): the Apple TV's HDMI-CEC chain must never change.** Any Apple TV remote button powers the whole system on and mom gets Zee Marathi with minimum fuss. So: no CEC changes on the Denon/TV/Apple TV, no CEC used as a CoreELEC remote path, and re-check the Apple TV one-button start after any box/Denon/HA change. Open check: Kodi's libcec on the box is at defaults (CEC adapter registered) and may send active-source/standby; to be reviewed with Rohan before the 21.2 stick goes into the living room.
**Risks noted:** the bootloader is locked and verified, so no eMMC install, USB boot only. Android 14 firmware would change
the picture (do not update). A CoreELEC-then-Android round trip can leave the LED glitching (guide).

## 9. Favourite scenes page in Kodi (opened 2026-11-20)
**Goal:** a "Favourite scenes" entry on the Kodi home screen. Cards with thumbnail, title, short description. Press one and the
scene plays from its start time and **stops at its end time** (YouTube-style: it ends, it does not roll on into the film) and
returns to the page. Rohan never hand-hunts timestamps. Jellyfin play state does not matter (Rohan, 2026-11-20).
**Depends on:** §8 (CoreELEC booted, Jellyfin for Kodi). Sources for the scene list: taste-map notes (`/mnt/user/projects/taste/1_distilled`,
his "scene-jump" picks and his own scene descriptions), `rewatch` page "Scenes" taps.
- [ ] **9.1 Scene data file.** One file in this repo: film (Jellyfin item), start, end, category, title, description.
      Done = file exists with ≥6 scenes across comedy / thrill / song / emotional, each with a start AND an end time.
- [ ] **9.2 Timestamp finder (no hand-hunting) — subtitles first (Rohan, 2026-11-20: more reliable).** Script matches a quote or
      description against the film's subtitles (embedded or external, via ffmpeg) and returns candidate start/end + a thumbnail
      per scene for Rohan to glance at. Only if a scene has no usable dialogue: local Whisper transcript, then (last resort)
      frame sampling. No vision model or face matching is set up unless a scene proves it necessary. Done = 5 test scenes get a
      correct start AND end without Rohan typing a time. Known risk: subtitle times drift between encodes, so check against
      the copy on the shelf (the thumbnail makes a bad match visible).
- [ ] **9.3 Seek + stop spike on the box.** Prove Kodi can start an item at T and stop at E (JSON-RPC `Player.Seek` or add-on
      `seekTime`, plus a watcher that stops at E). Done = on the Acer (then the TV), a test scene starts within ~1 s of T, stops
      within ~1 s of E, and the UI returns to the page, not the film.
- [ ] **9.4 Test on a few scenes, one per mood** (comedy, thriller, song, emotional). Done = Rohan says which of start/end
      accuracy, thumbnail and description actually matter to him.
- [ ] **9.5 Design the page** from what 9.4 teaches (grouping by mood? random scene? description length?). Done = layout agreed with Rohan before any code.
- [ ] **9.6 Kodi add-on.** Home-screen entry, the page, play-and-stop, "I ain't dead" state while it seeks. Done = on the box, one remote press from home plays a scene to its end and returns.
- [ ] **9.7 One-line add.** "Add <scene> from <film>" runs 9.2 and appends to 9.1. Done = a new scene appears on the page without Rohan editing a file.

## 10. Mark scene — capture button for MODAK (opened 2026-11-20)
**Goal:** while watching a film, Rohan taps to mark scene start/end (or a song) so MODAK (`~/repos/modak`) gets real boundaries.
Android first. Do not disturb the swipe-seek / quality-pill work (`SPEC_swipe_seek_and_quality_pill.md`).
**Tap model (Rohan, 2026-11-20):** one tap on the Mark button enters *marking mode*; timeline and controls then stay visible
(no auto-hide). In marking mode: tap = start, next tap = end, repeat. Long press = song. Marks show on the timeline like editor markers.
**Defaults I assumed (he did not object; change if wrong):** a start with no end when marking mode is left or the film closes becomes a
`point`; a tap within 3 s of the previous one is ignored as a double-tap; the sync URL is edited inside the Marks sheet (no new pref).
**Status 2026-11-21:** code is committed and pushed on branch `scene-marks` (cut from `upstream-3.1`), released as GitHub release `v3.1.0-30000170` (APK `moonfin-beta-3.1.0-30000170.apk`, for Obtainium). `flutter analyze` clean, store tests pass. 10.2–10.5 are not ticked until they run on the phone.
- [x] **10.1 Mark model + durable queue.** `lib/playback/scene_marks/`. JSON file in app documents, atomic write. Done = unit test: add marks,
      re-open the store, all are still there; a corrupt/partial write does not drop earlier marks.
- [ ] **10.2 Marking mode in the player.** Mark button in the controls row; mode keeps controls visible; tap start/end; long press song;
      haptic + toast "Start 1:03:30" / "End 1:08:10"; skippable one-line note. Done = on the phone, marks in both orders saved with right item id/position.
- [ ] **10.3 Timeline markers.** Ticks for point/song, shaded range for start–end, on the seek bar. Done = marks visible on the bar at the right place; pending start shown differently.
- [ ] **10.4 Export marks.** "Export marks" saves `marks.json` via the system save dialog. Done = file on phone storage, array of the spec'd objects.
- [ ] **10.5 Sync (optional target).** One configurable URL, empty by default; POST /marks with JSON array; retries when connectivity returns; never deletes a mark.
      Done = with URL empty nothing is sent; with a test URL, queued marks arrive after airplane mode is turned off.
- [ ] **10.6 End-to-end on the phone.** Done = open a film, start+end tap, airplane mode on, kill the app, reopen: marks in exported marks.json. (Needs Rohan's phone; build via flutterdev/.37.)
