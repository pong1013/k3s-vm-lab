#!/usr/bin/env bash

install_k3s_server() {
  local ip="$1"
  local node_name="$2"

  log_info "Installing k3s server on ${node_name}"
  remote_exec "${ip}" "curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='server --node-name ${node_name} --write-kubeconfig-mode 644' sh -"
}

k3s_node_token() {
  local server_ip="$1"
  remote_capture "${server_ip}" "sudo cat /var/lib/rancher/k3s/server/node-token"
}

install_k3s_worker() {
  local ip="$1"
  local node_name="$2"
  local server_ip="$3"
  local token="$4"

  log_info "Installing k3s agent on ${node_name}"
  remote_exec "${ip}" "curl -sfL https://get.k3s.io | K3S_URL='https://${server_ip}:6443' K3S_TOKEN='${token}' INSTALL_K3S_EXEC='agent --node-name ${node_name}' sh -"
}

fetch_server_kubeconfig() {
  local server_ip="$1"
  local target_file="$2"
  remote_capture "${server_ip}" "sudo cat /etc/rancher/k3s/k3s.yaml" > "${target_file}"
  chmod 600 "${target_file}"
}

k3s_version() {
  local server_ip="$1"
  remote_capture "${server_ip}" "k3s --version | head -1" || true
}

wait_for_nodes_ready() {
  local kubeconfig="$1"
  local timeout="${2:-180s}"
  require_command "kubectl" "Install kubectl to verify cluster readiness and merge kubeconfig."
  log_info "Waiting for k3s nodes to become Ready"
  kubectl --kubeconfig "${kubeconfig}" wait --for=condition=Ready nodes --all --timeout="${timeout}"
}
