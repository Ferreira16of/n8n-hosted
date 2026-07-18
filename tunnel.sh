#!/bin/bash
# Mantem um tunel localhost.run apontando para o n8n (porta 5678).
# A URL publica muda a cada reconexao (tunel anonimo) e fica em TUNNEL_URL.txt.
cd "$(dirname "$0")"
LOG=TUNNEL_URL.txt
: > "$LOG"
while true; do
  ssh -i id_rsa -o StrictHostKeyChecking=no -o ServerAliveInterval=30 \
      -o ExitOnForwardFailure=yes -R 80:localhost:5678 localhost.run >> tunnel_full.log 2>&1
  echo "[tunnel] ssh encerrou, reconectando em 3s..." >> "$LOG"
  sleep 3
done
