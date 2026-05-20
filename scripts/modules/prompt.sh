#!/usr/bin/env bash

print_header() {
  echo "=============================================="
  echo " k3s-vm-lab | VM-backed local k3s lab"
  echo "=============================================="
}

prompt_text() {
  local prompt="$1"
  local default="${2:-}"
  local answer

  if [[ -n "${default}" ]]; then
    read -r -p "${prompt} [${default}]: " answer
    echo "${answer:-${default}}"
  else
    read -r -p "${prompt}: " answer
    echo "${answer}"
  fi
}

prompt_choice() {
  local prompt="$1"
  shift
  local options=("$@")
  local i
  local choice

  echo "${prompt}" >&2
  for ((i=0; i<${#options[@]}; i++)); do
    echo "  $((i+1))) ${options[$i]}" >&2
  done

  while true; do
    read -r -p "Enter option number: " choice >&2
    if [[ "${choice}" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
      echo "${options[$((choice-1))]}"
      return
    fi
    echo "Invalid option, please try again." >&2
  done
}

prompt_yes_no() {
  local prompt="$1"
  local default="${2:-n}"
  local answer

  if [[ "${default}" == "y" ]]; then
    read -r -p "${prompt} [Y/n]: " answer
    answer="${answer:-Y}"
  else
    read -r -p "${prompt} [y/N]: " answer
    answer="${answer:-N}"
  fi

  [[ "${answer}" =~ ^[Yy]$ ]]
}
