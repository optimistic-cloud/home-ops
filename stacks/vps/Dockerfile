FROM caddy:builder@sha256:aef223d1f943bc12a29a9e0a0a73983aa19a36672daede7507da4201a6b1016a AS builder

RUN xcaddy build --with github.com/caddy-dns/cloudflare

FROM caddy:2.11.4@sha256:cb9d71ad83182011b79355cd57692686374bd78d6fe327efe0ff8507da03ab13

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
