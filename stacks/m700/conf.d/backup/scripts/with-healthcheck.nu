def process_exit_code [hc_slug: string, run_id: string]: record -> nothing {
    let exit_code = $in.exit_code
    let stdout = $in.stdout
    let stderr = $in.stderr

    def logs-to-hc [] {
        let url = $"https://hc-ping.com/($env.HC_PING_KEY)/($hc_slug)/log?rid=($run_id)"
        let timeout = 10sec
    
        $in | http post $"($url)" --max-time $timeout | ignore
    }
    
    def exit-status-to-hc [hc_slug: string, run_id: string] {
        let url = $"https://hc-ping.com/($env.HC_PING_KEY)/($hc_slug)"
        let timeout = 10sec
    
        http get $"($url)/($in)?rid=($run_id)" --max-time $timeout | ignore
    }

    $exit_code | exit-status-to-hc $hc_slug $run_id
    if $exit_code != 0 {
        $stderr | logs-to-hc $hc_slug $run_id
        error make { msg: $stderr }
    } else {
        $stdout | logs-to-hc $hc_slug $run_id
    }
}

export def main [hc_slug: string, run_id: string, operation: closure] {
  let url = {
        "scheme": "https",
        "host": "hc-ping.com",
        "path": $"($env.HC_PING_KEY)/($hc_slug)"
    } | url join


  #let url = $"https://hc-ping.com/($env.HC_PING_KEY)/($hc_slug)"
  let timeout = 10sec

  try {
    http get $"($url)/start?create=1&rid=($run_id)" --max-time $timeout | ignore

    let out = do $operation
    $out | process_exit_code $hc_slug $run_id
  } catch {|err|
    http get $"($url)/fail?rid=($run_id)" --max-time $timeout | ignore
    log error $"Error: ($err)"
    error make $err
  }
}
