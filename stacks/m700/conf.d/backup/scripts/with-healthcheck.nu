const timeout = 10sec

def process_exit_code [url: record]: record -> nothing {
    let exit_code = $in.exit_code
    let stdout = $in.stdout
    let stderr = $in.stderr

    def logs-to-hc [] {
        let url = $url | update path { [ $in, 'log'] | str join "/" } | url join
        #let url = $"https://hc-ping.com/($env.HC_PING_KEY)/($hc_slug)/log?rid=($run_id)"


        #http get $in --max-time $timeout | ignore
        $in | http post $url --max-time $timeout | ignore
    }
    
    def exit-status-to-hc [] {
        let exit_code = $in

        $url | update path { [ $in, $exit_code ] | str join "/" } | url join | http get $in --max-time $timeout | ignore
        #let url = $"https://hc-ping.com/($env.HC_PING_KEY)/($hc_slug)"
        
    
        #http get $url --max-time $timeout | ignore
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
      "path": $"($env.HC_PING_KEY)/($hc_slug)",
      "params":
      {
          "rid": $run_id
      }
  }

  #let url = $"https://hc-ping.com/($env.HC_PING_KEY)/($hc_slug)"

  try {
    $url | update path { [ $in, 'start'] | str join "/" } | merge { create: 1 } | url join | http get $in --max-time $timeout | ignore

    let out = do $operation
    $out | process_exit_code $url
  } catch {|err|
    $url | update path { [ $in, 'fail'] | str join "/" } | url join | http get $in --max-time $timeout | ignore

    log error $"Error: ($err)"
    error make $err
  }
}
