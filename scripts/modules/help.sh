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
  build creates 1 fixed control-plane/server VM plus the worker node count you choose.

Commands:
  doctor   Check required local tools and host resources.
  build    Create Multipass VM nodes through chien-dev, install k3s, merge kubeconfig, and write a report.
  status   Show VM and Kubernetes status for a cluster.
  report   Print the generated Markdown report.
  destroy  Delete cluster VM nodes and generated k3s-vm-lab files.
EOF
}
