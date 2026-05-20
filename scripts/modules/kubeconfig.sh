#!/usr/bin/env bash

normalize_kubeconfig() {
  local source_file="$1"
  local target_file="$2"
  local server_ip="$3"
  local context_name="$4"

  require_command "kubectl" "Install kubectl to normalize and merge kubeconfig."

  sed \
    -e "s#server: https://127.0.0.1:6443#server: https://${server_ip}:6443#g" \
    -e "s#server: https://localhost:6443#server: https://${server_ip}:6443#g" \
    -e "s/name: default/name: ${context_name}/g" \
    -e "s/cluster: default/cluster: ${context_name}/g" \
    -e "s/user: default/user: ${context_name}/g" \
    -e "s/current-context: default/current-context: ${context_name}/g" \
    "${source_file}" > "${target_file}"
  chmod 600 "${target_file}"

  kubectl --kubeconfig "${target_file}" config view >/dev/null
}

merge_kubeconfig() {
  local cluster_kubeconfig="$1"
  local context_name="$2"
  local user_kubeconfig="${KUBECONFIG_TARGET:-${HOME}/.kube/config}"
  local backup_path="none"
  local tmp_file

  mkdir -p "$(dirname "${user_kubeconfig}")"

  if [[ -f "${user_kubeconfig}" ]]; then
    backup_path="${user_kubeconfig}.k3s-vm-lab.$(date +%Y%m%d%H%M%S).bak"
    cp "${user_kubeconfig}" "${backup_path}"
    tmp_file="$(mktemp)"
    KUBECONFIG="${user_kubeconfig}:${cluster_kubeconfig}" kubectl config view --flatten > "${tmp_file}"
  else
    tmp_file="$(mktemp)"
    KUBECONFIG="${cluster_kubeconfig}" kubectl config view --flatten > "${tmp_file}"
  fi

  mv "${tmp_file}" "${user_kubeconfig}"
  chmod 600 "${user_kubeconfig}"
  kubectl config use-context "${context_name}" >/dev/null
  echo "${backup_path}"
}
