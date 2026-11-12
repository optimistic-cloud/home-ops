FROM caddy:builder@sha256:6350162b3889ca32600b3c699c61572fa0eb3ad6b2a51874f19b158a7df77511 AS builder

RUN xcaddy build --with github.com/caddy-dns/cloudflare --with github.com/mholt/caddy-l4

FROM caddy:2.11.4@sha256:cb9d71ad83182011b79355cd57692686374bd78d6fe327efe0ff8507da03ab13

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
