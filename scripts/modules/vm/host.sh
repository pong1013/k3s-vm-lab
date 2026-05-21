#!/usr/bin/env bash

host_cpu_count() {
  local value
  if [[ -n "${K3S_VM_LAB_HOST_CPUS:-}" ]]; then
    echo "${K3S_VM_LAB_HOST_CPUS}"
    return
  fi
  if [[ "$(uname -s)" == "Darwin" ]]; then
    value="$(sysctl -n hw.ncpu 2>/dev/null || true)"
  else
    value="$(nproc 2>/dev/null || true)"
  fi
  echo "${value:-unknown}"
}

host_memory_gb() {
  local bytes
  local value
  if [[ -n "${K3S_VM_LAB_HOST_MEM_GB:-}" ]]; then
    echo "${K3S_VM_LAB_HOST_MEM_GB}"
    return
  fi
  if [[ "$(uname -s)" == "Darwin" ]]; then
    bytes="$(sysctl -n hw.memsize 2>/dev/null || true)"
    if [[ "${bytes}" =~ ^[0-9]+$ ]]; then
      echo "$(( bytes / 1024 / 1024 / 1024 ))"
      return
    fi
  else
    value="$(free -g 2>/dev/null | awk '/^Mem:/{print $2}' || true)"
    if [[ -n "${value}" ]]; then
      echo "${value}"
      return
    fi
  fi
  echo "unknown"
}

host_free_disk_gb() {
  local value
  if [[ -n "${K3S_VM_LAB_HOST_DISK_GB:-}" ]]; then
    echo "${K3S_VM_LAB_HOST_DISK_GB}"
    return
  fi
  if [[ "$(uname -s)" == "Darwin" ]]; then
    value="$(df -g / 2>/dev/null | awk 'NR==2 {print $4}' || true)"
  else
    value="$(df -BG / 2>/dev/null | awk 'NR==2 {gsub(/G/, "", $4); print $4}' || true)"
  fi
  echo "${value:-unknown}"
}

print_host_resources() {
  log_info "Host CPU: $(host_cpu_count) cores"
  log_info "Host RAM: $(format_gb "$(host_memory_gb)")"
  log_info "Host free disk: $(format_gb "$(host_free_disk_gb)")"
}

format_gb() {
  local value="$1"
  if [[ "${value}" =~ ^[0-9]+$ ]]; then
    echo "${value}G"
  else
    echo "${value}"
  fi
}

print_capacity_breakdown() {
  local vm_cpu="$1"
  local vm_mem="$2"
  local vm_disk="$3"
  local required_cpu="$4"
  local required_mem="$5"
  local required_disk="$6"

  log_info "Resource check: selected VMs need ${vm_cpu} CPU / ${vm_mem}G RAM / ${vm_disk}G disk."
  log_info "Host reserve: keeping 2 CPU / 4G RAM / 20G disk for your machine."
  log_info "Minimum host capacity required: ${required_cpu} CPU / ${required_mem}G RAM / ${required_disk}G free disk."
}

print_host_capacity_summary() {
  echo ""
  paint bold "Host capacity"
  echo ""
  printf "  CPU:       %s cores\n" "$(host_cpu_count)"
  printf "  RAM:       %s\n" "$(format_gb "$(host_memory_gb)")"
  printf "  Free disk: %s\n" "$(format_gb "$(host_free_disk_gb)")"
  printf "  Reserve:   2 CPU / 4G RAM / 20G disk\n"
  echo ""
}

ensure_capacity() {
  local workers="$1"
  local server_cpus="$2"
  local server_mem="$3"
  local server_disk="$4"
  local worker_cpus="$5"
  local worker_mem="$6"
  local worker_disk="$7"

  local vm_cpu=$(( server_cpus + workers * worker_cpus ))
  local vm_mem=$(( $(gb_value "${server_mem}") + workers * $(gb_value "${worker_mem}") ))
  local vm_disk=$(( $(gb_value "${server_disk}") + workers * $(gb_value "${worker_disk}") ))
  local required_cpu=$(( vm_cpu + 2 ))
  local required_mem=$(( vm_mem + 4 ))
  local required_disk=$(( vm_disk + 20 ))
  local total_cpu
  local total_mem
  local free_disk

  total_cpu="$(host_cpu_count)"
  total_mem="$(host_memory_gb)"
  free_disk="$(host_free_disk_gb)"

  print_capacity_breakdown "${vm_cpu}" "${vm_mem}" "${vm_disk}" "${required_cpu}" "${required_mem}" "${required_disk}"

  if [[ ! "${total_cpu}" =~ ^[0-9]+$ ]] || [[ ! "${total_mem}" =~ ^[0-9]+$ ]] || [[ ! "${free_disk}" =~ ^[0-9]+$ ]]; then
    die "Could not determine host capacity. Set K3S_VM_LAB_HOST_CPUS, K3S_VM_LAB_HOST_MEM_GB, and K3S_VM_LAB_HOST_DISK_GB to override."
  fi

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

ensure_node_capacity() {
  local cpus_array_name="$1"
  local mems_array_name="$2"
  local disks_array_name="$3"
  local node_count="$4"
  local cpus=()
  local mems=()
  local disks=()
  local vm_cpu=0
  local vm_mem=0
  local vm_disk=0
  local required_cpu
  local required_mem
  local required_disk
  local total_cpu
  local total_mem
  local free_disk
  local i

  eval "cpus=(\"\${${cpus_array_name}[@]}\")"
  eval "mems=(\"\${${mems_array_name}[@]}\")"
  eval "disks=(\"\${${disks_array_name}[@]}\")"

  for ((i=0; i<node_count; i++)); do
    vm_cpu=$(( vm_cpu + cpus[i] ))
    vm_mem=$(( vm_mem + $(gb_value "${mems[i]}") ))
    vm_disk=$(( vm_disk + $(gb_value "${disks[i]}") ))
  done
  required_cpu=$(( vm_cpu + 2 ))
  required_mem=$(( vm_mem + 4 ))
  required_disk=$(( vm_disk + 20 ))

  total_cpu="$(host_cpu_count)"
  total_mem="$(host_memory_gb)"
  free_disk="$(host_free_disk_gb)"

  print_capacity_breakdown "${vm_cpu}" "${vm_mem}" "${vm_disk}" "${required_cpu}" "${required_mem}" "${required_disk}"

  if [[ ! "${total_cpu}" =~ ^[0-9]+$ ]] || [[ ! "${total_mem}" =~ ^[0-9]+$ ]] || [[ ! "${free_disk}" =~ ^[0-9]+$ ]]; then
    die "Could not determine host capacity. Set K3S_VM_LAB_HOST_CPUS, K3S_VM_LAB_HOST_MEM_GB, and K3S_VM_LAB_HOST_DISK_GB to override."
  fi

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
