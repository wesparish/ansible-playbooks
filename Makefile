# Ansible playbook - Ubuntu 24+ infrastructure. Use 'make test' for Molecule tests.

SHELL := /bin/bash
ANSIBLE_CFG ?= ansible.cfg
INVENTORY ?= inventory.example.yml
PLAYBOOK ?= site.yml
VENV := .venv
PYTHON := $(VENV)/bin/python3
PIP := $(VENV)/bin/pip
ANSIBLE_GALAXY := $(VENV)/bin/ansible-galaxy
ANSIBLE_PLAYBOOK := $(VENV)/bin/ansible-playbook
ANSIBLE_LINT := $(VENV)/bin/ansible-lint
MOLECULE := $(VENV)/bin/molecule

# Molecule's vagrant driver ships a custom 'vagrant' Ansible module but doesn't
# add it to ANSIBLE_LIBRARY automatically. This helper resolves the path at runtime.
FIND_VAGRANT_MODULES = $$($(PYTHON) -c "import molecule_plugins.vagrant, os; print(os.path.join(os.path.dirname(molecule_plugins.vagrant.__file__), 'modules'))")

.PHONY: install-deps install-test-deps lint syntax-check list-tasks run check test test-converge test-destroy clean help generate-molecule-extra

# Create virtual environment
$(VENV):
	python3 -m venv $(VENV)
	$(PIP) install --upgrade pip

# Install Ansible and collections in venv
install-deps: $(VENV)
	$(PIP) install ansible-core
	$(ANSIBLE_GALAXY) collection install -r requirements.yml --force

# Install Molecule and Vagrant plugin (for make test)
install-test-deps: install-deps
	$(PIP) install -r requirements-test.txt

# Lint playbooks and roles (requires ansible-lint)
lint: install-test-deps
	$(ANSIBLE_LINT) $(PLAYBOOK) 2>/dev/null || echo "ansible-lint not available"

# Syntax check
syntax-check: install-deps
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(PLAYBOOK) --syntax-check

# List tasks (dry run)
list-tasks: install-deps
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(PLAYBOOK) --list-tasks

# Run playbook (default inventory; use INVENTORY=... for custom)
run: install-deps
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(PLAYBOOK) $(ARGS)

# Run playbook in check mode
check: install-deps
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(PLAYBOOK) --check -D $(ARGS)

# Generate test extra vars (password hash for user wes, location). Password is "test".
# Always regenerated to avoid stale files after a failed test run.
generate-molecule-extra:
	@command -v openssl >/dev/null 2>&1 || { echo "Error: openssl required for make test"; exit 1; }; \
	hash=$$(openssl passwd -6 -salt xy test); \
	echo "wes_crypted_pwd: \"$$hash\"" > $(CURDIR)/.molecule-extra.yml; \
	echo "location: weshouse" >> $(CURDIR)/.molecule-extra.yml; \
	echo "molecule_test: true" >> $(CURDIR)/.molecule-extra.yml; \
	echo "Generated .molecule-extra.yml with wes_crypted_pwd (password: test)"

# Run Molecule test (create VM, converge, idempotence, verify, destroy).
# Uses Vagrant with libvirt to spin up a full Ubuntu 24.04 VM.
# Generates .molecule-extra.yml with a fresh crypt hash so no static secrets in repo.
# Common env for Molecule commands: venv PATH, vagrant module path, venv Python for localhost
MOLECULE_ENV = ANSIBLE_LOCAL_TMP=/tmp/ansible-local ANSIBLE_LIBRARY=$(FIND_VAGRANT_MODULES) MOLECULE_VENV_PYTHON=$(CURDIR)/$(PYTHON) PATH="$(VENV)/bin:$$PATH"

test: install-test-deps generate-molecule-extra
	$(MOLECULE_ENV) $(MOLECULE) test -- -e @$(CURDIR)/.molecule-extra.yml
	@rm -f .molecule-extra.yml

# Run only converge (no destroy) - useful for debugging. Uses same generated vars.
test-converge: install-test-deps generate-molecule-extra
	$(MOLECULE_ENV) $(MOLECULE) converge -- -e @$(CURDIR)/.molecule-extra.yml

# Destroy Molecule instances
test-destroy: $(VENV)
	$(MOLECULE_ENV) $(MOLECULE) destroy 2>/dev/null || true

clean: test-destroy
	rm -rf $(VENV) .molecule-extra.yml

help:
	@echo "Targets:"
	@echo "  install-deps      - Install Ansible and galaxy collections"
	@echo "  install-test-deps - Install Molecule + Vagrant plugin (for make test)"
	@echo "  lint              - Run ansible-lint (optional)"
	@echo "  syntax-check      - Check playbook syntax (needs inventory)"
	@echo "  list-tasks        - List tasks in playbook"
	@echo "  run               - Run playbook (INVENTORY=inventory.yml)"
	@echo "  check             - Run playbook in check mode"
	@echo "  test              - Run Molecule test (Vagrant/libvirt VM: create/converge/idempotence/verify/destroy)"
	@echo "  test-converge     - Molecule converge only (leave VM up)"
	@echo "  test-destroy      - Molecule destroy instances"
	@echo "  clean             - Remove venv and Molecule instances"
