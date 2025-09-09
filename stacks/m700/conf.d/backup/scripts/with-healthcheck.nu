export def main [hc_slug: string, run_id: string, operation: closure] {
  let url = $"https://hc-ping.com/($env.HC_PING_KEY)/($hc_slug)"
  let timeout = 10sec

  try {
    http get $"($url)/start?create=1&rid=($run_id)" --max-time $timeout | ignore
    do $operation
    http get $"($url)?rid=($run_id)" --max-time $timeout | ignore
  } catch {|err|
    http get $"($url)/fail?rid=($run_id)" --max-time $timeout | ignore
    log error $"Error: ($err)"
    error make $err
  }
}

export def logs-to-hc [hc_slug: string, run_id: string] {
    let url = $"https://hc-ping.com/($env.HC_PING_KEY)/($hc_slug)?rid=($run_id)"
    let timeout = 10sec

    #$in | collect | http post $"($url)" --max-time $timeout | ignore
    # $in | describe | print
    $in | to nuon | http post $"($url)" --max-time $timeout | ignore
}