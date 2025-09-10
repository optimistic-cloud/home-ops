const timeout = 10sec
const url = {
  "scheme": "https",
  "host": "hc-ping.com",
  "path": $"($env.HC_PING_KEY)/($hc_slug)",
  "params":
  {
      create: 1,
      rid: $run_id
  }
}

def process_exit_code []: record -> nothing {
  let exit_code = $in.exit_code
  let stdout = $in.stdout
  let stderr = $in.stderr

  $url | send_exit_code $exit_code
  if $exit_code != 0 {
      $url | send_log $stderr
  } else {
      $url | send_log $stdout
  }
}

def to_url [endpoint: string]: record -> string { $in | update path { [ $in, $endpoint] | str join "/" } | url join }
def do_get []: string -> nothing { http get $in --max-time $timeout | ignore }
def do_post [ body: string ]: string -> nothing {
  let url = $in
  $body | http post $url --max-time $timeout | ignore 
}
def send_start []: record -> nothing { $in | to_url 'start' | do_get }
def send_fail []: record -> nothing { $in | to_url 'fail' | do_get }
def send_exit_code [exit_code: int]: record -> nothing { $in | to_url ($exit_code | into string) | do_get }
def send_log [log: string]: record -> nothing { $in | to_url 'log' | do_post $log }

export def main [hc_slug: string, run_id: string, operation: closure] {
  try {
    $url | send_start
    do $operation | process_exit_code
  } catch {|err|
    $url | send_fail

    log error $"Error: ($err)"
    error make $err
  }
}
