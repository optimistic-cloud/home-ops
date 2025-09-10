use with-backup.nu *
use with-docker.nu *
use sqlite-export.nu *

def main [] {
  const app = "opengist"

  let data_dir = '/opt' | path join $app
  let export_dir = '/tmp' | path join $app export

  with-backup $app $export_dir {
    with-docker $app {
        $"($data_dir)/appdata/($app).db" | sqlite export $"($export_dir)/($app).db" | ignore
    }
  }
}
