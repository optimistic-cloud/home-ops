```
# Generate homeserver.yaml
docker run -it --rm \
    -v "matrix_synapse-data:/data" \
    -e SYNAPSE_SERVER_NAME=matrix.example.com \
    -e SYNAPSE_REPORT_STATS=no \
    matrixdotorg/synapse:latest generate
```

add `enable_registration: false` to homeserver.yaml

- https://element-hq.github.io/matrix-authentication-service/setup/sso.html
- https://github.com/element-hq/matrix-authentication-service
- https://github.com/wlphi/ess-docker-compose/blob/main/docker-compose.yml
- https://element-hq.github.io/synapse/latest/turn-howto.html
