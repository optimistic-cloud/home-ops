help:
    just --list-all

backup app:
    nu {{app}}-backup.nu

backup-with-debug app:
    NU_LOG_LEVEL := debug
    nu {{app}}-backup.nu
