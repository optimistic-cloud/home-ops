BACKUP_DIR=./backup
mkdir $BACKUP_DIR


# docker volume create outline-backup-volume
docker exec outline printenv > $BACKUP_DIR/outline.env
docker stop outline
docker exec outline-postgres printenv > $BACKUP_DIR/outline-postgres.env
docker exec outline-postgres pg_dumpall -U user | gzip > $BACKUP_DIR/pg_dump.sql.gz


# local backup
docker run --rm -it --name \
  outline-restic-backup \
  --env-file backup.env \
  -v ./backup:/backup \
  -v outline_storage-data:/data:ro \
  -v /mnt/data/m700/outline:/mnt/data/m700/outline \
  -v $HOME/.cache/restic:/root/.cache/restic \
  restic/restic:0.18.1 backup /data /backup --host "test-backup"

docker start outline
rm -rf $BACKUP_DIR
# docker volume rm outline-backup-volume