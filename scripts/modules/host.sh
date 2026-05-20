#!/usr/bin/env bash

host_cpu_count() {
  if [[ -n "${K3S_VM_LAB_HOST_CPUS:-}" ]]; then
    echo "${K3S_VM_LAB_HOST_CPUS}"
    return
  fi
  if [[ "$(uname -s)" == "Darwin" ]]; then
    sysctl -n hw.ncpu
  else
    nproc
  fi
}

host_memory_gb() {
  if [[ -n "${K3S_VM_LAB_HOST_MEM_GB:-}" ]]; then
    echo "${K3S_VM_LAB_HOST_MEM_GB}"
    return
  fi
  if [[ "$(uname -s)" == "Darwin" ]]; then
    echo "$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))"
  else
    free -g | awk '/^Mem:/{print $2}'
  fi
}

host_free_disk_gb() {
  if [[ -n "${K3S_VM_LAB_HOST_DISK_GB:-}" ]]; then
    echo "${K3S_VM_LAB_HOST_DISK_GB}"
    return
  fi
  if [[ "$(uname -s)" == "Darwin" ]]; then
    df -g / | awk 'NR==2 {print $4}'
  else
    df -BG / | awk 'NR==2 {gsub(/G/, "", $4); print $4}'
  fi
}

print_host_resources() {
  log_info "Host CPU: $(host_cpu_count) cores"
  log_info "Host RAM: $(host_memory_gb)G"
  log_info "Host free disk: $(host_free_disk_gb)G"
}

ensure_capacity() {
  local workers="$1"
  local server_cpus="$2"
  local server_mem="$3"
  local server_disk="$4"
  local worker_cpus="$5"
  local worker_mem="$6"
  local worker_disk="$7"

  local required_cpu=$(( server_cpus + workers * worker_cpus + 2 ))
  local required_mem=$(( $(gb_value "${server_mem}") + workers * $(gb_value "${worker_mem}") + 4 ))
  local required_disk=$(( $(gb_value "${server_disk}") + workers * $(gb_value "${worker_disk}") + 20 ))
  local total_cpu
  local total_mem
  local free_disk

  total_cpu="$(host_cpu_count)"
  total_mem="$(host_memory_gb)"
  free_disk="$(host_free_disk_gb)"

  log_info "Required with host reserve: ${required_cpu} CPU, ${required_mem}G RAM, ${required_disk}G free disk"

  if (( total_cpu < required_cpu )); then
    die "Not enough CPU cores. Need ${required_cpu}, found ${total_cpu}."
  fi
  if (( total_mem < required_mem )); then
    die "Not enough RAM. Need ${required_mem}G, found ${total_mem}G."
  fi
  if (( free_disk < required_disk )); then
    die "Not enough free disk. Need ${required_disk}G, found ${free_disk}G."
  fi
}
