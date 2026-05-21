#!/usr/bin/env bash

has_command() {
  command -v "$1" >/dev/null 2>&1
}

install_hint_for() {
  local tool="$1"
  local os
  os="$(uname -s)"

  case "${tool}" in
    chien-dev)
      echo "Install: git clone https://github.com/pong1013/dev-environment-setup.git && cd dev-environment-setup && ./install.sh"
      ;;
    multipass)
      if [[ "${os}" == "Darwin" ]]; then
        echo "Install: brew install --cask multipass"
      else
        echo "Install: sudo snap install multipass"
      fi
      ;;
    kubectl)
      if [[ "${os}" == "Darwin" ]]; then
        echo "Install: brew install kubectl"
      else
        echo "Install: curl -LO https://dl.k8s.io/release/stable.txt && curl -LO \"https://dl.k8s.io/release/\$(cat stable.txt)/bin/linux/$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')/kubectl\""
      fi
      ;;
    helm)
      if [[ "${os}" == "Darwin" ]]; then
        echo "Install: brew install helm"
      else
        echo "Install: curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
      fi
      ;;
    jq)
      if [[ "${os}" == "Darwin" ]]; then
        echo "Install: brew install jq"
      else
        echo "Install: sudo apt-get update && sudo apt-get install -y jq"
      fi
      ;;
    ssh|scp)
      if [[ "${os}" == "Darwin" ]]; then
        echo "Install: xcode-select --install"
      else
        echo "Install: sudo apt-get update && sudo apt-get install -y openssh-client"
      fi
      ;;
    curl)
      if [[ "${os}" == "Darwin" ]]; then
        echo "Install: brew install curl"
      else
        echo "Install: sudo apt-get update && sudo apt-get install -y curl"
      fi
      ;;
    *)
      echo "Install: install '${tool}' and make sure it is on PATH."
      ;;
  esac
}

print_install_hint() {
  local tool="$1"
  log_info "$(install_hint_for "${tool}")"
}

require_command() {
  local tool="$1"
  local hint="${2:-Install it and try again.}"
  if ! has_command "${tool}"; then
    log_error "Missing required command '${tool}'. ${hint}"
    print_install_hint "${tool}"
    exit 1
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
    print_install_hint "${tool}"
    return 0
  fi

  log_error "${tool} is missing."
  print_install_hint "${tool}"
  return 1
}
