# Moonfin fork — worklist & handoff spec

Six items for this Moonfin fork (Flutter/Dart Jellyfin client), **ordered by real-usage value**.
Target: **Android phone + OnePlus Pad 2 tablet**, against a real Jellyfin server.
Line numbers are **hints** — anchor on the named symbols; the files shift.
(Filename is legacy — this doc covers the whole list, not just swipe/quality.)

## Global constraints (all items)
- **Reuse existing code.** Most of what's needed already exists — locate and call it; don't reimplement.
- **Surgical, mergeable diffs.** Keep the fork mergeable with upstream Moonfin. Several items below are
  clean **upstream PR candidates** (marked ⬆) — consider contributing them back.
- **Route through `PlaybackManager`**, never a backend directly, so changes stay engine-agnostic.
- **Do NOT touch the rendering/surface layer.** Seek, source-swap, engine-select are controller-level.
- **No new state-management patterns or deps** without justification. Match surrounding style.
- **Findroid is reference-only** (`PlayerGestureHelper.kt`) — it's **GPLv3**, this fork is **GPLv2**;
  study the approach, copy no code. Write fresh Dart.

Priority order: **1** Quality pill → **2** Auto-HDR engine → **3** Offline play-next fix →
**4** Multi-select download → **5** Locked-overlay fix → **6** Swipe-seek.

---

## 1. Quality pill (THE PRIORITY)
**Why:** single-copy library ⇒ phone streaming relies on transcoding, which works fine *if quality can
be dropped easily*. This pill is that control. Must be **prominent, always-visible, one tap, seamless**
(no restart / no lost position — already true via `changeBitrate`).

**Reuse:** `_showBitrateSelector()` (`video_player_screen.dart:5856`), `_buildBitrateButton()` (:5885),
`_manager.changeBitrate(int?)` (`playback_core/.../playback_manager.dart:186` → `_reResolveAtCurrentPosition`,
already captures position + resumes), `_manager.maxBitrateOverrideMbps` (:189),
`_manager.currentResolution` (:122, delivered stream → video height), `TrackSelectorDialog`.

**1A (ship first, zero plumbing):** replace the buried bitrate *icon* with a prominent labelled **pill**
showing current delivered quality (`720p · 4 Mbps` / `Auto`), tap → existing `_showBitrateSelector()`.
Style with the existing chip styling; keep the accent-when-override behavior. **This alone delivers the
priority.**

**1B (optional, adds resolution axis — least mergeable, do last):** add `_maxResolutionOverride` +
`changeResolution(MaxVideoResolution?)` to `PlaybackManager` (mirror `changeBitrate`); thread it through
`PlayerBackend.getDeviceProfile` (`media_kit_player_backend.dart:450`, reads prefs :453–454) as an
optional named param → `DeviceProfileBuilder.build(maxResolution: override ?? pref)`. ⚠ `getDeviceProfile`
is on the `PlayerBackend` interface — update **every** implementor (media_kit, media3, tizen, appletv,
html); keep the param optional/defaulted so it's additive. Enum: `MaxVideoResolution`
(`preference_constants.dart:64`).

**Test:** pill shows current res+bitrate; tap → drop bitrate → resumes at same position (confirm in
Jellyfin Dashboard active session). Remote (transcode) + LAN.

---

## 2. Auto-select Media3 engine for HDR/DV  ⬆
**Why:** MPV (default, robust) renders SDR-ish; Media3 (native surface) does HDR. Manually switching
engines in Settings per HDR file is the friction. Make it automatic: HDR/DV content → Media3, else MPV.

**Reuse (all already in `lib/di/modules/playback_module.dart`):** the selector closure
`manager.setBackendSelector((resolution, currentBackend) { ... })` (:399) — **already receives
`resolution`** (carries `VideoRangeType`); `HdrStreamCapability.isDolbyVisionVideoStream()` /
HDR detection already used here (:46, :75); both backends are **live singletons** (:366–367, so switching
is free); content-based selection **precedent** exists (`_shouldUseHtmlVideoBackend(resolution)`, :412).

**Change:** in the Android branch (~:423), before the pref check, detect HDR/DV from `resolution`'s
video stream (VideoRangeType HDR10/HDR10Plus/DOVI/HLG via `HdrStreamCapability`); if HDR/DV, return
`Media3PlayerBackend` regardless of the MPV pref. ~a dozen lines, one file. Optionally gate behind a new
`autoHdrEngine` pref (default **on**).

**Nuance:** works for **direct-play HDR** (home/wifi — original stream + Media3 native surface = HDR).
Remote transcodes lose HDR before any renderer sees it, so no engine restores HDR there — expected, fine.

**Test:** play an HDR10/DV title on wifi with pref = MPV → confirm it auto-uses Media3 and the panel
enters HDR (gain-map screenshot / `adb dumpsys SurfaceFlinger | grep dataspace` → `BT2020_PQ`). SDR title
→ stays on MPV.

---

## 3. Fix — Offline "play next" jumps online  ⬆
**Why:** starting a downloaded episode from the main Offline list plays a lone item; "next" goes online.

**Root cause:** `launchOfflinePlayback` (`lib/playback/offline_playback_launcher.dart:17`) builds an
offline queue **only when passed `episodeQueue`**. Passed by `saved_season_screen.dart:103`,
`saved_album_screen.dart:62/82`, `item_detail_screen.dart:5961` — but **NOT** by
`saved_media_screen.dart:404` (`_playOffline`) → single item → next falls back to `_resolver.resolve` (online).

**Fix:** in `saved_media_screen._playOffline(item)`, when `item` is an Episode, build `episodeQueue` from
the item's **downloaded siblings** (same series, sorted by season/episode — from the offline repository)
and pass it, like `saved_season_screen.dart:103`. Movies stay single.
**Defensive (optional):** in `PlaybackManager.next()` (`playback_manager.dart:1573`), when
`_isOfflinePlayback` and the next item isn't downloaded, skip/stop — never resolve online.

**Test:** play a downloaded episode from the main Offline screen → let it end / hit next → next
**downloaded** episode plays offline (airplane mode on to prove no network).

---

## 4. Multi-select episode download  ⬆
**Why:** anime = many episodes. Today it's whole-season (season Download button) or one-at-a-time (open
each episode → Download). No way to grab a chosen subset (e.g. eps 12–18) in one action.

**Reuse:** the episode list `DetailEpisodeCard` (`item_detail_screen.dart:2015`, class :11955);
`_startDownload` (:9350) already routes `Episode→downloadItem`, `Season→downloadItems(all)`;
**`downloadService.downloadItems(List, quality)` already exists** (:9373) — batch method is done.

**Change:** add a selection mode to the episode list (selection state + a checkbox on `DetailEpisodeCard`
in selection mode, long-press to enter), a "Download selected" action, plus "Select all" / "Select
unwatched". Download → `downloadItems(selectedEpisodes, quality)`. Reuses the existing background/reliable
download pipeline; no engine changes. (Same UX as the Findroid batch spec, but easier — the batch method
already exists here.)

**Test:** select a subset → download → all queued + complete in the Downloads screen; select all = whole
season; single-tap (not in selection mode) still opens the episode.

---

## 5. Fix — Locked overlay text sits on the video  ⬆
**Why:** with OSD-lock on, the "long-press to unlock" pill is parked center-screen over the video. Hit
constantly because the lock **auto-engages** (`_scheduleHide()` sets `_isOsdLocked = true`, :2508–2511).

**Root cause:** `_buildLockedOverlay()` (`video_player_screen.dart:5506`) renders the pill
unconditionally; `IgnorePointer(ignoring: !_controlsVisible)` (:5513) disables *touch* but not *visibility*.

**Fix:** wrap the pill in `AnimatedOpacity(opacity: _controlsVisible ? 1.0 : 0.0, duration: 200ms, child:
IgnorePointer(ignoring: !_controlsVisible, child: <pill>))`. Locked = clean video; tap (`onTap:
_showControls`, :5510) fades the unlock pill in; it fades out with the next auto-hide. Clean screen is the
intended behavior — no toggle.

**Test:** lock (or idle 8s) → video is clean, no text; tap → unlock pill appears → long-press unlocks;
leave it → pill fades out.

---

## 6. Swipe-to-seek with trickplay preview (nice-to-have)
**Why:** lower priority now that offline (with its own gestures) isn't the driver, but still nice for
streaming. Entirely in `video_player_screen.dart`; no plumbing.

**Reuse:** GestureDetector (:3338; vertical volume/brightness handlers `_onVerticalDrag*` at :5259+ to
mirror); `_isSeeking` (:130), `_seekValue` (:131); `_getTrickplayTile()` (:4440) +
`_buildSeekPreviewThumbnail()` (:4355) (trickplay fetch/crop/render already wired for scrubbar);
`_buildGestureIndicator()` (:5404) for the delta/timestamp chip; `_manager.seekTo(Duration)`.

**Change:** add `onHorizontalDragStart/Update/End` (gated mobile-only like the vertical ones).
Start: record `_state.position`. Update: map total dx → time delta —
`deltaSeconds = (totalDx / screenWidth) * SECONDS_PER_FULL_SWIPE` (≈120, tunable; density-independent,
better than Findroid's raw px×90ms); set `_isSeeking`/`_seekValue`, show a centered overlay with
`±delta [target]` + `_getTrickplayTile(target)` thumbnail. End: `_manager.seekTo(target)` **once**.
**Do NOT call `_scheduleDebouncedScrubSeek`** (:2637) — it commits mid-drag; commit on release only.
Degrade: no `_trickplayInfo` → timestamp only. Port Findroid's guards (activation threshold, edge
exclusion, disabled when locked/TV).

**Test:** drag on video body → overlay `±delta [target]` + thumbnail, no seek until release; item with
and without trickplay; remote/transcoded; vertical + scrubbar still work.

---

## Notes
- Items **2, 3, 4, 5** are clean **upstream PR candidates** (⬆) — general-benefit, small. Consider
  PRing them to Moonfin so you don't carry them as fork-only patches.
- Suggested build sequence follows the priority order above; **1A first** (smallest + highest value).
