# Serves the Godot web export (build/web). The stock caddy image serves
# /usr/share/caddy on :80; TLS, compression and headers come from
# caddy-docker-proxy labels on the host.
FROM caddy:2-alpine
COPY build/web/ /usr/share/caddy/
