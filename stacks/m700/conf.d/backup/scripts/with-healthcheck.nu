const timeout = 10sec

def process_exit_code [url: record]: record -> nothing {
    let exit_code = $in.exit_code
    let stdout = $in.stdout
    let stderr = $in.stderr

    def logs-to-hc [] {
        let url = $url | update path { [ $in, 'log'] | str join "/" } | url join

        $in | http post $url --max-time $timeout | ignore
    }

    $url | do_ping_with ($exit_code | into string)
    if $exit_code != 0 {
        $stderr | logs-to-hc
        error make { msg: $stderr }
    } else {
        $stdout | logs-to-hc
    }
}

def do_ping_with [ endpoint: string ]: record -> nothing {
    let url = $in
    $url | update path { [ $in, $endpoint] | str join "/" } | url join | http get $in --max-time $timeout | ignore
}

export def main [hc_slug: string, run_id: string, operation: closure] {
  let url = {
      "scheme": "https",
      "host": "hc-ping.com",
      "path": $"($env.HC_PING_KEY)/($hc_slug)",
      "params":
      {
          create: 1,
          rid: $run_id
      }
  }

  try {
    $url | do_ping_with 'start'

    let out = do $operation
    $out | process_exit_code $url
  } catch {|err|
    $url | do_ping_with 'fail'

    log error $"Error: ($err)"
    error make $err
  }
}
