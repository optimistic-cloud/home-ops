help:
    just --list

backup app:
    nu {{app}}-backup.nu 

backup-with-debug app $NU_LOG_LEVEL="debug":
    nu {{app}}-backup.nu

restore app:
    nu {{app}}-backup.nu restore

restore-with-debug app $NU_LOG_LEVEL="debug":
    nu {{app}}-backup.nu restore
