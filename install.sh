#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${K3S_VM_LAB_REPO_URL:-https://github.com/pong1013/k3s-vm-lab.git}"
INSTALL_DIR="${K3S_VM_LAB_INSTALL_DIR:-${HOME}/.k3s-vm-lab}"
LOCAL_BIN_DIR="${HOME}/.local/bin"
BIN_NAME="k3s-vm-lab"

echo "==> Starting k3s-vm-lab installation"

if [[ -d "${INSTALL_DIR}/.git" ]]; then
  echo "==> Updating existing installation in ${INSTALL_DIR}"
  git -C "${INSTALL_DIR}" fetch origin
  git -C "${INSTALL_DIR}" reset --hard origin/main
else
  if [[ -e "${INSTALL_DIR}" ]]; then
    echo "error: ${INSTALL_DIR} exists but is not a git checkout" >&2
    exit 1
  fi
  echo "==> Cloning ${REPO_URL} to ${INSTALL_DIR}"
  git clone "${REPO_URL}" "${INSTALL_DIR}"
fi

mkdir -p "${LOCAL_BIN_DIR}"
ln -sf "${INSTALL_DIR}/scripts/k3s-vm-lab" "${LOCAL_BIN_DIR}/${BIN_NAME}"

if [[ ":${PATH}:" != *":${LOCAL_BIN_DIR}:"* ]]; then
  echo "==> Add this to your shell profile:"
  echo "    export PATH=\"${LOCAL_BIN_DIR}:\$PATH\""
fi

echo "==> Installed ${BIN_NAME}"
