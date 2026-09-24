# Moonfin (jf-player) — mobile streaming stalls: field report (2026-09-24)

## Status

**Diagnosis only — nothing fixed.** Streaming over cellular failed repeatedly on the evening of
2026-09-24 (20:24–20:54 IST). It was **not the transcoder and not the mobile link**. The player
froze at its start/resume position while segments kept downloading at full speed, and three times
it reported the episode as finished at the moment the server's transcode completed.

⚠️ **This was upstream Moonfin 2.5.1** (release build, User-Agent `Moonfin/2.5.1`), **not a
jf-player build.** Fork `main` reports `2.2.0` and does not contain the `2.5.1` tag. So none of
this fork's changes were running, including `3c090450` (the 2-minute network buffer). Whether
jf-player reproduces any of it is **untested**.

## Setup

- **Client:** upstream Moonfin for Android 2.5.1 on an Android 16 phone, on cellular (Jio).
- **Content:** Naruto (2002) S01E01 + S01E02. DVD 480p, Hi10P H.264 (10-bit x264), FLAC 2.0,
  ASS subs (JA+EN). About 6.8 Mbps source, so both caps below force a transcode
  (`TranscodeReasons=ContainerBitrateExceedsLimit`).
- **Quality:** the "regular" setting = `maxStreamingBitrate=2000000` (1.616 Mbps video + 384 kbps
  AAC). When regular didn't work, the operator switched to 4 Mbps by hand (3.36 Mbps video).
  Every switch restarts the stream (new `PlaySessionId`, new transcode) — that part is by design.
  Each fresh start came back at 2 Mbps. The in-player next-episode at 20:29:52 kept 4 Mbps.
- **Server:** Jellyfin 12.0 (official Docker image). Intel QSV `hevc_qsv` produces HEVC fMP4
  HLS in 3 s segments, so one episode is 467 segments. `EnableThrottling=false`, so a transcode
  runs to the end at full speed: about 10–30 s after a mid-episode seek, about 90 s for a whole
  episode. `EnableSegmentDeletion=false`. The remote bitrate limit is 20 Mbps.

## Ruled out

- **Transcoding:** 21 transcodes, all `hevc_qsv`, 10–16× realtime. Every ffmpeg run exited with
  code 0, and there were no playback or transcode errors in the server log.
- **Bandwidth:** 2.4 GB of segments went to the phone in about 17 minutes, peaking around
  47 Mbps averaged over a minute. The home uplink kept up.
- **Bitrate:** the same 4 Mbps setting froze twice, then played cleanly from the identical
  resume point.
- **Subtitles:** the ASS sidecar (stream index 3) was fetched on every attempt, including the one
  that worked.

## Symptom A — player freezes at the start/resume point while downloading continues

The table below groups segment requests per `PlaySessionId` from the reverse-proxy access log.
Start and stop positions come from Jellyfin's session log. Times are IST.

| start | ep | cap | start pos | outcome | segments pulled |
|---|---|---|---|---|---|
| 20:24:28 | E01 | 2 | resume ~20:50 | **fake-end** at 20:24:43 (see B) | 54 / 38 MB |
| 20:24:46 | E01 | 2 | 0:00 | stopped at 0:01.8 after 5 s | 14 / 9 MB |
| 20:24:52 | E01 | 2 | 0:00, seek → 15:34 | stuck: stopped at 15:35 after 25 s | 180 / 127 MB |
| 20:25:38 | E01 | 4 | resume 15:34 | **fake-end** at 20:26:18 | 169 / 229 MB |
| 20:26:31 | E01 | 2 | 0:00 | switched to 4 after 6 s (at 0:03.9) | 24 / 16 MB |
| 20:26:38 | E01 | 4 | 0:03.9 | **never advanced**: stopped at 0:03.5 about 3 min later | **467/467 — whole episode, 635 MB** |
| 20:29:52 | E02 | 4 | 0:00 | abandoned after ~4 s | 2 |
| 20:30:03 | E01 | 2 | 0:00, seek → 15:49 | **fake-end** at 20:30:47, app auto-started E02 | 185 / 130 MB |
| 20:30:47 | E02 | 2 | 0:00 | reached 3:37.6 after 5 min of wall time, then stopped | 325 (43 re-fetched) / 227 MB |
| 20:35:53 | E02 | 2 | resume 3:37.6 | stopped at 3:37.6 after 18 s | 87 / 61 MB |
| 20:36:14 | E02 | 4 | resume 3:37.6 | **49 s "playing"** (Progress every 5 s), stopped still at 3:37.6 | 255 (to 15:48) / 345 MB |
| 20:38:14 | E02 | 2 | resume 3:37.6 | stopped at 3:37.6 after 6 s | 36 / 25 MB |
| 20:38:24 | E02 | 4 | resume 3:37.6 | **played to the end** (stop at end, 20:54:33) | 400 / 542 MB |

- While frozen, the player kept fetching far ahead: the whole episode (635 MB) at 0:03, and
  about 12 minutes ahead at 3:37.6.
- **Readahead was not bounded.** Upstream 2.5.1 leaves Android at mpv's default
  `demuxer-max-bytes` (150 MiB) and sets no `cache-secs`. Yet a frozen player pulled 635 MB.
  So either something is consuming or discarding demuxed packets while the picture is stuck, or
  the fetching is not going through mpv's forward cache.
- This also means `3c090450`'s premise ("mpv caps read-ahead at cache-secs, default 10 s") did
  not match this build's behaviour. mpv's manual describes the `cache-secs` default as "very
  high", with readahead normally bounded by `demuxer-max-bytes`. Worth re-checking before
  relying on that commit's reasoning.

## Symptom B — false "episode finished" when the server's transcode completes

| ffmpeg exit (transcode done) | client reports "stopped at 23:21" (end) | gap | preceded by |
|---|---|---|---|
| 20:24:42.5 | 20:24:43.0 | 0.5 s | resume at ~20:50 (2 Mbps) |
| 20:26:12.0 | 20:26:18.5 | 6.5 s | resume at 15:34 (4 Mbps) |
| 20:30:47.3 | E02 auto-started 20:30:47.8; E01 stop-at-end logged 20:30:49 | 0.5 s | seek to 15:49 (2 Mbps) |

- In the first case the client immediately requested `PlaybackInfo` with
  `startTimeTicks` = full runtime. It believed its position was the end.
- All three followed a seek/resume start (`-ss`) and happened within seconds of the stream's
  **last segment becoming available**. The position was nowhere near the end.
- **Counter-case:** in the final attempt the transcode finished (~20:39:44) while the player was
  genuinely playing, and there was no fake-end.
- **Working hypothesis:** the app derives "completed" from demuxer/download EOF rather than from
  playback position. That only surfaces when the player is stalled at the moment EOF arrives.
  With server throttling off, EOF arrives 10–30 s after any mid-episode seek.

## Symptom C — data burn

Every restart is a new transcode plus a fresh download from the new session. The 13 attempts
pulled **2.4 GB**, while one clean 4 Mbps pass over both episodes would be about 1.3 GB. On a
daily-capped mobile plan, this alone could get the connection throttled.

## Other client-side findings

- **LAN address used on cellular.** Moonfin's diagnostic report, uploaded via Jellyfin
  `ClientLog/Document` at 20:25:03, contains an uncaught
  `SocketException: Connection timed out` from `NetworkImage`. It was loading an image from the
  server's LAN address while the phone was on cellular. So the app has a LAN URL stored and uses
  it for images. That doesn't block playback, but it's a UI stall source.
- **Missing server plugin.** `/Moonfin/Ping` and `/Moonfin/Games/Libraries` return 404: the app
  expects the server-side Moonfin plugin, which isn't installed.

## Next steps (operator's call — none done)

1. **A/B on cellular:** resume the same episode mid-way in the official Jellyfin Android app. If
   it plays cleanly, the fault is confirmed in Moonfin.
2. **Repro on a jf-player build** (fork `main`: pre-2.5.1 base plus `3c090450`). Does it freeze,
   fake-end, or over-fetch?
3. **Server-side mitigation:** Jellyfin Dashboard → Playback → Transcoding → *Throttle transcodes*
   (currently off). The transcode would then stay a few minutes ahead instead of finishing
   seconds after a seek. That should remove the EOF trigger for Symptom B and stop the
   whole-episode downloads. It will **not** fix Symptom A.
4. **If fixing in the fork:** find where the playback backend decides "completed", and check it
   against position vs duration. The fake-end fires far from the end, exactly when the download
   hits EOF.

## Evidence (not in this repo — raw logs rotate)

- **Jellyfin** (container log dir `/config/log/`): `log_20260924.log`,
  `FFmpeg.Transcode-2026-09-24_20-*.log`, and
  `upload_Moonfin for Android_2.5.1_20260924145509_*.log` (the client's diagnostic report).
  Jellyfin keeps only a few days of logs.
- **Reverse proxy** (Caddy JSON access log, per-request bytes/duration/`PlaySessionId`): size-rotated.
- ⚠️ **This repo is public. Never paste raw access-log lines here.** Their query strings carry
  the Jellyfin API token (`ApiKey=` / `api_key=` / `X-Emby-Token=`). Quote numbers, not lines.
