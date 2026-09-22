#!/bin/sh
# patchbot — external fact (facts.d, pluginsynced from the stagehand module;
# formerly named pcm_patch, from before the pcm -> stagehand rename).
#
# Patch posture the console reads (Patching page, Action Center, and — when
# the Labs `computed_findings` flag is on — the correlation engine). The
# console's PQL queries (backend/internal/httpapi/patching.go, dashboard.go,
# hipogamo.go) already query this fact by its `patchbot` name.
#
#   {"patchbot": {
#      "available": 12, "security": 3, "reboot_required": false,
#      "last_checked": "<ISO8601 UTC>", "manager": "apt",
#      "repos": ["noble","noble-updates","noble-security"],
#      "packages": [
#        {"name":"openssl","arch":"amd64","current":"3.0.2-0ubuntu1.15",
#         "available":"3.0.2-0ubuntu1.18","repo":"noble-security","security":true}
#      ],
#      "package_count": 12, "truncated": false
#   }}
#
# `available` / `security` / `reboot_required` / `last_checked` are unchanged
# from the counts-only version — the Patching page keeps working untouched.
#
# `packages` and `repos` are what make fix state computable. Given an
# advisory that says "fixed in 3.0.7-28", the console can answer three
# different questions per node, and only with BOTH fields:
#
#   fixable_now  — an update at or above the fixed version is available from
#                  a repo this node actually has configured
#   repo_gap     — the vendor published a fix, but no configured repo carries
#                  it. A stale mirror wearing a CVE costume; no other tool on
#                  the market can tell you this, because none of them know
#                  what repos your node has.
#   no_fix       — nothing published. Track it, don't nag about it.
#
# Structured JSON output requires Facter 4 (Puppet 8 — i.e. Puppet Core; the
# only stack we target, see docs: NO OpenVox).
#
# Cost note: this fact is per-node state in PuppetDB, so the package list is
# capped (PCM_PATCH_MAX_PACKAGES, default 500) and reports `truncated` when it
# bites. The counts are always exact — only the detail array is capped.
#
# Renamed from the legacy `patches` fact at the pcm cutover (2026-07-21).
# Deploy: pcm/facts.d via pluginsync once pcm is in the environment
# modulepath, or drop into /etc/puppetlabs/facter/facts.d/ (chmod 755).
set -u

LIMIT=${PCM_PATCH_MAX_PACKAGES:-500}

AVAILABLE=0
SECURITY=0
REBOOT=false
MANAGER=""
PACKAGES=""
REPOS=""
TOTAL=0

# ---------------------------------------------------------------- apt -----
if command -v apt-get >/dev/null 2>&1; then
  MANAGER="apt"

  # Simulated dist-upgrade against the package cache only (no network). The
  # pcm patch task and the pcm::patching refresh timer keep the cache fresh.
  #
  #   Inst sed [4.9-2build1] (4.9-2ubuntu0.24.04.1 Ubuntu:24.04/noble-updates,
  #                           Ubuntu:24.04/noble-security [amd64])
  #
  # A package pulled in fresh as a dependency has no [current] bracket, so the
  # third field is parsed defensively rather than positionally.
  UPGR=$(apt-get -s dist-upgrade 2>/dev/null | grep '^Inst ' || true)

  if [ -n "$UPGR" ]; then
    TOTAL=$(printf '%s\n' "$UPGR" | wc -l | tr -d ' ')
    AVAILABLE=$TOTAL
    SECURITY=$(printf '%s\n' "$UPGR" | grep -c -- '-security' || true)
    PACKAGES=$(printf '%s\n' "$UPGR" | awk -v lim="$LIMIT" '
      function esc(s) { gsub(/\\/,"\\\\",s); gsub(/"/,"\\\"",s); return s }
      NR > lim { exit }
      {
        name = $2
        cur  = ""
        if ($3 ~ /^\[/) { cur = $3; gsub(/[][]/, "", cur) }

        p = index($0, "(")
        rest = (p ? substr($0, p + 1) : "")
        split(rest, r, " ")
        avail = r[1]

        # Origins look like "Ubuntu:24.04/noble-updates, Ubuntu:24.04/noble-security".
        # Take the suite of the first one as the repo; the whole list decides
        # the security flag.
        repo = ""
        if (match(rest, /\/[A-Za-z0-9._-]+/)) {
          repo = substr(rest, RSTART + 1, RLENGTH - 1)
        }
        sec = (rest ~ /-security/) ? "true" : "false"

        arch = ""
        if (match(rest, /\[[A-Za-z0-9_-]+\][)]?[ ]*$/)) {
          arch = substr(rest, RSTART + 1, RLENGTH - 1)
          gsub(/[])] */, "", arch)
        }

        printf "%s{\"name\":\"%s\",\"arch\":\"%s\",\"current\":\"%s\",\"available\":\"%s\",\"repo\":\"%s\",\"security\":%s}",
               (NR > 1 ? "," : ""), esc(name), esc(arch), esc(cur), esc(avail), esc(repo), sec
      }')
  fi

  # Configured suites, from the resolved policy rather than sources.list, so
  # pinning and deb822 sources are both accounted for.
  REPOS=$(apt-cache policy 2>/dev/null \
    | grep -o 'a=[A-Za-z0-9._-]*' | cut -d= -f2 \
    | grep -v '^now$' | sort -u \
    | awk '{ printf "%s\"%s\"", (NR > 1 ? "," : ""), $0 }')

  [ -f /var/run/reboot-required ] && REBOOT=true

# ---------------------------------------------------------- dnf / yum -----
elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
  if command -v dnf >/dev/null 2>&1; then MANAGER="dnf"; else MANAGER="yum"; fi

  # `check-update -q` exits 100 with a package list when updates exist:
  #   openssl.x86_64   1:3.0.7-28.el9   rhel-9-appstream-rpms
  LIST=$($MANAGER -q check-update 2>/dev/null \
         | awk 'NF>=3 && $1 !~ /^Obsoleting/ && $1 !~ /^Last/ && $1 ~ /\./ {print}' || true)

  # Security advisories name their packages; used to flag rows rather than
  # just to produce a count, so `security` is per-package here.
  SECLIST=$($MANAGER -q updateinfo list security --available 2>/dev/null \
            | awk 'NF>=3 {print $NF}' || true)

  if [ -n "$LIST" ]; then
    TOTAL=$(printf '%s\n' "$LIST" | wc -l | tr -d ' ')
    AVAILABLE=$TOTAL
    PACKAGES=$(printf '%s\n' "$LIST" | awk -v lim="$LIMIT" -v sec="$SECLIST" '
      function esc(s) { gsub(/\\/,"\\\\",s); gsub(/"/,"\\\"",s); return s }
      BEGIN { n = split(sec, s, "\n"); for (i = 1; i <= n; i++) if (s[i] != "") secmap[s[i]] = 1 }
      NR > lim { exit }
      {
        nv = $1                       # name.arch
        arch = ""
        idx = 0
        # rsplit on the last dot: package names contain dots, arches do not.
        for (i = length(nv); i > 0; i--) if (substr(nv, i, 1) == ".") { idx = i; break }
        if (idx) { arch = substr(nv, idx + 1); name = substr(nv, 1, idx - 1) } else { name = nv }

        avail = $2
        repo  = $3
        # updateinfo reports full NEVRA; match on the leading name.arch.
        isec = "false"
        for (k in secmap) if (index(k, nv) == 1 || index(k, name "-") == 1) { isec = "true"; break }

        printf "%s{\"name\":\"%s\",\"arch\":\"%s\",\"current\":\"\",\"available\":\"%s\",\"repo\":\"%s\",\"security\":%s}",
               (NR > 1 ? "," : ""), esc(name), esc(arch), esc(avail), esc(repo), isec
      }')
    SECURITY=$($MANAGER -q updateinfo list security --available 2>/dev/null | grep -c '/' || true)
  fi

  REPOS=$($MANAGER -q repolist --enabled 2>/dev/null \
    | awk 'NR>1 && NF>=1 && $1 !~ /^repo[ -]?id/ {print $1}' \
    | sort -u | awk '{ printf "%s\"%s\"", (NR > 1 ? "," : ""), $0 }')

  # needs-restarting -r: exit 0 = no reboot, exit 1 = reboot required. Only an
  # explicit 1 is trusted — a missing plugin exits differently.
  if command -v needs-restarting >/dev/null 2>&1; then
    needs-restarting -r >/dev/null 2>&1
    [ $? -eq 1 ] && REBOOT=true
  fi
fi

TRUNCATED=false
[ "$TOTAL" -gt "$LIMIT" ] && TRUNCATED=true

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '{"patchbot": {"available": %s, "security": %s, "reboot_required": %s, "last_checked": "%s", "manager": "%s", "repos": [%s], "packages": [%s], "package_count": %s, "truncated": %s}}\n' \
  "${AVAILABLE:-0}" "${SECURITY:-0}" "$REBOOT" "$NOW" "$MANAGER" \
  "$REPOS" "$PACKAGES" "${TOTAL:-0}" "$TRUNCATED"
