#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

export K3S_VM_LAB_HOME="${TMP_DIR}/home"
export HOME="${TMP_DIR}/user"
export PATH="${ROOT_DIR}/tests/mocks:${PATH}"
export K3S_VM_LAB_HOST_CPUS=16
export K3S_VM_LAB_HOST_MEM_GB=64
export K3S_VM_LAB_HOST_DISK_GB=500
export MOCK_MULTIPASS_LOG="${TMP_DIR}/multipass.log"
export NO_COLOR=1
mkdir -p "${HOME}/.kube"

printf 'apiVersion: v1\nkind: Config\n' > "${HOME}/.kube/config"

{
  printf 'destroy-lab\n'
  printf '2\n'
  printf '1\n'
  printf '1\n'
  printf '1\n'
  printf 'n\n'
} | "${ROOT_DIR}/scripts/k3s-vm-lab" build >"${TMP_DIR}/build.out"

cluster_dir="${K3S_VM_LAB_HOME}/generated/clusters/destroy-lab"

{
  printf 'y\n'
  printf 'n\n'
} | "${ROOT_DIR}/scripts/k3s-vm-lab" destroy destroy-lab >"${TMP_DIR}/destroy-stop.out"

test -d "${cluster_dir}"
grep -q "BUILD_STATUS=destroy-stopped" "${cluster_dir}/cluster.env"
grep -q "stop destroy-lab-server-1" "${MOCK_MULTIPASS_LOG}"
grep -q "stop destroy-lab-worker-1" "${MOCK_MULTIPASS_LOG}"
grep -q "remains in destroy-stopped state" "${TMP_DIR}/destroy-stop.out"

"${ROOT_DIR}/scripts/k3s-vm-lab" status >"${TMP_DIR}/status-list.out"
grep -q "destroy-lab.*destroy-stopped" "${TMP_DIR}/status-list.out"

printf 'y\n' | "${ROOT_DIR}/scripts/k3s-vm-lab" destroy destroy-lab >"${TMP_DIR}/destroy-delete.out"

test ! -e "${cluster_dir}"
grep -q "delete destroy-lab-server-1" "${MOCK_MULTIPASS_LOG}"
grep -q "delete destroy-lab-worker-1" "${MOCK_MULTIPASS_LOG}"
grep -q "purge" "${MOCK_MULTIPASS_LOG}"

legacy_dir="${K3S_VM_LAB_HOME}/generated/clusters/legacy-lab"
mkdir -p "${legacy_dir}"
cat > "${legacy_dir}/cluster.env" <<'EOF'
CLUSTER_NAME=legacy-lab
OS_VERSION=24.04
TOTAL_NODE_COUNT=1
WORKER_COUNT=0
RESOURCE_PROFILE=small
SERVER_NAME=legacy-lab-server-1
SERVER_IP=10.0.0.50
KUBE_CONTEXT=k3s-vm-lab-legacy-lab
KUBECONFIG_PATH=/tmp/legacy-kubeconfig
KUBECONFIG_BACKUP=none
FAKE_GPU_ENABLED=false
FAKE_GPU_STATUS=disabled
K3S_VERSION=unknown
BUILD_STATUS=ready
CREATED_AT=2026-01-01T00:00:00Z
EOF
printf 'legacy-lab-server-1\tserver\t10.0.0.50\t2\t2G\t20G\n' > "${legacy_dir}/nodes.tsv"

{
  printf 'y\n'
  printf 'y\n'
} | "${ROOT_DIR}/scripts/k3s-vm-lab" destroy legacy-lab >"${TMP_DIR}/legacy-destroy.out" 2>&1

test ! -e "${legacy_dir}"
grep -q "adopting legacy metadata" "${TMP_DIR}/legacy-destroy.out"
grep -q "delete legacy-lab-server-1" "${MOCK_MULTIPASS_LOG}"

echo "safe destroy test passed"
