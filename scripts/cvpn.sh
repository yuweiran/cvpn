#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
deploy_dir="$project_root/deploy"
env_file="$deploy_dir/.env"
action="${1:-status}"

case "$action" in
  init)
    if [[ -e "$env_file" ]]; then
      printf '%s\n' 'deploy/.env already exists; left unchanged.'
    else
      (umask 077; cp -- "$deploy_dir/.env.example" "$env_file")
      printf '%s\n' 'Created deploy/.env. See README.cvpn.md before starting.'
    fi
    exit 0
    ;;
  check|pull|up|down|status|logs) ;;
  *) printf '%s\n' 'Usage: bash scripts/cvpn.sh {init|check|pull|up|down|status|logs}' >&2; exit 2 ;;
esac

if [[ ! -f "$env_file" ]]; then
  printf '%s\n' 'Missing deploy/.env. Run: bash scripts/cvpn.sh init' >&2
  exit 1
fi
if ! command -v docker >/dev/null 2>&1; then
  printf '%s\n' 'Docker with Compose v2 is required. See README.cvpn.md.' >&2
  exit 1
fi

compose=(docker compose --env-file "$env_file" -f "$deploy_dir/compose.yaml")
case "$action" in
  check)  exec "${compose[@]}" config --quiet ;;
  pull)   exec "${compose[@]}" pull ;;
  up)     exec "${compose[@]}" up -d ;;
  down)   exec "${compose[@]}" down ;;
  status) exec "${compose[@]}" ps ;;
  logs)   exec "${compose[@]}" logs --tail=100 -f ;;
esac
