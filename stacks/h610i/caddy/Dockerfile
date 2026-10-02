FROM caddy:builder@sha256:34466183d881df9a8226caf360ff86fe50456f0971221b127dcb756cf514e1ea AS builder

RUN xcaddy build --with github.com/caddy-dns/cloudflare

FROM caddy:2.11.4@sha256:cb9d71ad83182011b79355cd57692686374bd78d6fe327efe0ff8507da03ab13

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
