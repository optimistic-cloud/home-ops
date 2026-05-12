use std/log

def hc-ping [url: string, --logfile: string] {
  if ($logfile | is-empty) {
    ^curl -fsS -m 10 --retry 5 -o /dev/null -X POST $url
  } else {
    ^curl -fsS -m 10 --retry 5 -o /dev/null -X POST $url -H "Content-Type: text/plain" --data-binary $"@($logfile)"
  }
}

def main [--target: string] {
  let hc_url = $"($env.HC_URL)-($target)"
  let run_id = (random uuid)

  let logfile = (^mktemp /tmp/davis-backup-XXXXXX | str trim)

  try {
    hc-ping $"($hc_url)/start?rid=($run_id)&create=1"

    ^just backup {{target}} o+e> $logfile
    ^just forget {{target}} o+e>> $logfile
    ^just check {{target}} o+e>> $logfile
    ^just stats {{target}} o+e>> $logfile

    if (($logfile | path exists) and ((ls $logfile | get size.0) == 0B)) { error make {msg: "Backup failed, log file ($logfile) is empty"}}
    hc-ping $"($hc_url)/0?rid=($run_id)" --logfile $logfile
  } catch { |err|
    log error $"Backup failed: ($err.msg)"
    $err.msg | save --append $logfile
    hc-ping $"($hc_url)/fail?rid=($run_id)" --logfile $logfile
    error make $err
  }
}
