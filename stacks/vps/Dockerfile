FROM caddy:builder@sha256:01668408cc26e2e00c9d067c30cb43b2ba14ad1f2808beda55503cb2a31f59dc AS builder

RUN xcaddy build --with github.com/caddy-dns/cloudflare

FROM caddy:2.11.2@sha256:261437d35b88cc2f8fa1ed337ebb6b6ce2bd5cd61b2a28cdf83cb201db0a853b

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
