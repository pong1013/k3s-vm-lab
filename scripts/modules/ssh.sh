#!/usr/bin/env bash

SSH_USER="${SSH_USER:-ubuntu}"
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=8)

ssh_target() {
  local ip="$1"
  echo "${SSH_USER}@${ip}"
}

remote_exec() {
  local ip="$1"
  shift
  ssh "${SSH_OPTS[@]}" "$(ssh_target "${ip}")" "$@"
}

remote_capture() {
  local ip="$1"
  shift
  ssh "${SSH_OPTS[@]}" "$(ssh_target "${ip}")" "$@"
}

wait_for_ssh() {
  local ip="$1"
  local attempts="${2:-30}"
  local i

  log_info "Waiting for SSH on ${ip}"
  for ((i=1; i<=attempts; i++)); do
    if remote_exec "${ip}" "true" >/dev/null 2>&1; then
      log_success "SSH is ready on ${ip}"
      return 0
    fi
    sleep 5
  done

  die "SSH did not become ready on ${ip}."
}
