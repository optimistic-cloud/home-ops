docker stop $DOCKER_CONTAINER

# export env vars
docker exec $DOCKER_CONTAINER printenv > $BACKUP_DIR/outline-postgres.env

# backup postgres database
docker exec $DOCKER_CONTAINER pg_dumpall -U user | gzip > $BACKUP_DIR/pg_dump.sql.gz

# export sqlite database
docker exec -i $DOCKER_CONTAINER sh -c 'sqlite3 /path/to/app.db ".dump"' > $BACKUP_DIR/backup.sql

docker start $DOCKER_CONTAINER