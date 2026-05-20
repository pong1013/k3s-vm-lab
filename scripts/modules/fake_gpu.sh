#!/usr/bin/env bash

install_fake_gpu_operator() {
  local kubeconfig="$1"
  local nodes_file="$2"
  local node_name
  local role

  require_command "kubectl" "Install kubectl before installing fake-gpu-operator."
  require_command "helm" "Install Helm before installing fake-gpu-operator."

  log_info "Labeling worker nodes for fake-gpu-operator"
  while IFS=$'\t' read -r node_name role _; do
    [[ "${role}" == "worker" ]] || continue
    kubectl --kubeconfig "${kubeconfig}" label node "${node_name}" \
      run.ai/simulated-gpu-node-pool=default --overwrite
  done < "${nodes_file}"

  log_info "Installing fake-gpu-operator"
  helm upgrade --install fake-gpu-operator \
    oci://ghcr.io/run-ai/fake-gpu-operator/fake-gpu-operator \
    --namespace fake-gpu-operator \
    --create-namespace \
    --kubeconfig "${kubeconfig}"

  kubectl --kubeconfig "${kubeconfig}" -n fake-gpu-operator wait \
    --for=condition=Ready pods --all --timeout=180s
}
