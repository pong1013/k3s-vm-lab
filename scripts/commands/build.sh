#!/usr/bin/env bash

select_resource_profile() {
  local profile="$1"

  case "${profile}" in
    small)
      SERVER_CPUS=2
      SERVER_MEM="2G"
      SERVER_DISK="20G"
      WORKER_CPUS=2
      WORKER_MEM="2G"
      WORKER_DISK="20G"
      ;;
    medium)
      SERVER_CPUS=2
      SERVER_MEM="4G"
      SERVER_DISK="30G"
      WORKER_CPUS=2
      WORKER_MEM="4G"
      WORKER_DISK="30G"
      ;;
    large)
      SERVER_CPUS=4
      SERVER_MEM="8G"
      SERVER_DISK="40G"
      WORKER_CPUS=4
      WORKER_MEM="8G"
      WORKER_DISK="40G"
      ;;
    custom)
      SERVER_CPUS="$(prompt_text "Server CPU cores" "2")"
      SERVER_MEM="$(prompt_text "Server memory" "4G")"
      SERVER_DISK="$(prompt_text "Server disk" "30G")"
      WORKER_CPUS="$(prompt_text "Worker CPU cores" "2")"
      WORKER_MEM="$(prompt_text "Worker memory" "4G")"
      WORKER_DISK="$(prompt_text "Worker disk" "30G")"
      ;;
    *)
      die "Unknown resource profile: ${profile}"
      ;;
  esac

  validate_positive_int "${SERVER_CPUS}" "Server CPU cores"
  validate_size_gb "${SERVER_MEM}" "Server memory"
  validate_size_gb "${SERVER_DISK}" "Server disk"
  validate_positive_int "${WORKER_CPUS}" "Worker CPU cores"
  validate_size_gb "${WORKER_MEM}" "Worker memory"
  validate_size_gb "${WORKER_DISK}" "Worker disk"
}

collect_build_inputs() {
  local provided_name="$1"
  local profile_choice
  local os_choice
  local cluster_dir

  print_header
  echo "This build creates one k3s control-plane/server VM plus worker VMs." >&2
  echo "Control-plane/server node count: 1 fixed" >&2
  CLUSTER_NAME="${provided_name:-$(prompt_text "Cluster name" "demo-lab")}"
  validate_cluster_name "${CLUSTER_NAME}"

  cluster_dir="$(cluster_dir_for "${CLUSTER_NAME}")"
  if [[ -e "${cluster_dir}" ]]; then
    if [[ -f "$(cluster_env_for "${CLUSTER_NAME}")" ]]; then
      die "Cluster '${CLUSTER_NAME}' already exists at ${cluster_dir}. Destroy it first or use another name."
    fi
    die "Incomplete cluster directory exists: ${cluster_dir}. It may be left from an interrupted build. Run 'make k3s-vm-lab destroy ${CLUSTER_NAME}' to clean it, then build again."
  fi

  WORKER_COUNT="$(prompt_text "Worker node count, in addition to the control-plane/server" "1")"
  validate_positive_int "${WORKER_COUNT}" "Worker node count"

  os_choice="$(prompt_choice "Select Ubuntu version for all VM nodes:" "22.04" "24.04")"
  OS_VERSION="${os_choice}"

  profile_choice="$(prompt_choice "Select resource profile for control-plane/server and workers:" "small" "medium" "large" "custom")"
  RESOURCE_PROFILE="${profile_choice}"
  select_resource_profile "${RESOURCE_PROFILE}"

  if prompt_yes_no "Install fake-gpu-operator after the cluster is ready?" "n"; then
    FAKE_GPU_ENABLED="true"
  else
    FAKE_GPU_ENABLED="false"
  fi
  FAKE_GPU_STATUS="disabled"
}

setup_build_logging() {
  local cluster_name="$1"
  local log_file
  log_file="$(log_file_for "${cluster_name}")"
  touch "${log_file}"
  log_info "Build log: ${log_file}"
  exec >> "${log_file}" 2>&1
}

do_build() {
  local provided_name="${1:-}"
  local cluster_dir
  local nodes_file
  local raw_kubeconfig
  local worker_name
  local worker_ip
  local token
  local i
  local -a created_nodes=()

  ensure_chien_dev
  ensure_multipass
  require_command "ssh" "Install OpenSSH client."
  require_command "kubectl" "Install kubectl."

  collect_build_inputs "${provided_name}"
  ensure_capacity "${WORKER_COUNT}" "${SERVER_CPUS}" "${SERVER_MEM}" "${SERVER_DISK}" "${WORKER_CPUS}" "${WORKER_MEM}" "${WORKER_DISK}"

  cluster_dir="$(cluster_dir_for "${CLUSTER_NAME}")"
  ensure_cluster_dirs "${CLUSTER_NAME}"
  setup_build_logging "${CLUSTER_NAME}"

  CREATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  SERVER_NAME="${CLUSTER_NAME}-server-1"
  KUBE_CONTEXT="k3s-vm-lab-${CLUSTER_NAME}"
  KUBECONFIG_PATH="$(kubeconfig_file_for "${CLUSTER_NAME}")"
  KUBECONFIG_BACKUP="none"
  K3S_VERSION="unknown"
  BUILD_STATUS="in-progress"
  nodes_file="$(nodes_file_for "${CLUSTER_NAME}")"
  : > "${nodes_file}"

  on_build_error() {
    local status=$?
    trap - ERR INT TERM
    BUILD_STATUS="failed"
    write_cluster_env "${CLUSTER_NAME}" || true
    render_report "${CLUSTER_NAME}" || true
    cleanup_created_nodes created_nodes
    log_error "Build failed. Log retained at $(log_file_for "${CLUSTER_NAME}")"
    exit "${status}"
  }
  trap on_build_error ERR INT TERM

  create_vm_node "${SERVER_NAME}" "${OS_VERSION}" "${SERVER_CPUS}" "${SERVER_MEM}" "${SERVER_DISK}"
  created_nodes+=("${SERVER_NAME}")
  SERVER_IP="$(vm_ip "${SERVER_NAME}")"
  append_node_record "${CLUSTER_NAME}" "${SERVER_NAME}" "server" "${SERVER_IP}" "${SERVER_CPUS}" "${SERVER_MEM}" "${SERVER_DISK}"
  wait_for_ssh "${SERVER_IP}"
  install_k3s_server "${SERVER_IP}" "${SERVER_NAME}"

  token="$(k3s_node_token "${SERVER_IP}")"

  for ((i=1; i<=WORKER_COUNT; i++)); do
    worker_name="${CLUSTER_NAME}-worker-${i}"
    create_vm_node "${worker_name}" "${OS_VERSION}" "${WORKER_CPUS}" "${WORKER_MEM}" "${WORKER_DISK}"
    created_nodes+=("${worker_name}")
    worker_ip="$(vm_ip "${worker_name}")"
    append_node_record "${CLUSTER_NAME}" "${worker_name}" "worker" "${worker_ip}" "${WORKER_CPUS}" "${WORKER_MEM}" "${WORKER_DISK}"
    wait_for_ssh "${worker_ip}"
    install_k3s_worker "${worker_ip}" "${worker_name}" "${SERVER_IP}" "${token}"
  done

  raw_kubeconfig="${cluster_dir}/k3s.raw.yaml"
  fetch_server_kubeconfig "${SERVER_IP}" "${raw_kubeconfig}"
  normalize_kubeconfig "${raw_kubeconfig}" "${KUBECONFIG_PATH}" "${SERVER_IP}" "${KUBE_CONTEXT}"
  wait_for_nodes_ready "${KUBECONFIG_PATH}"

  if [[ "${FAKE_GPU_ENABLED}" == "true" ]]; then
    install_fake_gpu_operator "${KUBECONFIG_PATH}" "${nodes_file}"
    FAKE_GPU_STATUS="installed"
  fi

  KUBECONFIG_BACKUP="$(merge_kubeconfig "${KUBECONFIG_PATH}" "${KUBE_CONTEXT}")"
  K3S_VERSION="$(k3s_version "${SERVER_IP}")"
  BUILD_STATUS="ready"
  write_cluster_env "${CLUSTER_NAME}"
  render_report "${CLUSTER_NAME}"

  trap - ERR INT TERM
  log_success "Cluster ${CLUSTER_NAME} is ready."
  log_info "Report: $(report_file_for "${CLUSTER_NAME}")"
}
