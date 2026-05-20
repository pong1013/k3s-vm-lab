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

  if [[ -z "${cluster_name}" ]]; then
    if [[ ! -d "${CLUSTERS_DIR}" ]]; then
      log_info "No clusters found."
      return 0
    fi
    for cluster_dir in "${CLUSTERS_DIR}"/*; do
      [[ -d "${cluster_dir}" ]] || continue
      env_file="${cluster_dir}/cluster.env"
      if [[ -f "${env_file}" ]]; then
        # shellcheck disable=SC1090
        source "${env_file}"
        echo "${CLUSTER_NAME} (${BUILD_STATUS}) - ${KUBE_CONTEXT}"
      else
        echo "$(basename "${cluster_dir}") (incomplete) - missing cluster.env"
      fi
    done
    return 0
  fi

  validate_cluster_name "${cluster_name}"
  load_cluster_env "${cluster_name}"
  nodes_file="$(nodes_file_for "${cluster_name}")"

  echo "Cluster: ${CLUSTER_NAME}"
  echo "Status: ${BUILD_STATUS}"
  echo "Context: ${KUBE_CONTEXT}"
  echo ""
  echo "VM nodes:"
  while IFS=$'\t' read -r node_name role recorded_ip cpus memory disk; do
    if multipass info "${node_name}" >/dev/null 2>&1; then
      echo "  - ${node_name} (${role}): $(vm_state "${node_name}") ${recorded_ip} ${cpus}/${memory}/${disk}"
    else
      echo "  - ${node_name} (${role}): missing"
    fi
  done < "${nodes_file}"

  echo ""
  if has_command kubectl; then
    kubectl --context "${KUBE_CONTEXT}" get nodes -o wide || true
  else
    log_warn "kubectl is not installed; skipping Kubernetes status."
  fi
}
