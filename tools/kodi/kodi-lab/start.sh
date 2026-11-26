#!/bin/sh
rm -f /tmp/.X0-lock /tmp/.X11-unix/X0
Xvfb :0 -screen 0 1920x1080x24 -nolisten tcp &
sleep 2
x11vnc -display :0 -forever -shared -nopw -quiet -rfbport 5900 &
websockify --web /usr/share/novnc 8595 localhost:5900 &
while true; do kodi --standalone -fs; sleep 3; done
