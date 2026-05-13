use std/log

const name = "wallos"

def hc-ping [url: string, --logfile: string] {
  if ($logfile | is-empty) {
    ^curl -fsS -m 10 --retry 5 -o /dev/null -X POST $url
  } else {
    ^curl -fsS -m 10 --retry 5 -o /dev/null -X POST $url -H "Content-Type: text/plain" --data-binary $"@($logfile)"
  }
}

def workflow-for-target [target: string, ping_url: string] {
  let run_id = (random uuid)

  let logfile = (^mktemp $"/tmp/($name)-backup-XXXXXX" | str trim)

  try {
    hc-ping $"($ping_url)/start?rid=($run_id)&create=1"

    ^just backup $target o+e> $logfile
    ^just forget $target o+e>> $logfile
    ^just check $target o+e>> $logfile
    ^just stats $target o+e>> $logfile

    if (($logfile | path exists) and ((ls $logfile | get size.0) == 0B)) { error make {msg: "Backup failed, log file ($logfile) is empty"}}
    hc-ping $"($ping_url)/0?rid=($run_id)" --logfile $logfile
  } catch { |err|
    log error $"Backup failed: ($err.msg)"
    $err.msg | save --append $logfile
    hc-ping $"($ping_url)/fail?rid=($run_id)" --logfile $logfile
    error make $err
  }
}

def main [target: string, ping_slug: string = "wallos"] {
  let ping_url = $"($env.HC_API)/($ping_slug)-($target)"
  workflow-for-target $target $ping_url
}
