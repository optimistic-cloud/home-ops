  #!/usr/bin/env bash
  set -eoux pipefail

  export_path="${EXPORT_DATA:?EXPORT_DATA is required}"

  rm -rf "${export_path}"