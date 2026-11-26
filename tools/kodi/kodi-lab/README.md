# kodi-lab: Kodi skin/UI sandbox (no TV, no CEC)
Container `kodi-lab` on Unraid .40. Browser: http://10.0.10.40:8595/ (noVNC). JSON-RPC: :8596 (kodi/kodilab).
Build dir on .40: /mnt/cache/appdata/kodi-lab/build (copy of this folder + repository.xbmc.org/addon.xml from xbmc/xbmc Omega).
Data: /mnt/cache/appdata/kodi-lab/home (= $HOME, Kodi profile in .kodi).
Run: docker run -d --name kodi-lab --restart unless-stopped --memory 3g --cpus 4 -e TZ=Asia/Kolkata -e KODI_AE_SINK=NULL \
  -v /etc/localtime:/etc/localtime:ro -v /mnt/cache/appdata/kodi-lab/home:/kodi -p 8595:8595 -p 8596:8080 kodi-lab:local
Set up 2026-11-26: Jellyfin add-on (user rohan, add-on playback mode, 8 libraries, not Cinephage Test TV), SiLVO skin,
91 playlists from gen_playlists.py --host 10.0.10.40 --port 8596. Drive it: kl.sh (rpc / act / shot).
Watched state syncs to rohan's Jellyfin account, so don't play films here.
