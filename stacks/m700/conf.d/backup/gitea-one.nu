use std/log

use ./lib/with-backup-template-one.nu *
use ./lib/with-docker.nu *
use ./lib/lib.nu *

const app = "gitea"
const container_name = "gitea"

def main [provider_name: string, provider_env_file: path] {
    $app | with-backup-template-one $provider_name $provider_env_file {
        let backup_docker_volume = $in
    
        let dump_location = '/var/lib/gitea'
        let gitea_archive = 'gitea-dump.tar.gz'
    
        # Create gitea-dump.tar.gz
        # https://docs.gitea.com/administration/backup-and-restore
        do {
            # remove old dump, create new dump 
            ^docker exec -u git gitea rm -f $"($dump_location)/($gitea_archive)"
            #^docker exec -u git gitea mkdir -p $dump_location
            (
                ^docker exec -u git gitea /usr/local/bin/gitea
                    dump --work-path /tmp
                    --file $gitea_archive
                    --config /etc/gitea/app.ini
                    --database sqlite3
                    --type tar.gz
            )
        }
    
        # Add contents of gitea-dump.tar.gz to backup volume
        do {
            {
                from_container: $container_name
                paths: [$"($dump_location)/($gitea_archive)"]
            } | extract-files-from-container --volume $backup_docker_volume --sub-path "gitea-dump" {
                let tmp_dir = $in
    
                # gitea.tar.gz
                let archive = $"($tmp_dir)/($gitea_archive)"
    
                # extract in-place and remove the archive
                ^tar -xzf $archive -C $tmp_dir | ignore
                ^rm -f $archive | ignore
    
                $tmp_dir
            }
        }
    
        {
            container_name: $container_name
            volumes: {
                config: $backup_docker_volume
            }
        }
    }
}
