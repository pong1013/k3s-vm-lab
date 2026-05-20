#!/usr/bin/env bash

do_report() {
  local cluster_name="${1:-}"
  local report_file

  if [[ -z "${cluster_name}" ]]; then
    die "Usage: k3s-vm-lab report <cluster-name>"
  fi

  validate_cluster_name "${cluster_name}"
  report_file="$(report_file_for "${cluster_name}")"
  [[ -f "${report_file}" ]] || die "Report not found: ${report_file}"
  sed -n '1,240p' "${report_file}"
}
