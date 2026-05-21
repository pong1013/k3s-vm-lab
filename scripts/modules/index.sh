#!/usr/bin/env bash

generate_cluster_id() {
  if [[ -n "${K3S_VM_LAB_CLUSTER_ID:-}" ]]; then
    echo "${K3S_VM_LAB_CLUSTER_ID}"
    return 0
  fi
  printf "%04x%04x" "${RANDOM}" "${RANDOM}"
}

find_cluster_index_by_name() {
  local cluster_name="$1"
  local index_file
  local cluster_id
  local name
  local context
  local status
  local dir
  local created_at

  index_file="$(cluster_index_file)"
  [[ -f "${index_file}" ]] || return 1

  while IFS=$'\t' read -r cluster_id name context status dir created_at; do
    [[ -n "${cluster_id}" ]] || continue
    if [[ "${name}" == "${cluster_name}" ]]; then
      INDEX_CLUSTER_ID="${cluster_id}"
      INDEX_CLUSTER_NAME="${name}"
      INDEX_KUBE_CONTEXT="${context}"
      INDEX_STATUS="${status}"
      INDEX_CLUSTER_DIR="${dir}"
      INDEX_CREATED_AT="${created_at}"
      return 0
    fi
  done < "${index_file}"

  return 1
}

find_cluster_index_by_context() {
  local wanted_context="$1"
  local index_file
  local cluster_id
  local name
  local context
  local status
  local dir
  local created_at

  index_file="$(cluster_index_file)"
  [[ -f "${index_file}" ]] || return 1

  while IFS=$'\t' read -r cluster_id name context status dir created_at; do
    [[ -n "${cluster_id}" ]] || continue
    if [[ "${context}" == "${wanted_context}" ]]; then
      INDEX_CLUSTER_ID="${cluster_id}"
      INDEX_CLUSTER_NAME="${name}"
      INDEX_KUBE_CONTEXT="${context}"
      INDEX_STATUS="${status}"
      INDEX_CLUSTER_DIR="${dir}"
      INDEX_CREATED_AT="${created_at}"
      return 0
    fi
  done < "${index_file}"

  return 1
}

write_cluster_index_entry() {
  local cluster_id="$1"
  local cluster_name="$2"
  local context="$3"
  local status="$4"
  local dir="$5"
  local created_at="$6"
  local index_file
  local tmp_file
  local existing_id
  local existing_name
  local existing_context
  local existing_status
  local existing_dir
  local existing_created_at

  index_file="$(cluster_index_file)"
  mkdir -p "$(dirname "${index_file}")"
  tmp_file="$(mktemp)"

  if [[ -f "${index_file}" ]]; then
    while IFS=$'\t' read -r existing_id existing_name existing_context existing_status existing_dir existing_created_at; do
      [[ -n "${existing_id}" ]] || continue
      [[ "${existing_name}" != "${cluster_name}" ]] || continue
      printf "%s\t%s\t%s\t%s\t%s\t%s\n" \
        "${existing_id}" "${existing_name}" "${existing_context}" "${existing_status}" "${existing_dir}" "${existing_created_at}" >> "${tmp_file}"
    done < "${index_file}"
  fi

  printf "%s\t%s\t%s\t%s\t%s\t%s\n" \
    "${cluster_id}" "${cluster_name}" "${context}" "${status}" "${dir}" "${created_at}" >> "${tmp_file}"
  mv "${tmp_file}" "${index_file}"
  chmod 600 "${index_file}"
}

update_cluster_index_status() {
  local cluster_name="$1"
  local status="$2"

  if find_cluster_index_by_name "${cluster_name}"; then
    write_cluster_index_entry \
      "${INDEX_CLUSTER_ID}" \
      "${INDEX_CLUSTER_NAME}" \
      "${INDEX_KUBE_CONTEXT}" \
      "${status}" \
      "${INDEX_CLUSTER_DIR}" \
      "${INDEX_CREATED_AT}"
  fi
}

remove_cluster_index_entry() {
  local cluster_name="$1"
  local index_file
  local tmp_file
  local cluster_id
  local name
  local context
  local status
  local dir
  local created_at

  index_file="$(cluster_index_file)"
  [[ -f "${index_file}" ]] || return 0
  tmp_file="$(mktemp)"

  while IFS=$'\t' read -r cluster_id name context status dir created_at; do
    [[ -n "${cluster_id}" ]] || continue
    [[ "${name}" == "${cluster_name}" ]] && continue
    printf "%s\t%s\t%s\t%s\t%s\t%s\n" "${cluster_id}" "${name}" "${context}" "${status}" "${dir}" "${created_at}" >> "${tmp_file}"
  done < "${index_file}"

  if [[ -s "${tmp_file}" ]]; then
    mv "${tmp_file}" "${index_file}"
    chmod 600 "${index_file}"
  else
    rm -f "${tmp_file}" "${index_file}"
  fi
}
