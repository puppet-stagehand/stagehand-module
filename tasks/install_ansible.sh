#!/bin/sh
# stagehand::install_ansible — ensure ansible-playbook is present on a node per one
# of several install strategies (D-01, 14.3-01-PLAN.md). Ships as a
# standalone Bolt task (input_method stdin) for direct/manual use.
#
# stagehand::run_playbook (run_playbook.sh) also SOURCES this script — with
# STAGEHAND_SOURCED=1 exported first — to reuse the install_ansible_run function
# below, so a chained install surfaces as part of the SAME run record
# (D-07) instead of a second Bolt task invocation. The `[ "$STAGEHAND_SOURCED" !=
# "1" ]` guard at the bottom of this file is what makes sourcing safe: it
# skips this file's own stdin-read/exit-0 main path when sourced, leaving
# only the install_ansible_run function definition behind for the caller.
#
# Task params (stdin JSON, per Bolt input_method stdin), standalone use only:
#   install_method   one of auto|package|pip|pipx|wsl|skip (default auto)
#
# This script's stdout, when run standalone, is a single JSON object:
#   {"method": "<m>", "status": "ok"|"error", "error": "..."}
# The script ALWAYS exits 0 when run standalone — install failure is
# embedded status, not a task failure (same always-exit-0 contract as
# discover.sh / run_playbook.sh).
set -u

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# STAGEHAND_ANSIBLE_BIN exists solely so tests can point the presence-check +
# install strategies at a stub ansible-playbook binary on a curated PATH
# (mirroring STAGEHAND_DISCOVER_PUPPET_BIN). It is NEVER a Bolt param. Evaluated at
# source time, so a caller (run_playbook.sh) that exports STAGEHAND_ANSIBLE_BIN
# before sourcing this file controls which binary install_ansible_run checks
# for.
ANSIBLE_BIN="${STAGEHAND_ANSIBLE_BIN:-ansible-playbook}"

# Ruby interpreter for JSON parsing (standalone main path only). Prefer the
# puppet-agent bundled ruby — targets often have no system ruby on PATH —
# falling back to PATH ruby. STAGEHAND_RUBY_BIN is a test-only override. A caller
# sourcing this file (run_playbook.sh) defines its own $RUBY the same way;
# ${RUBY:-} keeps sourcing side-effect-free.
if [ -z "${RUBY:-}" ]; then
  RUBY="${STAGEHAND_RUBY_BIN:-}"
  if [ -z "$RUBY" ]; then
    if [ -x /opt/puppetlabs/puppet/bin/ruby ]; then
      RUBY=/opt/puppetlabs/puppet/bin/ruby
    else
      RUBY=ruby
    fi
  fi
fi

# The encoder is a staged task file in Bolt and a repository sibling in the
# direct shell harnesses. run_playbook.sh also lists it explicitly because
# Bolt does not recursively stage files declared by install_ansible.json.
if [ -n "${PT__installdir:-}" ] && [ -f "${PT__installdir}/stagehand/files/json_escape.sh" ]; then
  JSON_HELPER="${PT__installdir}/stagehand/files/json_escape.sh"
else
  JSON_HELPER="$(dirname "$0")/../files/json_escape.sh"
fi
[ -f "$JSON_HELPER" ] || die "JSON helper not found at $JSON_HELPER"
# shellcheck disable=SC1090
. "$JSON_HELPER"

# install_ansible_run METHOD
#
# Ensures ansible-playbook is available per METHOD; prints a single JSON
# fragment on stdout: {"method": "<m>", "status": "ok"|"error", "error": "..."}
# Returns 0 on ok, 1 on error — but NEVER exits the calling process (callers,
# whether this file's own main path or run_playbook.sh, decide what to do
# with a non-ok status).
install_ansible_run() {
  method="${1:-auto}"

  if command -v "$ANSIBLE_BIN" >/dev/null 2>&1; then
    printf '{"method": %s, "status": "ok"}' "$(json_escape "$method")"
    return 0
  fi

  case "$method" in
    skip)
      printf '{"method": "skip", "status": "error", "error": "ansible-playbook not found and install_method is skip"}'
      return 1
      ;;
    auto)
      # Best-effort: try the node's own package manager first (its own
      # signing/provenance), then fall back to pip installing the official
      # ansible-core package from PyPI. Every step is best-effort (|| true
      # style via the outer command -v re-check below) — a package-manager
      # attempt that partially fails still falls through to the pip
      # fallback rather than aborting the whole install_method.
      # Capture each attempt's output so a real failure (missing ansible-core
      # in the repos, apt lock, no network) is reported instead of the old
      # misleading "no package manager" message. _pm records what we actually
      # tried, so the error can distinguish "nothing to try" from "tried and
      # failed".
      _pm=""
      _log=$(mktemp 2>/dev/null || printf '/tmp/stagehand_install_ansible.%s' "$$")
      if command -v apt-get >/dev/null 2>&1; then
        _pm="apt-get"
        apt-get update >"$_log" 2>&1
        apt-get install -y ansible-core >>"$_log" 2>&1
      elif command -v dnf >/dev/null 2>&1; then
        _pm="dnf"
        dnf install -y ansible-core >"$_log" 2>&1
      elif command -v yum >/dev/null 2>&1; then
        _pm="yum"
        yum install -y ansible-core >"$_log" 2>&1
      elif command -v zypper >/dev/null 2>&1; then
        _pm="zypper"
        zypper install -y ansible-core >"$_log" 2>&1
      fi
      if ! command -v "$ANSIBLE_BIN" >/dev/null 2>&1; then
        if command -v pip3 >/dev/null 2>&1; then
          _pm="${_pm:+$_pm+}pip3"
          pip3 install --quiet ansible-core >>"$_log" 2>&1
        elif command -v pip >/dev/null 2>&1; then
          _pm="${_pm:+$_pm+}pip"
          pip install --quiet ansible-core >>"$_log" 2>&1
        fi
      fi
      if command -v "$ANSIBLE_BIN" >/dev/null 2>&1; then
        rm -f "$_log"
        printf '{"method": "auto", "status": "ok"}'
        return 0
      fi
      if [ -z "$_pm" ]; then
        _reason="no package manager (apt-get/dnf/yum/zypper) or pip found on PATH — task PATH may be minimal (PATH=$PATH)"
      else
        # Keep the diagnostic on one line; json_escape below preserves quotes
        # and backslashes safely instead of deleting them from the message.
        _tail=$(tail -c 600 "$_log" 2>/dev/null | tr '\n' ' ' | tr -d '\000-\037')
        _reason="install via ${_pm} did not yield ansible-playbook: ${_tail}"
      fi
      rm -f "$_log"
      printf '{"method": "auto", "status": "error", "error": %s}' "$(json_escape "$_reason")"
      return 1
      ;;
    package)
      # Dedicated distro-package-manager strategy (vs. auto's try-then-fall-
      # back chain) — errors immediately if no supported manager is present,
      # rather than silently falling back to pip.
      if command -v apt-get >/dev/null 2>&1; then
        apt-get update >/dev/null 2>&1
        apt-get install -y ansible-core >/dev/null 2>&1
      elif command -v dnf >/dev/null 2>&1; then
        dnf install -y ansible-core >/dev/null 2>&1
      elif command -v yum >/dev/null 2>&1; then
        yum install -y ansible-core >/dev/null 2>&1
      elif command -v zypper >/dev/null 2>&1; then
        zypper install -y ansible-core >/dev/null 2>&1
      else
        printf '{"method": "package", "status": "error", "error": "no supported package manager found (apt-get/dnf/yum/zypper)"}'
        return 1
      fi
      if command -v "$ANSIBLE_BIN" >/dev/null 2>&1; then
        printf '{"method": "package", "status": "ok"}'
        return 0
      fi
      printf '{"method": "package", "status": "error", "error": "package manager install did not produce a working ansible-playbook binary"}'
      return 1
      ;;
    pip)
      if command -v pip3 >/dev/null 2>&1; then
        pip3 install --user --quiet ansible-core >/dev/null 2>&1
      elif command -v pip >/dev/null 2>&1; then
        pip install --user --quiet ansible-core >/dev/null 2>&1
      else
        printf '{"method": "pip", "status": "error", "error": "pip/pip3 not found on PATH"}'
        return 1
      fi
      if command -v "$ANSIBLE_BIN" >/dev/null 2>&1; then
        printf '{"method": "pip", "status": "ok"}'
        return 0
      fi
      printf '{"method": "pip", "status": "error", "error": "pip install did not produce a working ansible-playbook binary"}'
      return 1
      ;;
    pipx)
      # Isolated-environment strategy (skill doc: "clean installs") — never
      # falls back to bare pip, since the whole point of choosing pipx is
      # avoiding an unmanaged pip install.
      if command -v pipx >/dev/null 2>&1; then
        pipx install ansible-core >/dev/null 2>&1
      else
        printf '{"method": "pipx", "status": "error", "error": "pipx not found on PATH"}'
        return 1
      fi
      if command -v "$ANSIBLE_BIN" >/dev/null 2>&1; then
        printf '{"method": "pipx", "status": "ok"}'
        return 0
      fi
      printf '{"method": "pipx", "status": "error", "error": "pipx install did not produce a working ansible-playbook binary"}'
      return 1
      ;;
    wsl)
      # Windows path (puppet-construct:ansible-integration skill doc):
      # Ansible cannot run natively on Windows as a control node, so this
      # strategy installs/verifies Ansible INSIDE WSL2, not on the outer
      # Windows host. `wsl` on PATH is the WSL2-present signal; without it
      # there is nothing this strategy can do (Ansible cannot run at all on
      # bare Windows without WSL2).
      if command -v wsl >/dev/null 2>&1; then
        if ! wsl ansible-playbook --version >/dev/null 2>&1; then
          wsl bash -lc 'command -v ansible-playbook >/dev/null 2>&1 || (command -v apt-get >/dev/null 2>&1 && sudo apt-get update && sudo apt-get install -y ansible-core) || pip3 install --user ansible-core' >/dev/null 2>&1
        fi
        if wsl ansible-playbook --version >/dev/null 2>&1 || command -v "$ANSIBLE_BIN" >/dev/null 2>&1; then
          printf '{"method": "wsl", "status": "ok"}'
          return 0
        fi
        printf '{"method": "wsl", "status": "error", "error": "WSL install did not produce a working ansible-playbook (requires WSL2 with a Linux distro installed)"}'
        return 1
      fi
      printf '{"method": "wsl", "status": "error", "error": "WSL not available on this Windows host — Ansible cannot run natively on Windows; install WSL2 first (run \\"wsl --install\\" as Administrator)"}'
      return 1
      ;;
    *)
      # $method is unvalidated, operator-controlled input in direct/sourced
      # use, so encode both occurrences with the same complete JSON encoder.
      printf '{"method": %s, "status": "error", "error": %s}' \
        "$(json_escape "$method")" "$(json_escape "unknown install_method $method")"
      return 1
      ;;
  esac
}

# ---- standalone entry point (skipped when sourced with STAGEHAND_SOURCED=1) ----
if [ "${STAGEHAND_SOURCED:-0}" != "1" ]; then
  RAW=$(cat)
  METHOD=$(printf '%s' "$RAW" | "$RUBY" -rjson -e '
begin
  d = JSON.parse(STDIN.read)
  v = d["install_method"]
  print(v.nil? || v == "" ? "auto" : v)
rescue
  print "auto"
end
' 2>/dev/null)
  [ -n "$METHOD" ] || METHOD="auto"
  OUT=$(install_ansible_run "$METHOD")
  printf '%s\n' "$OUT"
  exit 0
fi
