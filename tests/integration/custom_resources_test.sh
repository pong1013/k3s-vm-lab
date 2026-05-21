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
export NO_COLOR=1
mkdir -p "${HOME}/.kube"

printf 'apiVersion: v1\nkind: Config\n' > "${HOME}/.kube/config"

{
  printf 'custom-lab\n'
  printf '2\n'
  printf '1\n'
  printf '4\n'
  printf '3\n'
  printf '5G\n'
  printf '35G\n'
  printf '4\n'
  printf '2\n'
  printf '3G\n'
  printf '25G\n'
  printf 'n\n'
} | "${ROOT_DIR}/scripts/k3s-vm-lab" build >"${TMP_DIR}/build.out"

nodes_file="${K3S_VM_LAB_HOME}/generated/clusters/custom-lab/nodes.tsv"
report_file="${K3S_VM_LAB_HOME}/generated/clusters/custom-lab/report.md"

grep -q $'custom-lab-server-1\tserver\t192.168.64.10\t3\t5G\t35G' "${nodes_file}"
grep -q $'custom-lab-worker-1\tworker\t192.168.64.10\t2\t3G\t25G' "${nodes_file}"
grep -q "| custom-lab-server-1 | server | 192.168.64.10 | 3 | 5G | 35G |" "${report_file}"
grep -q "Resource check: selected VMs need 5 CPU / 8G RAM / 60G disk." "${TMP_DIR}/build.out"
grep -q "Host reserve: keeping 2 CPU / 4G RAM / 20G disk for your machine." "${TMP_DIR}/build.out"
grep -q "Minimum host capacity required: 7 CPU / 12G RAM / 80G free disk." "${TMP_DIR}/build.out"
grep -q "step: Creating control-plane VM custom-lab-server-1" "${TMP_DIR}/build.out"

"${ROOT_DIR}/scripts/k3s-vm-lab" report custom-lab >"${TMP_DIR}/report.out"
grep -q "k3s-vm-lab report: custom-lab" "${TMP_DIR}/report.out"
grep -q "custom-lab-worker-1" "${TMP_DIR}/report.out"

echo "custom resources test passed"
