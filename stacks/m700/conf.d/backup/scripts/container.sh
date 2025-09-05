wait_for() {
  local name=$1
  local desired_state=$2
  local retries=12

  while (( retries > 0 )); do
    state=$(curl -s --unix-socket /var/run/docker.sock "http://localhost/containers/$name/json" | jq -r '.State.Status')
    if [[ "${state}" == "${desired_state}" ]]; then
      break
    fi

    ((retries--))
    if (( retries == 0 )); then
       exit 3
    fi

    sleep 5
  done
}

start_container() {
  local name=$1

  "${curl_cmd}" --unix-socket /var/run/docker.sock -X POST http://localhost/containers/"${name}"/start

  wait_for ${name} "running"
}

stop_container() {
  local name=$1

  "${curl_cmd}" --unix-socket /var/run/docker.sock -X POST http://localhost/containers/"${name}"/stop

  wait_for ${name} "exited"
}
