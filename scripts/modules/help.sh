#!/usr/bin/env bash

print_help() {
  cat <<'EOF'
k3s-vm-lab - VM-backed local k3s lab installer

Usage:
  make k3s-vm-lab doctor
  make k3s-vm-lab build [cluster-name]
  make k3s-vm-lab status [cluster-name]
  make k3s-vm-lab report [cluster-name]
  make k3s-vm-lab destroy <cluster-name>
  make k3s-vm-lab help

Topology:
  build creates 1 fixed control-plane/server VM plus optional workers.
  You choose the total node count, including the server.

Commands:
  doctor   Check required local tools and host resources.
  build    Create Multipass VM nodes through chien-dev, install k3s, merge kubeconfig, and write a report.
  status   Show formatted VM and Kubernetes status for a cluster.
  report   Show a formatted terminal report and keep report.md on disk.
  destroy  Stop cluster VMs first, then optionally delete/purge them.
EOF
}
