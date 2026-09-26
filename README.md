# Ansible playbooks – Ubuntu 24+ infrastructure

Playbooks and roles for Ubuntu 24.04 and newer only. No mining, AMD GPU, Rancher 1.x, or custom kernel support.

## Requirements

- Python 3.8+
- Vagrant + libvirt (for Molecule tests)
- Target hosts: Ubuntu 24.04+

First time setup:

```bash
make install-deps  # Creates .venv and installs ansible-core + collections
```

## Quick start

1. Copy `group_vars/all.example` to `group_vars/all` and set at least `wes_crypted_pwd` (and optionally `location`, `rancher2`, etc.).
2. Use an inventory (e.g. copy `inventory.example.yml` to `inventory.yml` and add your hosts).
3. Run: `make run` (or `make run INVENTORY=inventory.yml`) — uses the venv ansible-playbook. Use `-K -k` if you need become/SSH password.

## Testing with Molecule

Tests run in a full Ubuntu 24.04 VM (Vagrant/libvirt) using a local Python venv (`.venv/`). One scenario runs the full `site.yml` playbook, then checks idempotence and runs verify tasks.

Because it's a real VM (not a container), everything works: systemd services, kernel modules, Docker installation, NFS mounts, sysctl, etc. No workarounds or skips needed.

```bash
make test
```

The first run creates `.venv/`, installs Ansible, Molecule, and collections. Subsequent runs reuse the venv.

**`make test`** generates a temporary `wes_crypted_pwd` hash (password is `test`) using `openssl passwd -6`, so no static secrets are in the repo.

This will:

1. Create `.venv/` and install dependencies (first run only)
2. Generate `.molecule-extra.yml` with `wes_crypted_pwd` and `location=weshouse`
3. Create an Ubuntu 24.04 VM via Vagrant/libvirt
4. Run the full playbook (converge)
5. Run the playbook again and **fail if not idempotent**
6. Run verify tasks (Docker installed, user `wes` exists, chrony running, SSH config, sudoers)
7. Destroy the VM and remove `.molecule-extra.yml`

Other targets:

- `make test-converge` – Run converge only (VM stays up for debugging)
- `make test-destroy` or `make clean` – Destroy the test VM and remove venv

## Makefile

All targets automatically use the local venv (`.venv/`):

- `make install-deps` – Create venv, install Ansible and collections
- `make install-test-deps` – Install Molecule and Vagrant plugin (for `make test`)
- `make syntax-check` – Check playbook syntax
- `make list-tasks` – List tasks
- `make run` – Run playbook (default inventory: `inventory.example.yml`)
- `make check` – Run playbook in check mode
- `make test` – Run Molecule test (creates venv first if needed)
- `make test-converge` – Molecule converge only
- `make test-destroy` / `make clean` – Destroy Molecule instances and remove venv
- `make help` – Show all targets

## Idempotency

All roles are written to be idempotent. Molecule runs the playbook twice and fails if the second run reports any changes.

## Roles

- **hostname** – Sets FQDN and /etc/hostname, /etc/hosts
- **ubuntu-common** – User wes, sudoers, SSH, chrony, NFS/ceph mounts, sysctl, resolv.conf, etc.
- **docker** – Docker CE from Ubuntu/Docker repo; daemon.json with optional NVIDIA runtime when host is in `nvidiagpu` group
- **nvidiagpu** – NVIDIA driver and nvidia-container-toolkit from Ubuntu packages (no custom drivers)
- **rancher2** – Joins hosts to a Rancher 2 server

## Groups

- `all` – All hosts
- `docker` – All hosts get the docker role (applied to all in `site.yml`)
- `nvidiagpu` – Hosts with NVIDIA GPUs (driver + Docker runtime)
- `rancher2` – Hosts that join Rancher 2
