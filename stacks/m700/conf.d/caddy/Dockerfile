FROM caddy:builder@sha256:d842facfd63b960922e57444ff76fd8f0793a66dfdcf481af8026e1f4e6a39b4 AS builder

RUN xcaddy build --with github.com/caddy-dns/cloudflare --with github.com/mholt/caddy-l4

FROM caddy:2.11.4@sha256:cb9d71ad83182011b79355cd57692686374bd78d6fe327efe0ff8507da03ab13

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
