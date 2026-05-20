#!/usr/bin/env bash

do_destroy() {
  local cluster_name="${1:-}"
  local nodes_file
  local node_name
  local role
  local ip
  local cpus
  local memory
  local disk
  local cluster_dir

  if [[ -z "${cluster_name}" ]]; then
    die "Usage: k3s-vm-lab destroy <cluster-name>"
  fi

  validate_cluster_name "${cluster_name}"
  cluster_dir="$(cluster_dir_for "${cluster_name}")"
  nodes_file="$(nodes_file_for "${cluster_name}")"
  [[ -d "${cluster_dir}" ]] || die "Cluster '${cluster_name}' not found."

  if ! prompt_yes_no "Delete cluster '${cluster_name}' VM nodes and generated files?" "n"; then
    log_info "Destroy cancelled."
    return 0
  fi

  if [[ -f "${nodes_file}" ]]; then
    while IFS=$'\t' read -r node_name role ip cpus memory disk; do
      delete_vm_node "${node_name}"
    done < "${nodes_file}"
    purge_deleted_vms
  fi

  rm -rf "${cluster_dir}"
  log_success "Cluster '${cluster_name}' destroyed."
}
