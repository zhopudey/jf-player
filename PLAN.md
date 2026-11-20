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
**Why not CoreELEC (decided 2026-11-19):** supported for this box (`sc2_s905x4_sei_smb_280.dtb`)
but forum reports say HDR10+ plays as HDR10 and DTS-HD MA/DTS:X are not passed through. Reopen only if the
Dune app hand-off fails (7.3) AND a CoreELEC SD-boot test passes HDR10+, TrueHD Atmos, DTS:X, 24p.
Sources are forum posts, not release notes.
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
- [ ] **7.6 Resume position.** Pass the Jellyfin resume offset if Dune accepts one. Done = resuming an item starts
      at the saved position, or we record that Dune can't.
- [ ] **7.7 Watched/progress sync back to Jellyfin.** Dune plays outside Moonfin, so Jellyfin doesn't know.
      Options to test: Dune returns a result with position on exit; otherwise a "Mark watched" button or
      a prompt on return. Done = an item played through Dune shows correct watched state in Jellyfin.
- [ ] **7.8 Decide with Rohan** what the default Play action is on the box (Dune vs in-app) and whether
      subtitles/audio-track choice carry across. Done = recorded here.
