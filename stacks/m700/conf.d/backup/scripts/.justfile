help:
    just --list-all

backup app:
    nu backup.nu {{app}}

backup-with-debug app $NU_LOG_LEVEL="debug":
    nu {{app}}-backup.nu
