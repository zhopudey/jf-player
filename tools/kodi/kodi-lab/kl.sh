#!/bin/sh
# usage: kl.sh rpc '<json>' | kl.sh shot name | kl.sh act Action
case "$1" in
rpc) ssh root@10.0.10.40 "curl -s -u kodi:kodilab -H 'Content-Type: application/json' -d '$2' http://127.0.0.1:8596/jsonrpc"; echo;;
act) ssh root@10.0.10.40 "curl -s -u kodi:kodilab -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"Input.ExecuteAction\",\"params\":{\"action\":\"$2\"}}' http://127.0.0.1:8596/jsonrpc" >/dev/null;;
bi) ssh root@10.0.10.40 "docker exec kodi-lab kodi-send --action='$2'" >/dev/null 2>&1 || ssh root@10.0.10.40 "curl -s -u kodi:kodilab -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"Addons.ExecuteAddon\"}' http://127.0.0.1:8596/jsonrpc";;
shot) ssh root@10.0.10.40 "docker exec kodi-lab import -window root -resize 50% /tmp/$2.png && docker cp kodi-lab:/tmp/$2.png /tmp/$2.png" && scp -q root@10.0.10.40:/tmp/$2.png /tmp/claude-1000/-home-rohan-repos-jf-player/d5540964-4b4b-43ab-b61d-25222e3acfc9/scratchpad/$2.png && echo ok;;
esac
