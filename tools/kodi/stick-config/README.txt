Files that live on the CoreELEC stick (10.0.10.124), kept here so the setup can be rebuilt.
- back-stops-video.xml -> /storage/.kodi/userdata/keymaps/   (Back stops full-screen video; then `kodi-send --action=reloadkeymaps`)
- mainmenu.DATA.xml -> /storage/.kodi/addons/skin.arctic.zephyr.mod/shortcuts/   (then delete userdata/addon_data/script.skinshortcuts/*.hash, restart kodi)
- remote.conf -> /storage/.config/remote.conf   (IR keymap, reboot)
- Time zone: echo TIMEZONE=Asia/Kolkata > /storage/.cache/timezone; systemctl restart tz-data
- Playlists: tools/kodi/gen_playlists.py
