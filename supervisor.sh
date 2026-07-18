#!/bin/bash
# Supervisor desacoplado: mantem n8n + 1 tunel localhost.run vivos e ativos.
# - setsid: roda fora da sessao do shell (sobrevive melhor)
# - heartbeat a cada 10s para o tunel NAO dormir (localhost.run mata tunel ocioso)
# - garante chave 600
# - URL atual em TUNNEL_URL.txt
DIR="/workspace/18b65815-c0d1-4e77-99a4-b388a20cdfe1/sessions/agent_ff974ce7-70c7-4c7c-9a2a-27aa396a4e18"
cd "$DIR"

N8N_BIN="$DIR/node_modules/.bin/n8n"
N8N_PORT=5678
URL_FILE="$DIR/TUNNEL_URL.txt"
LOG="$DIR/supervisor.log"

chmod 600 "$DIR/id_rsa" 2>/dev/null
set -a; source "$DIR/.env"; set +a

tunnel_pid=0
tunnel_running() { [ "$tunnel_pid" -gt 0 ] && kill -0 "$tunnel_pid" 2>/dev/null; }

start_tunnel() {
  [ "$tunnel_pid" -gt 0 ] && kill "$tunnel_pid" 2>/dev/null
  pkill -f "ssh -i $DIR/id_rsa" 2>/dev/null
  sleep 2
  chmod 600 "$DIR/id_rsa" 2>/dev/null
  nohup ssh -i "$DIR/id_rsa" -o StrictHostKeyChecking=no -o ServerAliveInterval=10 \
      -o ServerAliveCountMax=2 -o ExitOnForwardFailure=yes \
      -R 80:localhost:$N8N_PORT localhost.run >> "$DIR/tunnel_full.log" 2>&1 &
  tunnel_pid=$!
  sleep 10
  grep -oE 'https://[a-z0-9]+\.lhr\.life' "$DIR/tunnel_full.log" | tail -1 > "$URL_FILE"
  echo "[super] tunel pid=$tunnel_pid url=$(cat "$URL_FILE")" >> "$LOG"
}

# n8n
nohup "$N8N_BIN" start >> "$DIR/n8n.log" 2>&1 &
echo $! > "$DIR/n8n.pid"
echo "[super] n8n iniciado pid=$!" >> "$LOG"
for i in $(seq 1 40); do
  curl -s -o /dev/null http://localhost:$N8N_PORT/healthz && break
  sleep 2
done

start_tunnel

while true; do
  if ! curl -s -o /dev/null http://localhost:$N8N_PORT/healthz; then
    echo "[super] n8n caiu, reiniciando" >> "$LOG"
    nohup "$N8N_BIN" start >> "$DIR/n8n.log" 2>&1 &
    echo $! > "$DIR/n8n.pid"
  fi

  if ! tunnel_running; then
    echo "[super] tunel morto, reiniciando" >> "$LOG"
    start_tunnel
  else
    URL=$(cat "$URL_FILE" 2>/dev/null)
    if [ -n "$URL" ]; then
      # heartbeat: mantem o tunel acordado
      if curl -s -o /dev/null "$URL/healthz"; then
        :
      else
        echo "[super] tunel 503, reiniciando" >> "$LOG"
        start_tunnel
      fi
    fi
  fi

  sleep 10
done
