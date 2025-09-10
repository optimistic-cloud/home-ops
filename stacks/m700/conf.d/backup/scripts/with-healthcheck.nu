def process_exit_code [hc_slug: string, run_id: string]: record -> nothing {
    let exit_code = $in.exit_code
    let stdout = $in.stdout
    let stderr = $in.stderr

    def logs-to-hc [] {
        let url = $"https://hc-ping.com/($env.HC_PING_KEY)/($hc_slug)/log?rid=($run_id)"
        let timeout = 10sec
    
        $in | http post $"($url)" --max-time $timeout | ignore
    }
    
    def exit-status-to-hc [] {
        let url = $"https://hc-ping.com/($env.HC_PING_KEY)/($hc_slug)"
        let timeout = 10sec
    
        http get $"($url)/($in)?rid=($run_id)" --max-time $timeout | ignore
    }

    $exit_code | exit-status-to-hc
    if $exit_code != 0 {
        $stderr | logs-to-hc
        error make { msg: $stderr }
    } else {
        $stdout | logs-to-hc
    }
}

export def main [hc_slug: string, run_id: string, operation: closure] {
  let url = {
      "scheme": "https",
      "host": "hc-ping.com",
      "path": $"($env.HC_PING_KEY)/($hc_slug)"
  }

  #let url = $"https://hc-ping.com/($env.HC_PING_KEY)/($hc_slug)"
  let timeout = 10sec

  try {
    $url | update path { [ $in, 'start'] | str join "/" } | insert params { create:1, rid:$run_id } | url join | print
    $url | update path { [ $in, 'start'] | str join "/" } | insert params { create:1, rid:$run_id } | url join | http get $in --max-time $timeout | ignore
    #http get $"($url)/start?create=1&rid=($run_id)" --max-time $timeout | ignore

    let out = do $operation
    $out | process_exit_code $hc_slug $run_id
  } catch {|err|
    http get $"($url)/fail?rid=($run_id)" --max-time $timeout | ignore
    log error $"Error: ($err)"
    error make $err
  }
}
