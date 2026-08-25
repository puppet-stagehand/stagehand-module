#!/bin/sh
# stagehand::ensure_ssh_server — idempotent OpenSSH server install + start on
# this host (Phase 47, D-05/D-09's one-click remediation for the control-repo
# wizard's SSH-reachability readiness check: 47-04-PLAN.md Task 1). Detects
# the package manager (apt-get/dnf/yum/zypper, in that order) rather than
# assuming one — mirrors install_ansible.sh's ordered-detection convention.
# No parameters (input_method: environment, empty parameters block).
#
# Idempotent by design (T-47-11): if sshd is already installed AND actively
# running, this is a no-op — a repeated "provision now" click can never
# reinstall or restart an already-working service.
#
# This script's stdout, on success, is a single JSON object:
#   {"already_present": true}
#   {"already_present": false, "installed": true, "package_manager": "<pm>"}
# A real failure calls die(), which prints "ERROR: <real underlying error>"
# to stderr and exits 1 — never a generic "failed" message (D-09's real-error
# contract starts at the task layer, not just the wizard UI layer).
set -u

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Already-present short-circuit. Debian/Ubuntu's openssh-server package
# registers the systemd unit as "ssh"; RHEL/SUSE families register it as
# "sshd" — checked in that order below since is-active on a nonexistent unit
# simply fails, never errors out this script.
if command -v sshd >/dev/null 2>&1; then
  if systemctl is-active --quiet sshd 2>/dev/null || systemctl is-active --quiet ssh 2>/dev/null; then
    printf '{"already_present": true}\n'
    exit 0
  fi
fi

PM=""
if command -v apt-get >/dev/null 2>&1; then
  PM="apt-get"
elif command -v dnf >/dev/null 2>&1; then
  PM="dnf"
elif command -v yum >/dev/null 2>&1; then
  PM="yum"
elif command -v zypper >/dev/null 2>&1; then
  PM="zypper"
else
  die "no supported package manager found (apt-get/dnf/yum/zypper) on PATH — cannot install openssh-server (PATH=$PATH)"
fi

LOG=$(mktemp 2>/dev/null || printf '/tmp/pcm_ensure_ssh_server.%s' "$$")

# openssh-server is the correct package name across all four families
# targeted here (Debian/Ubuntu apt, RHEL/Fedora dnf/yum, SUSE zypper calls
# the same source package "openssh" — pinned per-family below). This is a
# well-known OS package installed via the OS's own package manager, not a
# console-side npm/pip/cargo dependency — no legitimacy-gate applies.
case "$PM" in
  apt-get)
    apt-get update >"$LOG" 2>&1 && apt-get install -y openssh-server >>"$LOG" 2>&1
    ;;
  dnf)
    dnf install -y openssh-server >"$LOG" 2>&1
    ;;
  yum)
    yum install -y openssh-server >"$LOG" 2>&1
    ;;
  zypper)
    zypper --non-interactive install openssh >"$LOG" 2>&1
    ;;
esac
STATUS=$?
if [ $STATUS -ne 0 ]; then
  REASON=$(tail -c 600 "$LOG" 2>/dev/null | tr '\n' ' ' | tr -d '\000-\037' | tr '"\\' '  ')
  rm -f "$LOG"
  die "openssh-server install via ${PM} failed (exit ${STATUS}): ${REASON}"
fi

# Start + enable whichever service name this distro's openssh package
# registered under — try sshd first (RHEL/SUSE family, and the more common
# name across dnf/yum/zypper targets), fall back to ssh (Debian/Ubuntu).
if systemctl enable --now sshd >>"$LOG" 2>&1; then
  :
elif systemctl enable --now ssh >>"$LOG" 2>&1; then
  :
else
  REASON=$(tail -c 600 "$LOG" 2>/dev/null | tr '\n' ' ' | tr -d '\000-\037' | tr '"\\' '  ')
  rm -f "$LOG"
  die "openssh-server installed via ${PM} but starting/enabling the service failed (tried sshd, ssh): ${REASON}"
fi
rm -f "$LOG"

printf '{"already_present": false, "installed": true, "package_manager": "%s"}\n' "$PM"
