FROM caddy:builder@sha256:3db11aead97f1fdff9c563d0dd8e7fba2e4c7031bef40f3e44fd1982f3e8366b AS builder

RUN xcaddy build --with github.com/caddy-dns/cloudflare --with github.com/mholt/caddy-l4

FROM caddy:2.11.4@sha256:cb9d71ad83182011b79355cd57692686374bd78d6fe327efe0ff8507da03ab13

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
