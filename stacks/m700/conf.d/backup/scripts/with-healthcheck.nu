const timeout = 10sec

def to_url [endpoint: string]: record -> string { $in | update path { [ $in, $endpoint] | str join "/" } | url join }
def do_get []: string -> nothing { http get $in --max-time $timeout | ignore }
def do_post [url: string]: string -> nothing { $in | http post $url --max-time $timeout | ignore }
def send_log [url: record]: string -> nothing { $in | do_post ($url | to_url 'log') }
def send_exit_code [url: record]: int -> nothing {
  let exit_code = $in
  log debug $"Send exit code ($exit_code) to ($url.path) with run_id ($url.params.rid)"

  $url | to_url ($exit_code | into string) | do_get
}

export def send_start [url: record] {
  log debug $"Send start ping to ($url.path) with run_id ($url.params.rid)"
  $url | to_url 'start' | do_get
}
export def send_fail [url: record] {
  log debug $"Send fail ping to ($url.path) with run_id ($url.params.rid)"
  $url | to_url 'fail' | do_get
}

export def --env configure-ping-url [slug: string, run_id: string] {
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
  
  $env.BACKUP_CONFIG = $config
}

export def with-ping [operation: closure] {
  let url = $env.BACKUP_CONFIG
  

  let out = do $operation
  print $"==>($out)"

  let url = $url | to_url ($out.exit_code | into string)

  if $out.exit_code != 0 {
      $out.stderr | from json | to json --indent 2 | do_post $url
  } else {
      $out.stdout | from json | to json --indent 2 | do_post $url
  }
}

export def main [operation: closure] {
  let url = $env.BACKUP_CONFIG
  
  send_start $url

  try {
    let out = do $operation
  } catch {|err|
      log error $"Error: ($err)"
      send_fail $url
  }
}
