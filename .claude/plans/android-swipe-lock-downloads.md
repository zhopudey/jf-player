# Moonfin (jf-player) — Android build: swipe-seek, lock button, downloads overhaul

## Status (2026-08-24)

Plan verified against current `main` — every file/line reference below (video_player_screen.dart, download_service.dart, aggregated_item.dart, item_detail_view_model.dart, item_detail_screen.dart, user_preferences.dart, video_playback_screen.dart, saved_season_screen.dart, saved_series_screen.dart, playback_manager.dart) matched exactly or within a few lines of drift. No rebasing needed — implementable as written.

Progress:
- **Feature 1 (horizontal swipe-to-seek): implemented and built.** `onHorizontalDragStart/Update/End/Cancel` added to the root `GestureDetector` in `video_player_screen.dart`, mirroring the existing vertical-drag gating pattern. New state: `_hSeekStartX`, `_hSeekStartPosition`, `_hSeekPreviewTarget`, `_isHorizontalSeeking`, `_hSeekIgnored`. Preview-only during drag, commits via `_manager.seekTo(...)` on drag end. New `_buildHorizontalSeekOverlay()` reuses the existing trickplay thumbnail helper. Seekbar guard implemented geometrically: a `GlobalKey` (`_seekbarKey`) attached to the seekbar's `Focus` widget, checked via `RenderBox.localToGlobal`/`Rect.contains` in `_isWithinSeekbarHitBand()` (plan only specified the requirement, not the mechanism — this was the implementation choice made to satisfy it), and only consulted while `_controlsVisible`.
- **Feature 2 (lock button): implemented and built.** Pref gate dropped from the lock button (always visible on mobile UI), auto-lock-on-idle removed from `_scheduleHide()`, locked overlay reduced to a circular tap-to-unlock `Icons.lock_open` in the **bottom-left** corner, `UserPreferences.osdLockEnabled` and its settings row deleted.
- **Feature 3 (downloads overhaul): implemented and built (2026-08-24).** Built as planned except
  where noted under "Deviations from the plan in Feature 3" below. Selection widgets landed in
  `lib/ui/widgets/selection/`, the picker in `lib/ui/screens/downloads/download_picker_screen.dart`,
  select-mode + bulk delete in both saved-media screens. `flutter analyze lib` 0 errors, APK built
  and installed to the Pad; **on-device behaviour not yet confirmed by the operator.**
- **Offline-first playback (added mid-session at operator request, not in the original plan).**
  `OfflineFirstStreamResolver` + `OfflineAwarePlayerService` wrap the server resolver/player service
  in `playback_module.dart:setActiveStreamResolver`, so a downloaded copy plays instead of streaming
  at *every* entry point (Play, Continue Watching, episode rows, autoplay-next, queue) with no
  call-site changes, and local progress reaches Jellyfin live when reachable / via the existing
  `SyncService` on reconnect when not. The separate "Play offline" button is gone for video/audio;
  books keep theirs. Operator decision: **local always wins, no "stream instead" escape hatch** —
  he downloads originals, so streaming the same 50-100 GB file to a tablet is never wanted.
  Known gap: local playback leaves `PlaybackManager._isOfflinePlayback` false, so trickplay and
  chapter images are still fetched from the server (invisible online, they simply don't load when
  fully offline).

### Deviations from the plan in Feature 3

1. **The plan's claim that no multi-select pattern exists is wrong.**
   `storage_management_screen.dart:109-265` already has select-mode + checkbox rows + bulk delete,
   and the strings `selectAll`, `itemsSelected`, `deleteSelected`, `deleteSelectedCount`,
   `unwatched` all exist. The new widgets follow that idiom and added **zero** l10n strings, so no
   generated `app_localizations_*.dart` file was touched.
2. **Selection happens before the quality sheet**, not after, so the sheet's size estimates
   describe the actual selection. `_showQualityPicker` was split into `_openDownloadPicker` +
   a reusable `_showQualitySheet`.
3. **`SelectableEpisodeList` takes a presentation entry, not an `AggregatedItem`**, because the
   delete side works with Drift `DownloadedItem` rows and local thumbnails while the picker works
   with server items and `CachedNetworkImage`.
4. **Already-downloaded episodes are badged and left unticked** in the picker (queried via
   `OfflineRepository.getSeriesEpisodes`) — not in the plan, but it is what makes "top up the
   tablet" a single confirm.
5. **`saved_series_screen` deletes via `deleteDownloadedItems` over the selected episodes**, not by
   deleting a Season item — the season rows there are synthesised from grouped episodes, and the
   Episode delete path already prunes emptied season/series rows and their images.

### Rewritten from scratch 2026-08-24

The Feature 1 code described in the previous revision of this file was **never committed** — that
session wrote it on the Windows laptop and only the plan doc reached `main`. It was reimplemented
fresh from this plan rather than recovered.

### Verified this session (2026-08-24)

Built on **harihara LXC 337 / `10.0.10.37`** (`flutterdev`, Debian 13, Flutter 3.44.1 matching
`FLUTTER_VERSION` in `.github/workflows/build.yml`), deployed to the OnePlus Pad 2 over wireless
adb. `flutter analyze` clean on all changed files; `flutter build apk --flavor mobile-beta --debug`
exit 0; installs and launches without fatals. **Gesture/UI behaviour confirmed working on-device by
the operator (2026-08-24)**; both features merged to `main` the same day.

Use the **`mobile-beta`** flavor for dev builds (`applicationId org.moonfin.androidtv.beta`): it
installs alongside the production app instead of forcing an uninstall, which would wipe the
device's downloaded media. Launcher activity stays `org.moonfin.androidtv.MainActivity` even for
the beta package.

### Deliberate deviations from this plan

1. **`longPressToUnlock` localization string kept.** The plan called for dropping it; it lives in
   ~70 *generated* `lib/l10n/app_localizations_*.dart` files under Weblate management, so
   hand-deleting it would be merge-hostile for negligible gain. Unused string left in place.
2. **`AnimatedOpacity` added to `_buildLockedOverlay()`.** The plan assumed tapping a locked screen
   already reveals/hides the pill via `_controlsVisible`; it does not — the original only wrapped it
   in `IgnorePointer`, which gates *touch*, not visibility, so the pill sat on the video
   permanently. Opacity gating is what actually delivers the plan's stated "tap-to-reveal" design.

## Context

Three UX gaps borrowed from Findroid (the native Android Jellyfin client), to be built and then compiled as an Android-only release build:

1. No horizontal-swipe seek gesture on the player — only tap-side double-tap skip and vertical-swipe brightness/volume exist today.
2. A lock feature already exists in the player but is buried behind an opt-in settings toggle (`osdLockEnabled`), mobile-only, and unlocked via a "long-press" text pill — it should just be a button that's always there, unlocked by tapping a small icon (Findroid-style).
3. Downloads only support "download everything in this season/series right now" with no way to filter to unwatched episodes or hand-pick individual episodes/seasons — and there's no bulk-delete UI at all, just per-item long-press delete.

**Hard constraint (explicitly confirmed by user): the actual download engine — the isolate-based background downloader, WiFi-only policy, progress notifications, Drift-backed offline DB — is not touched.** All Feature 3 work is new selection/filter UI that calls the existing `DownloadService.downloadItems(...)` and `DownloadService.deleteDownloadedItems(...)` (already present, the latter currently unused by any UI).

Confirmed decisions from user:
- Lock button: always visible on mobile UI, no settings gate.
- Unlock: tap-to-reveal small icon (not long-press pill).
- Downloads multi-select: works at both season level (episodes) and series level (seasons), for both download and delete.

---

## Feature 1: Horizontal swipe-to-seek

**File:** `lib/ui/screens/playback/video_player_screen.dart`

- Root `GestureDetector` (line 3338) already wires separate `onVerticalDragStart/Update/End/Cancel` (3348-3367, each gated `PlatformDetection.useMobileUi && !_isOsdLocked`) alongside `onDoubleTapDown`/`onTap`. Flutter allows a `HorizontalDragGestureRecognizer` to coexist with a `VerticalDragGestureRecognizer` on the same detector (arena resolves by dominant axis) — add `onHorizontalDragStart/Update/End/Cancel` right after the vertical block, same ternary gating pattern. Do not use `onPanUpdate` (would conflict with the existing separate vertical handlers).
- New fields near `_isOsdLocked` (143): `double? _hSeekStartX`, `Duration? _hSeekStartPosition`, `Duration? _hSeekPreviewTarget`, `bool _isHorizontalSeeking = false`.
- `_onHorizontalDragStart`: record start X and `_state.position`.
- `_onHorizontalDragUpdate`: `deltaX = details.localPosition.dx - _hSeekStartX!`. Sensitivity scaled to content length so a full-width swipe covers a sensible range of the video, e.g. `msPerPixel = (durationSeconds*1000/screenWidth).clamp(150, 2000)`; compute `target = (_hSeekStartPosition + Duration(ms: deltaX*msPerPixel)).clamp(0, duration)`; `setState(() { _isHorizontalSeeking = true; _hSeekPreviewTarget = target; })`. Do not call `_manager.seekTo` per-frame — only update the preview.
- `_onHorizontalDragEnd`: if seeking, call `_manager.seekTo(_hSeekPreviewTarget!)` (`PlaybackManager.seekTo`, `packages/playback_core/lib/src/playback_manager.dart:1562`), reset state, `_showControls()`.
- New overlay `_buildHorizontalSeekOverlay()` (placed near `_buildDoubleTapSkipOverlay`, ~5440): centered pill with target time + signed delta, reusing the existing trickplay thumbnail helper `_buildSeekPreviewThumbnail`/`_getTrickplayTile` (4179-4201) exactly as the seekbar `Slider` (4278) already does. Render only `if (_isHorizontalSeeking)`, wired into the Stack alongside the existing double-tap overlay (~3410-3416).
- Guard: reject drags that start within the bottom seekbar's hit band (mirror however the Slider already avoids being swallowed by the parent detector for taps) so users can still scrub the Slider directly without triggering a swipe-seek.

## Feature 2: Lock button — always-on, tap-to-unlock

**File:** `lib/ui/screens/playback/video_player_screen.dart` (all existing infrastructure, no new timers needed — `_showControls()`/`_scheduleHide()`/`_controlsVisible` already implement "reveal briefly, auto-hide after 8s on mobile", confirmed at lines 2571-2598).

1. Lock button (currently gated at 3849-3850 by `PlatformDetection.useMobileUi && _prefs.get(UserPreferences.osdLockEnabled)`) → drop the preference check, keep just `PlatformDetection.useMobileUi`. Body (3852-3857) unchanged: sets `_isOsdLocked = true`, hides controls.
2. Remove the auto-lock-on-idle side effect in `_scheduleHide` (2508-2511: `if (PlatformDetection.isMobile && _prefs.get(osdLockEnabled)) { _isOsdLocked = true; }`) — locking should only happen via explicit button tap, not automatically after controls idle-hide (Findroid's lock is manual-only; auto-locking a video the user never locked would be a surprising new behavior nobody asked for).
3. `_buildLockedOverlay()` (5506-5562): keep the outer `GestureDetector.onTap: _showControls` as-is — tapping the locked screen already reveals the pill via existing `_controlsVisible`/`_scheduleHide` machinery, auto-hiding again on the same 8s timer. Only change the **inner** pill:
   - Replace `onLongPress` (5516) with `onTap` calling the unlock action: `setState(() { _isOsdLocked = false; _controlsVisible = true; }); _scheduleHide();`
   - Replace the icon+text Row (5537-5554, `Icons.lock` + `l10n.longPressToUnlock`) with a plain centered circular tap target showing `Icons.lock_open` (or keep `Icons.lock`), no text — matches Findroid's small unlock icon.
4. Dead code cleanup: remove `UserPreferences.osdLockEnabled` (`lib/preference/user_preferences.dart:1467-1470`) and its settings row (`lib/ui/screens/settings/panel/video_playback_screen.dart:113-119`) — confirm no other references before deleting. Drop the now-unused `longPressToUnlock` localization string if nothing else uses it.

## Feature 3: Downloads overhaul — season/series multi-select, unwatched filter, shared with delete

Existing pieces to reuse as-is (no changes): `DownloadService.downloadItems(List<AggregatedItem>, {quality})` (download_service.dart:1561), `DownloadService.deleteDownloadedItems(List<AggregatedItem>)` (1657, currently dead code — this becomes its first real caller), `AggregatedItem.isPlayed` (aggregated_item.dart:86) for the unwatched filter, `ItemDetailViewModel.episodes`/`seriesEpisodes`/`seasons` (item_detail_view_model.dart) as the data source, `OfflineRepository.watchSeasonEpisodes`/`deleteSeasonItems` for the downloaded-side screens.

There is no existing checkbox/multi-select pattern anywhere in the app — build one new small reusable piece rather than bespoke UI per screen:

- **New:** `lib/ui/widgets/selection/selectable_list_controller.dart` — `SelectableListController extends ChangeNotifier` with `Set<String> selectedIds`, `bool selectMode`, `toggle(id)`, `selectAll(ids)`, `clear()`, `enterSelectMode()`/`exitSelectMode()`, `isSelected(id)`. Plain `ChangeNotifier` (not Riverpod-specific) so it works both from the non-Riverpod `item_detail_screen.dart` and the Riverpod-based `saved_season_screen.dart`/`saved_series_screen.dart`, via `ListenableBuilder`.
- **New:** `lib/ui/widgets/selection/selectable_episode_list.dart` — checkbox-per-row episode list: header "Select all", a `FilterChip` "Unwatched only" (download mode only — toggling it filters visible rows using `isPlayed` and adjusts default-checked state, it doesn't permanently hide anything so users can turn it back off), bottom bar with selected count + confirm button. Reuses `DetailEpisodeCard`'s row layout (thumbnail/title/runtime) with a leading `Checkbox` added.
- **New:** `lib/ui/widgets/selection/selectable_season_list.dart` — same shape, one row per season (label + episode count from `viewModel.seasons`); each row expands (`ExpansionTile`) to a nested `SelectableEpisodeList` for that season, so series-level picking supports both whole-season and individual-episode selection sharing one controller.
- **New screen:** `lib/ui/screens/downloads/download_picker_screen.dart` — for `item.type == 'Season'`, shows `SelectableEpisodeList` over `viewModel.episodes`; for `'Series'`, shows `SelectableSeasonList` over `viewModel.seasons` + `viewModel.seriesEpisodes` (grouped client-side by `parentIndexNumber`, same grouping `saved_series_screen.dart` already does — no new repository query needed). On confirm: flatten selection to `List<AggregatedItem>`, run the existing quality picker, then `DownloadService.downloadItems(selected, quality:)`.
- **Trigger:** `item_detail_screen.dart`'s `_startDownload` (9350-9390) — for the `'Season'` (9363-9373) and `'Series'` (9374-9375) cases, navigate to `DownloadPickerScreen` instead of calling `downloadItems`/`downloadSeries` directly. `'Movie'/'Episode'/'Audio'/'AudioBook'/'Book'/'BoxSet'` cases (9357-9362, 9376-9377) are unchanged — single-item/box-set download flow stays as-is.
- **Delete side, `saved_season_screen.dart`:** add a "Select" toggle that switches the existing `ListView.builder`/`_EpisodeRow` list into `SelectableEpisodeList` (delete mode: no unwatched chip, nothing pre-checked). Long-press on a row (currently triggers a single delete confirm) instead enters select mode with that item pre-checked (Findroid-style). Confirm calls `DownloadService.deleteDownloadedItems(selected)`.
- **Delete side, `saved_series_screen.dart`:** same pattern with `SelectableSeasonList`; route its confirm action through `DownloadService.deleteDownloadedItems`/`deleteDownloadedFiles` as well (rather than this screen's current direct file/DB deletion at lines ~250-291) so both download-picker and delete-picker end up calling the same service methods — one deletion code path instead of two.

**No changes to:** `download_service.dart`'s isolate/queue/progress internals, `offline_database.dart` schema, WiFi-only/storage-limit checks, notification service.

---

## Verification (Android build)

1. `flutter analyze` — should be clean (existing `analysis_options.yaml` lint rules).
2. `flutter pub get` if any new imports require it (none of the new widgets need new packages — Checkbox/FilterChip/ExpansionTile are all Flutter SDK).
3. Build: run `./build-android.sh` (or `.\build-android.ps1` on native Windows) to produce the Android artifact — confirm this is the intended build entrypoint before running it, since it's a repo-provided script, not a bare `flutter build apk`.
4. Manual pass on a device/emulator:
   - Player: play a video, swipe left/right to confirm seek preview + commit; confirm double-tap skip and vertical brightness/volume swipes still work unaffected; tap the lock icon, confirm controls disappear and gestures are inert; tap the locked screen, confirm the small unlock icon appears and auto-hides after ~8s if untouched; tap it to unlock.
   - Downloads: from a Series detail page, start "Download" → picker shows seasons, expand one → episodes with checkboxes, toggle "Unwatched only", confirm only unwatched pre-checked; download a partial selection and confirm only those episodes download (existing download mechanism, unmodified). From the Downloads tab, enter select mode on a downloaded season, delete a subset, confirm files + DB rows are removed via `deleteDownloadedItems`.

---

## Environment errors found this session (2026-08-24)

Toolchain checkout (`flutter doctor -v`) never completed successfully in this environment despite ~1.5 hours of troubleshooting. Recorded here so it isn't re-discovered from scratch next time.

**1. Corrupted local Pub cache (root cause: fixed).**
`%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\...` contained ~25+ packages whose cached `pubspec.yaml`/`.dart` files were pure `0x00` bytes instead of real content (`checked_yaml-2.0.4`, `test-1.31.1`, `vm_service_interface-2.0.1`, `dart_service_protocol_shared-0.0.3/lib/src/client.dart`, and others). This broke `flutter_tools`' own `dart pub upgrade` — every `flutter` command failed with a misleading error (`flutter_tools depends on test 1.31.1 which doesn't match any versions`), and `dart pub cache repair` silently skipped the corrupted entries (it can't read a name/version from a garbled pubspec, so it doesn't know to reinstall it). Fix: manually scan for and delete null-byte-only files under the Pub cache, forcing a redownload. Suspected cause: Windows Defender and/or Malwarebytes real-time scanning interfering with Pub's rapid burst of small file writes during package extraction.

**2. Same corruption recurred after adding AV exclusions.**
User added Defender exclusions for `C:\src\flutter`, the Pub cache, and the project's `build` dir. The *specific* null-byte corruption pattern did not reappear in a post-fix scan, but `dart_service_protocol_shared/src/client.dart` corrupted again on a later redownload with the identical crash signature (`Crash when compiling package:dart_service_protocol_shared/src/client.dart` → `Out of Memory` inside `LibraryProblemReporting.addProblem`/`SourceLoader.tokenize`). Root cause not fully resolved — either Malwarebytes exclusions weren't added (only Defender was confirmed), or there's a second interfering process. Whenever this recurs, the fix is the same: find and delete the null-byte file(s) under the Pub cache and retry.

**3. Machine is memory-constrained for this build (separate, real issue).**
This machine has 15.8GB total RAM. Building the `flutter_tools` kernel snapshot (a one-time cost after any SDK/dependency change) drove `dartvm.exe` to 10-16GB resident, repeatedly pushing system free memory to <0.5GB. This is independent of the corruption bug above — even a corruption-free attempt reached ~16GB before completing or crashing. Two attempts were manually killed to avoid destabilizing the whole system (not just the build). **Recommendation: do toolchain bootstrap / first builds on a machine with more headroom (user mentioned "harihara", 32GB RAM) rather than this one.** Once `flutter_tools.snapshot` exists on disk, subsequent `flutter` invocations reuse it and don't repeat this cost — the expensive part is one-time.

**4. Operational gotcha: `TaskStop` does not reliably kill native child processes.**
Stopping a background Bash task that wraps `cmd.exe`/`flutter.bat`/`dart.exe` only stops the tracked wrapper — the actual Windows process tree can survive as an orphan and keep running (and keep writing to the Pub cache), racing with any subsequent attempt. Confirmed via `Get-CimInstance Win32_Process` parent/child tracing. Always verify no `dart.exe`/`dartvm.exe`/`flutter.bat` processes remain (via PowerShell, not just the harness's task status) before retrying after a stop/kill.

**Net effect:** Dart/Flutter code was written and reasoned about correctly this session (Feature 1), but nothing was compiled, analyzed, or run. Treat Feature 1's implementation as unverified until `flutter analyze` and a real build succeed.
