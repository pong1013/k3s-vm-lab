#!/usr/bin/env bash

color_enabled() {
  local fd="${1:-1}"
  [[ -z "${NO_COLOR:-}" ]] && [[ -t "${fd}" ]]
}

color_code() {
  local color="$1"
  case "${color}" in
    blue) echo "34" ;;
    cyan) echo "36" ;;
    green) echo "32" ;;
    yellow) echo "33" ;;
    red) echo "31" ;;
    bold) echo "1" ;;
    *) echo "0" ;;
  esac
}

paint() {
  local color="$1"
  local text="$2"
  local fd="${3:-1}"
  if color_enabled "${fd}"; then
    printf "\033[%sm%s\033[0m" "$(color_code "${color}")" "${text}"
  else
    printf "%s" "${text}"
  fi
}

status_color() {
  local status="$1"
  case "${status}" in
    ready|installed|Running|Ready|*Ready*)
      if [[ "${status}" == *"NotReady"* ]]; then
        echo "red"
      else
        echo "green"
      fi
      ;;
    stopped|stopping|starting|disabled|Stopped) echo "yellow" ;;
    failed|deleting|missing|Missing|NotReady|incomplete) echo "red" ;;
    *) echo "blue" ;;
  esac
}

paint_status() {
  local status="$1"
  paint "$(status_color "${status}")" "${status}"
}

section_title() {
  paint bold "$1"
  echo ""
}

console_fd() {
  if [[ "${K3S_VM_LAB_CONSOLE:-false}" == "true" ]]; then
    echo 3
  else
    echo 1
  fi
}

console_err_fd() {
  if [[ "${K3S_VM_LAB_CONSOLE:-false}" == "true" ]]; then
    echo 4
  else
    echo 2
  fi
}

console_printf() {
  local format="$1"
  shift
  if [[ "${K3S_VM_LAB_CONSOLE:-false}" == "true" ]]; then
    printf "${format}" "$@" >&3
  else
    printf "${format}" "$@"
  fi
}

console_err_printf() {
  local format="$1"
  shift
  if [[ "${K3S_VM_LAB_CONSOLE:-false}" == "true" ]]; then
    printf "${format}" "$@" >&4
  else
    printf "${format}" "$@" >&2
  fi
}

log_info() {
  printf "%s\n" "$(paint blue "info: $*")"
}

log_warn() {
  printf "%s\n" "$(paint yellow "warn: $*" 2)" >&2
}

log_error() {
  printf "%s\n" "$(paint red "error: $*" 2)" >&2
}

log_success() {
  printf "%s\n" "$(paint green "success: $*")"
}

log_step() {
  printf "%s\n" "$(paint cyan "step: $*")"
}

log_console_info() {
  console_printf "%s\n" "$(paint blue "info: $*" "$(console_fd)")"
}

log_console_warn() {
  console_err_printf "%s\n" "$(paint yellow "warn: $*" "$(console_err_fd)")"
}

log_console_error() {
  console_err_printf "%s\n" "$(paint red "error: $*" "$(console_err_fd)")"
}

log_console_success() {
  console_printf "%s\n" "$(paint green "success: $*" "$(console_fd)")"
}

log_console_step() {
  console_printf "%s\n" "$(paint cyan "step: $*" "$(console_fd)")"
}

die() {
  log_error "$*"
  exit 1
}
