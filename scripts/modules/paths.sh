#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
K3S_VM_LAB_HOME="${K3S_VM_LAB_HOME:-${HOME}/.k3s-vm-lab}"
GENERATED_DIR="${K3S_VM_LAB_HOME}/generated"
CLUSTERS_DIR="${GENERATED_DIR}/clusters"

cluster_dir_for() {
  local cluster_name="$1"
  echo "${CLUSTERS_DIR}/${cluster_name}"
}

cluster_env_for() {
  local cluster_name="$1"
  echo "$(cluster_dir_for "${cluster_name}")/cluster.env"
}

nodes_file_for() {
  local cluster_name="$1"
  echo "$(cluster_dir_for "${cluster_name}")/nodes.tsv"
}

report_file_for() {
  local cluster_name="$1"
  echo "$(cluster_dir_for "${cluster_name}")/report.md"
}

log_file_for() {
  local cluster_name="$1"
  echo "$(cluster_dir_for "${cluster_name}")/build.log"
}

kubeconfig_file_for() {
  local cluster_name="$1"
  echo "$(cluster_dir_for "${cluster_name}")/kubeconfig"
}

ensure_cluster_dirs() {
  local cluster_name="$1"
  mkdir -p "$(cluster_dir_for "${cluster_name}")"
}
