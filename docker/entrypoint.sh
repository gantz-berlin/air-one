#!/usr/bin/env bash
# Runs a dbt command inside the container.
#   no arguments      -> dbt build   (run models + tests)
#   any arguments     -> dbt <args>, e.g. "run --select hello_world"
set -euo pipefail

cd "${DBT_PROJECT_DIR:-/app/dbt}"

echo "=== dbt version ==="
dbt --version

if [ "$#" -eq 0 ]; then
  set -- build
fi

echo "=== dbt debug (connection check) ==="
dbt debug

echo "=== dbt $* ==="
exec dbt "$@"
