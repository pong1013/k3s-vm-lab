#!/usr/bin/env bash

has_command() {
  command -v "$1" >/dev/null 2>&1
}

require_command() {
  local tool="$1"
  local hint="${2:-Install it and try again.}"
  if ! has_command "${tool}"; then
    die "Missing required command '${tool}'. ${hint}"
  fi
}

doctor_check_command() {
  local tool="$1"
  local required="${2:-required}"
  if has_command "${tool}"; then
    log_success "${tool} is installed."
    return 0
  fi

  if [[ "${required}" == "optional" ]]; then
    log_warn "${tool} is missing (optional for some flows)."
    return 0
  fi

  log_error "${tool} is missing."
  return 1
}
