#!/usr/bin/env bash

load_cluster_env() {
  local cluster_name="$1"
  local cluster_dir
  local env_file
  cluster_dir="$(cluster_dir_for "${cluster_name}")"
  env_file="$(cluster_env_for "${cluster_name}")"
  if [[ ! -f "${env_file}" ]]; then
    if [[ -d "${cluster_dir}" ]]; then
      die "Cluster '${cluster_name}' is incomplete: missing ${env_file}. Run 'make k3s-vm-lab destroy ${cluster_name}' to clean it, then build again."
    fi
    die "Cluster '${cluster_name}' not found. Expected ${env_file}"
  fi
  # shellcheck disable=SC1090
  source "${env_file}"
  CLUSTER_ID="${CLUSTER_ID:-unknown}"
  TOTAL_NODE_COUNT="${TOTAL_NODE_COUNT:-$(( ${WORKER_COUNT:-0} + 1 ))}"
  WORKER_COUNT="${WORKER_COUNT:-$(( TOTAL_NODE_COUNT - 1 ))}"
  RESOURCE_PROFILE="${RESOURCE_PROFILE:-unknown}"
}

do_status() {
  local cluster_name="${1:-}"
  local nodes_file
  local node_name
  local role
  local recorded_ip
  local cpus
  local memory
  local disk
  local cluster_dir
  local env_file
  local state
  local status_text

  if [[ -z "${cluster_name}" ]]; then
    if [[ ! -d "${CLUSTERS_DIR}" ]]; then
      log_info "No clusters found."
      return 0
    fi
    paint bold "Clusters"
    echo ""
    printf "%-22s %-18s %-8s %s\n" "NAME" "STATUS" "NODES" "CONTEXT"
    printf "%-22s %-18s %-8s %s\n" "----------------------" "------------------" "--------" "------------------------------"
    for cluster_dir in "${CLUSTERS_DIR}"/*; do
      [[ -d "${cluster_dir}" ]] || continue
      env_file="${cluster_dir}/cluster.env"
      if [[ -f "${env_file}" ]]; then
        # shellcheck disable=SC1090
        source "${env_file}"
        CLUSTER_ID="${CLUSTER_ID:-unknown}"
        TOTAL_NODE_COUNT="${TOTAL_NODE_COUNT:-$(( ${WORKER_COUNT:-0} + 1 ))}"
        WORKER_COUNT="${WORKER_COUNT:-$(( TOTAL_NODE_COUNT - 1 ))}"
        printf "%-22s %-18s %-8s %s\n" "${CLUSTER_NAME}" "${BUILD_STATUS}" "${TOTAL_NODE_COUNT}" "${KUBE_CONTEXT}"
      else
        printf "%-22s %-18s %-8s %s\n" "$(basename "${cluster_dir}")" "incomplete" "-" "missing cluster.env"
      fi
    done
    return 0
  fi

  validate_cluster_name "${cluster_name}"
  load_cluster_env "${cluster_name}"
  nodes_file="$(nodes_file_for "${cluster_name}")"

  paint bold "Cluster status"
  echo ""
  printf "%-16s %s\n" "Cluster:" "${CLUSTER_NAME}"
  printf "%-16s %s\n" "Status:" "${BUILD_STATUS}"
  printf "%-16s %s total / %s workers\n" "Nodes:" "${TOTAL_NODE_COUNT}" "${WORKER_COUNT}"
  printf "%-16s %s\n" "Context:" "${KUBE_CONTEXT}"
  echo ""
  paint bold "VM nodes"
  echo ""
  printf "%-28s %-8s %-12s %-15s %-6s %-8s %-8s\n" "NAME" "ROLE" "VM STATE" "IP" "CPU" "RAM" "DISK"
  printf "%-28s %-8s %-12s %-15s %-6s %-8s %-8s\n" "----------------------------" "--------" "------------" "---------------" "------" "--------" "--------"
  while IFS=$'\t' read -r node_name role recorded_ip cpus memory disk; do
    if multipass info "${node_name}" >/dev/null 2>&1; then
      state="$(vm_state "${node_name}")"
      status_text="${state}"
    else
      status_text="missing"
    fi
    printf "%-28s %-8s %-12s %-15s %-6s %-8s %-8s\n" "${node_name}" "${role}" "${status_text}" "${recorded_ip}" "${cpus}" "${memory}" "${disk}"
  done < "${nodes_file}"

  echo ""
  if has_command kubectl; then
    kubectl --context "${KUBE_CONTEXT}" get nodes -o wide || true
  else
    log_warn "kubectl is not installed; skipping Kubernetes status."
  fi
}
