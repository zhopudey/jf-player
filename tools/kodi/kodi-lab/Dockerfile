FROM debian:trixie
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    kodi kodi-inputstream-adaptive xvfb x11vnc novnc websockify xdotool kodi-eventclients-kodi-send \
    mesa-utils libgl1-mesa-dri fonts-dejavu-core ca-certificates procps tzdata imagemagick x11-apps \
    && rm -rf /var/lib/apt/lists/*
RUN ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html
COPY start.sh /start.sh
RUN chmod +x /start.sh
ENV HOME=/kodi DISPLAY=:0
CMD ["/start.sh"]
