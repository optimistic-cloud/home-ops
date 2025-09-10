const timeout = 10sec

def process_exit_code [url: record]: record -> nothing {
  let exit_code = $in.exit_code
  let stdout = $in.stdout
  let stderr = $in.stderr

  $exit_code | send_exit_code $url
  if $exit_code != 0 {
      $stderr | send_log $url
  } else {
      $stdout | send_log $url
  }
}

def to_url [endpoint: string]: record -> string { $in | update path { [ $in, $endpoint] | str join "/" } | url join }
def do_get []: string -> nothing { http get $in --max-time $timeout | ignore }
def do_post [url: string]: string -> nothing { $in | http post $url --max-time $timeout | ignore }
def send_start [url: record] { 
    log debug $"Send start ping to ($url.path) with run_id ($url.params.rid)"
    $url | to_url 'start' | do_get
}
export def send_fail [url: record] { 
  log debug $"Send fail ping to ($url.path) with run_id ($url.params.rid)"
  $url | to_url 'fail' | do_get
}
def send_exit_code [url: record]: int -> nothing {
  let exit_code = $in
  log debug $"Send exit code ($exit_code) to ($url.path) with run_id ($url.params.rid)"

  $url | to_url ($exit_code | into string) | do_get
}
def send_log [url: record]: string -> nothing { $in | do_post ($url | to_url 'log') }

export def configure-ping-url [slug: string, run_id: string] {
  {
    "scheme": "https",
    "host": "hc-ping.com",
    "path": $"($env.HC_PING_KEY)/($slug)",
    "params":
    {
      create: 1,
      rid: $run_id
    }
  }
}

export def main [url: record, operation: closure] {
  try {
    send_start $url
    do $operation | process_exit_code $url
  } catch {|err|
    send_fail $url
    error make $err
  }
}
