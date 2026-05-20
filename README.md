# k3s-vm-lab

`k3s-vm-lab` is a VM-backed local k3s lab installer. It creates Multipass VM nodes through `chien-dev`, installs a `1 server + N workers` k3s cluster, merges kubeconfig into `~/.kube/config`, optionally installs `fake-gpu-operator`, and writes a Markdown report.

This project is intentionally not a generic k3s builder. It is an all-in-one local lab package for people who do not want to prepare instances or VMs by hand.

## Requirements

- macOS or Linux
- `chien-dev` from `dev-environment-setup`
- Multipass
- OpenSSH client
- `kubectl`
- `helm` if installing `fake-gpu-operator`

Windows and WSL are not officially supported in the first version.

One-command requirements setup is not included yet. For now, install the required tools above before running the lab commands.

## Usage

Run commands through `make` from the repo root:

```bash
make k3s-vm-lab doctor
make k3s-vm-lab build my-lab
make k3s-vm-lab status my-lab
make k3s-vm-lab report my-lab
make k3s-vm-lab destroy my-lab
```

During `build`, the CLI asks for:

- cluster name, if not provided in the command
- worker node count, in addition to the fixed `1 control-plane/server` node
- Ubuntu version for every VM node
- resource profile for both control-plane/server and worker nodes: `small`, `medium`, `large`, or `custom`
- whether to install `fake-gpu-operator` after the cluster is ready

Example interactive build:

```text
make k3s-vm-lab build my-lab

==============================================
 k3s-vm-lab | VM-backed local k3s lab
==============================================
This build creates one k3s control-plane/server VM plus worker VMs.
Control-plane/server node count: 1 fixed
Worker node count, in addition to the control-plane/server [1]:
Select Ubuntu version for all VM nodes:
  1) 22.04
  2) 24.04
Enter option number: 1
Select resource profile for control-plane/server and workers:
  1) small
  2) medium
  3) large
  4) custom
Enter option number: 1
Install fake-gpu-operator after the cluster is ready? [y/N]:
```

Node names are deterministic:

```text
<cluster>-server-1
<cluster>-worker-1...N
```

## Resource Profiles

| Profile | Server | Worker |
| --- | --- | --- |
| small | 2 CPU / 2G RAM / 20G disk | 2 CPU / 2G RAM / 20G disk |
| medium | 2 CPU / 4G RAM / 30G disk | 2 CPU / 4G RAM / 30G disk |
| large | 4 CPU / 8G RAM / 40G disk | 4 CPU / 8G RAM / 40G disk |
| custom | prompted | prompted |

The build checks host capacity before creating VMs and reserves at least `2 CPU + 4G RAM + 20G disk` for the host.

## Generated Files

Cluster files are written under:

```text
~/.k3s-vm-lab/generated/clusters/<cluster-name>/
```

Important files:

- `build.log`
- `kubeconfig`
- `report.md`
- `cluster.env`
- `nodes.tsv`

The user kubeconfig is backed up before merge:

```text
~/.kube/config.k3s-vm-lab.<timestamp>.bak
```

The generated context is:

```text
k3s-vm-lab-<cluster-name>
```

## Development

```bash
make syntax
make test
```

`make test` uses mocked external commands and does not create real VMs.
