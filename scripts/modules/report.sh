#!/usr/bin/env bash

write_cluster_env() {
  local cluster_name="$1"
  local env_file
  env_file="$(cluster_env_for "${cluster_name}")"

  {
    printf "CLUSTER_NAME=%q\n" "${CLUSTER_NAME}"
    printf "OS_VERSION=%q\n" "${OS_VERSION}"
    printf "WORKER_COUNT=%q\n" "${WORKER_COUNT}"
    printf "RESOURCE_PROFILE=%q\n" "${RESOURCE_PROFILE}"
    printf "SERVER_NAME=%q\n" "${SERVER_NAME}"
    printf "SERVER_IP=%q\n" "${SERVER_IP}"
    printf "KUBE_CONTEXT=%q\n" "${KUBE_CONTEXT}"
    printf "KUBECONFIG_PATH=%q\n" "${KUBECONFIG_PATH}"
    printf "KUBECONFIG_BACKUP=%q\n" "${KUBECONFIG_BACKUP}"
    printf "FAKE_GPU_ENABLED=%q\n" "${FAKE_GPU_ENABLED}"
    printf "FAKE_GPU_STATUS=%q\n" "${FAKE_GPU_STATUS}"
    printf "K3S_VERSION=%q\n" "${K3S_VERSION}"
    printf "BUILD_STATUS=%q\n" "${BUILD_STATUS}"
    printf "CREATED_AT=%q\n" "${CREATED_AT}"
  } > "${env_file}"
}

append_node_record() {
  local cluster_name="$1"
  local node_name="$2"
  local role="$3"
  local ip="$4"
  local cpus="$5"
  local memory="$6"
  local disk="$7"
  printf "%s\t%s\t%s\t%s\t%s\t%s\n" "${node_name}" "${role}" "${ip}" "${cpus}" "${memory}" "${disk}" >> "$(nodes_file_for "${cluster_name}")"
}

render_report() {
  local cluster_name="$1"
  local report_file
  local nodes_file
  local node_name
  local role
  local ip
  local cpus
  local memory
  local disk

  report_file="$(report_file_for "${cluster_name}")"
  nodes_file="$(nodes_file_for "${cluster_name}")"

  {
    echo "# k3s-vm-lab Report: ${CLUSTER_NAME}"
    echo ""
    echo "- Build status: ${BUILD_STATUS}"
    echo "- Created at: ${CREATED_AT}"
    echo "- OS version: Ubuntu ${OS_VERSION}"
    echo "- Resource profile: ${RESOURCE_PROFILE}"
    echo "- k3s version: ${K3S_VERSION:-unknown}"
    echo "- Kube context: ${KUBE_CONTEXT}"
    echo "- Kubeconfig: ${HOME}/.kube/config"
    echo "- Kubeconfig backup: ${KUBECONFIG_BACKUP}"
    echo "- Local cluster kubeconfig copy: ${KUBECONFIG_PATH}"
    echo "- fake-gpu-operator: ${FAKE_GPU_STATUS}"
    echo ""
    echo "## Nodes"
    echo ""
    echo "| Name | Role | IP | CPU | RAM | Disk |"
    echo "| --- | --- | --- | --- | --- | --- |"
    if [[ -f "${nodes_file}" ]]; then
      while IFS=$'\t' read -r node_name role ip cpus memory disk; do
        echo "| ${node_name} | ${role} | ${ip} | ${cpus} | ${memory} | ${disk} |"
      done < "${nodes_file}"
    fi
    echo ""
    echo "## Useful commands"
    echo ""
    echo '```bash'
    echo "kubectl config use-context ${KUBE_CONTEXT}"
    echo "kubectl get nodes -o wide"
    echo "kubectl get pods -A"
    echo "k3s-vm-lab status ${CLUSTER_NAME}"
    echo "k3s-vm-lab destroy ${CLUSTER_NAME}"
    echo '```'
  } > "${report_file}"
}
