# Agent Guidelines for ansible-playbooks

When making changes to this Ansible codebase, follow these priorities **in order**.

## 1. Idempotence First

Every task MUST be idempotent. Never use `command`, `shell`, `raw`, `script`, or `ansible.builtin.raw` when a declarative module exists for the job.

- Use `ansible.posix.sysctl` instead of `command: sysctl -p`
- Use `ansible.builtin.get_url` + `signed-by=` instead of `ansible.builtin.apt_key`
- Use `ansible.builtin.user` instead of `command: useradd`
- Use `ansible.builtin.service` / `ansible.builtin.systemd` instead of `command: systemctl ...`
- Use `ansible.builtin.file` instead of `command: mkdir / chmod / chown`
- Use `ansible.builtin.lineinfile` or `ansible.builtin.template` instead of `command: sed / echo >>`

If `command` or `shell` is truly unavoidable, you MUST set `changed_when` and `creates`/`removes` so the task reports correct state.

## 2. Currently Supported Modules

Use fully qualified collection names (FQCNs) and avoid deprecated modules.

- `ansible.builtin.apt_key` is deprecated -- use `ansible.builtin.get_url` to fetch GPG keys into `/etc/apt/keyrings/` and reference them with `signed-by=` in the repo line.
- `include:` is deprecated -- use `ansible.builtin.import_tasks` or `ansible.builtin.include_tasks`.
- Prefer `ansible.posix.*` and `community.docker.*` modules from `requirements.yml` over raw commands.

Check the Ansible deprecation warnings in CI output and fix them proactively.

## 3. Clean Layout and Role Separation

- Each role handles one concern (e.g., `docker`, `hostname`, `ubuntu-common`).
- Do not add Docker-specific tasks to `ubuntu-common` or vice versa.
- Role variables go in `defaults/main.yml`; playbook-level overrides go in `group_vars/` or extra vars.
- Templates live in `roles/<name>/templates/`, files in `roles/<name>/files/`.
- Keep task files short and focused. Split into multiple files with `import_tasks` if a role exceeds ~100 tasks.

## 4. Unit Test Updates

When adding or modifying a task:

- Update `molecule/default/verify.yml` to assert the expected outcome.
- Use `ansible.builtin.assert`, `ansible.builtin.stat`, `ansible.builtin.getent`, or `ansible.builtin.service_facts` for verification -- not `command` with grep.
- Tasks that depend on infrastructure unavailable in the test VM (NFS mounts, external APIs) must be gated with `when: not (molecule_test | default(false))`.

## 5. Testing After Every Change

Run `make test` after every change and confirm the full cycle passes (converge, idempotence, verify, destroy) before considering work complete. Do not skip the idempotence check -- a second converge must produce zero `changed` tasks.
