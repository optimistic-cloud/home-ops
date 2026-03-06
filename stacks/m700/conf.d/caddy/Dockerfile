FROM caddy:builder@sha256:d4f984844fc3b867ac88fd814285a38eaaf5b3ecadb9ca1b3b0397182ef60cfe AS builder

RUN xcaddy build --with github.com/caddy-dns/cloudflare

FROM caddy:2.10.2@sha256:c3d7ee5d2b11f9dc54f947f68a734c84e9c9666c92c88a7f30b9cba5da182adb

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
