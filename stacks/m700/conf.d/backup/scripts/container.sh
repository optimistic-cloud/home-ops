start_container() {
  local name=$1

  "${curl_cmd}" --unix-socket /var/run/docker.sock -X POST http://localhost/containers/"${name}"/start
}

stop_container() {
  local name=$1

  "${curl_cmd}" --unix-socket /var/run/docker.sock -X POST http://localhost/containers/"${name}"/stop
}
