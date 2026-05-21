#!/usr/bin/env bash

wait_for_fake_gpu_pods() {
  local kubeconfig="$1"
  local timeout_seconds="$2"
  local elapsed=0
  local interval=5

  log_info "Waiting for fake-gpu-operator pods to be created"
  while (( elapsed <= timeout_seconds )); do
    if kubectl --kubeconfig "${kubeconfig}" -n fake-gpu-operator get pods --no-headers 2>/dev/null | grep -q .; then
      return 0
    fi
    sleep "${interval}"
    elapsed=$(( elapsed + interval ))
  done

  log_warn "Timed out waiting for fake-gpu-operator pods to be created."
  return 1
}

wait_for_fake_gpu_rollout() {
  local kubeconfig="$1"
  local timeout="${2:-600s}"
  local resource

  log_info "Waiting for fake-gpu-operator deployments"
  while IFS= read -r resource; do
    [[ -n "${resource}" ]] || continue
    kubectl --kubeconfig "${kubeconfig}" -n fake-gpu-operator rollout status "${resource}" --timeout="${timeout}" || return 1
  done < <(kubectl --kubeconfig "${kubeconfig}" -n fake-gpu-operator get deployment -o name)

  log_info "Waiting for fake-gpu-operator daemonsets"
  while IFS= read -r resource; do
    [[ -n "${resource}" ]] || continue
    kubectl --kubeconfig "${kubeconfig}" -n fake-gpu-operator rollout status "${resource}" --timeout="${timeout}" || return 1
  done < <(kubectl --kubeconfig "${kubeconfig}" -n fake-gpu-operator get daemonset -o name)

  log_info "Waiting for fake-gpu-operator pods to become Ready"
  kubectl --kubeconfig "${kubeconfig}" -n fake-gpu-operator wait \
    --for=condition=Ready pods --all --timeout="${timeout}" || return 1
}

capture_fake_gpu_diagnostics() {
  local kubeconfig="$1"

  log_warn "fake-gpu-operator did not become Ready. Capturing diagnostics."
  kubectl --kubeconfig "${kubeconfig}" -n fake-gpu-operator get pods -o wide || true
  kubectl --kubeconfig "${kubeconfig}" -n fake-gpu-operator get deployments -o wide || true
  kubectl --kubeconfig "${kubeconfig}" -n fake-gpu-operator get daemonsets -o wide || true
  kubectl --kubeconfig "${kubeconfig}" -n fake-gpu-operator get events --sort-by=.lastTimestamp || true
  kubectl --kubeconfig "${kubeconfig}" -n fake-gpu-operator describe pods || true
}

install_fake_gpu_operator() {
  local kubeconfig="$1"
  local nodes_file="$2"
  local timeout="${3:-600s}"
  local node_name
  local role
  local timeout_seconds="${timeout%s}"

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
    --set runtimeClass.enabled=false \
    --kubeconfig "${kubeconfig}"

  if ! wait_for_fake_gpu_pods "${kubeconfig}" "${timeout_seconds}" ||
     ! wait_for_fake_gpu_rollout "${kubeconfig}" "${timeout}"; then
    capture_fake_gpu_diagnostics "${kubeconfig}"
    return 1
  fi
}
