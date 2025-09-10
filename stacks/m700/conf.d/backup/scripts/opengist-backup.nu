use with-backup.nu *
use with-docker.nu *
use sqlite-export.nu *

def main [] {
  const app = "opengist"

  let data_dir = '/opt' | path join $app
  let working_dir = '/tmp' | path join $app export

  with-backup $app $working_dir {
    with-docker $app {
        $"($data_dir)/appdata/($app).db" | sqlite export $"($working_dir)/($app).db" | ignore
    }
  }
}
