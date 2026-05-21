#!/usr/bin/env bash

cleanup_created_nodes() {
  local array_name="$1"
  local nodes=()
  local node
  eval "nodes=(\"\${${array_name}[@]}\")"

  if (( ${#nodes[@]} == 0 )); then
    return 0
  fi

  log_warn "Build failed. Cleaning up created VM nodes."
  for node in "${nodes[@]}"; do
    delete_vm_node "${node}"
  done
  purge_deleted_vms
}
