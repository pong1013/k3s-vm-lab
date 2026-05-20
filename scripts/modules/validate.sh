#!/usr/bin/env bash

validate_cluster_name() {
  local name="$1"
  if [[ -z "${name}" ]]; then
    die "Cluster name is required."
  fi
  if [[ ! "${name}" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]; then
    die "Cluster name must use lowercase letters, numbers, and hyphens, and must not start or end with a hyphen."
  fi
}

validate_positive_int() {
  local value="$1"
  local label="$2"
  if [[ ! "${value}" =~ ^[0-9]+$ ]] || (( value < 1 )); then
    die "${label} must be a positive integer."
  fi
}

validate_size_gb() {
  local value="$1"
  local label="$2"
  if [[ ! "${value}" =~ ^[0-9]+G$ ]]; then
    die "${label} must look like 2G, 20G, or 100G."
  fi
}

gb_value() {
  local value="$1"
  value="${value%G}"
  value="${value%g}"
  echo "${value}"
}
