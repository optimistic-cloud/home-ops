FROM caddy:builder@sha256:10ed0251c5cd1dbb4db0b71ad43121147961a51adfec35febce2c93ea25c24f4 AS builder

RUN xcaddy build --with github.com/caddy-dns/cloudflare --with github.com/mholt/caddy-l4

FROM caddy:2.11.2@sha256:1e40b251ca9639ead7b5cd2cedcc8765adfbabb99450fe23f130eefabf50f4bc

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
