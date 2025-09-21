# m700 stack

## Applications

### Pocket ID

- https://id.optimistic.cloud/setup

### Gitea

Add oidc from cli

Gitea: docker exec -it gitea /bin/bash
Gitea: gitea admin auth add-oauth \
        --name "Optimistic Cloud" \
        --provider openidConnect \
        --key   "<key>" \
        --secret "<secret>" \
        --auto-discover-url "https://id.optimistic.cloud/.well-known/openid-configuration" \
        --scopes "openid,email,profile"