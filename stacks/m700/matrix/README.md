```
# Generate homeserver.yaml
docker run -it --rm \
    -v "matrix_synapse-data:/data" \
    -e SYNAPSE_SERVER_NAME=matrix.example.com \
    -e SYNAPSE_REPORT_STATS=no \
    matrixdotorg/synapse:latest generate
```

add `enable_registration: false` to homeserver.yaml