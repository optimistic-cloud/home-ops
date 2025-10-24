FROM caddy:builder@sha256:e8ec35d0787c123c0776d5e22570f2eeba76a730390104113554c271c40d2aeb AS builder

RUN xcaddy build --with github.com/caddy-dns/cloudflare

FROM caddy:latest@sha256:9e95012adcbbd599f853cb315b986781845c238f9e52aa3652798758cca01422

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
