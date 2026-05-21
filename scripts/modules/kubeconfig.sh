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

backup_user_kubeconfig() {
  local user_kubeconfig="${KUBECONFIG_TARGET:-${HOME}/.kube/config}"
  local backup_path="none"

  mkdir -p "$(dirname "${user_kubeconfig}")"
  if [[ -f "${user_kubeconfig}" ]]; then
    backup_path="${user_kubeconfig}.k3s-vm-lab.$(date +%Y%m%d%H%M%S).bak"
    cp "${user_kubeconfig}" "${backup_path}"
  fi

  echo "${backup_path}"
}

kubeconfig_context_exists() {
  local context_name="$1"
  local user_kubeconfig="${KUBECONFIG_TARGET:-${HOME}/.kube/config}"
  local contexts

  [[ -f "${user_kubeconfig}" ]] || return 1
  contexts="$(kubectl --kubeconfig "${user_kubeconfig}" config get-contexts "${context_name}" -o name 2>/dev/null || true)"
  [[ "${contexts}" == "${context_name}" || "${contexts}" == *$'\n'"${context_name}"$'\n'* || "${contexts}" == *$'\n'"${context_name}" ]]
}

ensure_kube_context_is_available() {
  local context_name="$1"

  if kubeconfig_context_exists "${context_name}" && ! find_cluster_index_by_context "${context_name}" >/dev/null; then
    die "Kube context '${context_name}' already exists in ${KUBECONFIG_TARGET:-${HOME}/.kube/config} and is not managed by k3s-vm-lab. Refusing to overwrite it."
  fi
}

merge_kubeconfig() {
  local cluster_kubeconfig="$1"
  local context_name="$2"
  local user_kubeconfig="${KUBECONFIG_TARGET:-${HOME}/.kube/config}"
  local backup_path="none"
  local tmp_file

  backup_path="$(backup_user_kubeconfig)"

  if [[ "${backup_path}" != "none" ]]; then
    tmp_file="$(mktemp)"
    KUBECONFIG="${user_kubeconfig}:${cluster_kubeconfig}" kubectl config view --flatten > "${tmp_file}"
  else
    tmp_file="$(mktemp)"
    KUBECONFIG="${cluster_kubeconfig}" kubectl config view --flatten > "${tmp_file}"
  fi

  mv "${tmp_file}" "${user_kubeconfig}"
  chmod 600 "${user_kubeconfig}"
  kubectl --kubeconfig "${user_kubeconfig}" config use-context "${context_name}" >/dev/null
  echo "${backup_path}"
}

remove_kubeconfig_identity() {
  local context_name="$1"
  local user_kubeconfig="${KUBECONFIG_TARGET:-${HOME}/.kube/config}"
  local backup_path

  require_command "kubectl" "Install kubectl to clean up kubeconfig entries."

  backup_path="$(backup_user_kubeconfig)"
  if [[ ! -f "${user_kubeconfig}" ]]; then
    echo "${backup_path}"
    return 0
  fi

  kubectl --kubeconfig "${user_kubeconfig}" config delete-context "${context_name}" >/dev/null 2>&1 || true
  kubectl --kubeconfig "${user_kubeconfig}" config delete-cluster "${context_name}" >/dev/null 2>&1 || true
  kubectl --kubeconfig "${user_kubeconfig}" config delete-user "${context_name}" >/dev/null 2>&1 || true
  chmod 600 "${user_kubeconfig}"

  echo "${backup_path}"
}
