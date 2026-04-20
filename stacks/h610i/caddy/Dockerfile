FROM caddy:builder@sha256:c54715e63a99f6bc427f6733749b71dd48fc036f9c4fcda10aa29fb278518ee0 AS builder

RUN xcaddy build --with github.com/caddy-dns/cloudflare

FROM caddy:2.11.2@sha256:25cdc846626b62d05f6b633b9b40c2c9f6ef89b515dc76133cefd920f7dbe562

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
