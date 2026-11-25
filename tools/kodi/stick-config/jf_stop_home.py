# Home during playback: stop (Kodi saves the resume point), then go to the Home screen.
import xbmc

player = xbmc.Player()
player.stop()
monitor = xbmc.Monitor()
for _ in range(50):  # up to 5 s
    if not player.isPlaying() or monitor.waitForAbort(0.1):
        break
xbmc.executebuiltin("ActivateWindow(Home)")
