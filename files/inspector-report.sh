#!/usr/bin/env bash
# inspector-report.sh — Puppet Inspector reference adapter: native JSON
# (`puppet-inspector exec ... --format json`, the RunResult contract) →
# compliance.v1. Emits the normalized JSON batch on stdout; POST it (or pipe
# it) to the console's ingestion endpoint. See docs/compliance-schema.md for
# the mapping.
#
#   puppet-inspector exec --local --format json profile.yaml > native.json
#   ./inspector-report.sh --report native.json \
#     | curl -sf -X POST "$CONSOLE/api/v1/compliance/results" \
#            -H "Authorization: Bearer $(cat /etc/puppetlabs/psh-ingest.token)" \
#            -H 'Content-Type: application/json' --data-binary @-
#
# Deliberately built against Inspector's NATIVE JSON reporter, not its
# InSpec-compatible JSON reporter: native JSON's five-way control status
# (passed/failed/skipped/manual/error) maps directly onto compliance.v1's
# five-way status, where InSpec-JSON collapses "error" into "failed" and
# loses that distinction (checked against internal/report/report.go this
# session — inspecControlFor's StatusError branch emits InSpec status
# "failed", same as a real check failure).
set -euo pipefail

REPORT="" TOOL_VERSION=""
while [ $# -gt 0 ]; do
  case "$1" in
    --report) REPORT="$2"; shift 2 ;;
    --tool-version) TOOL_VERSION="$2"; shift 2 ;;
    *) echo "usage: $0 --report <native-run-result.json> [--tool-version <puppet-inspector version>]" >&2; exit 2 ;;
  esac
done
[ -n "$REPORT" ] && [ -r "$REPORT" ] || { echo "readable --report <native-run-result.json> is required" >&2; exit 2; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 2; }

REPORT="$REPORT" TOOL_VERSION="$TOOL_VERSION" python3 <<'PYEOF'
import json, os, sys, datetime

path = os.environ["REPORT"]
tool_version = os.environ.get("TOOL_VERSION", "")

with open(path) as f:
    run = json.load(f)

# Status collapse: Inspector's engine.Status is already five-way and maps
# onto compliance.v1 near 1:1. "manual" (needs a human to review evidence,
# not yet a pass/fail) and "skipped" (profile not applicable to this node,
# from a control-level or whole-profile `supports:` mismatch) map the same
# way the OpenSCAP adapter maps its own "not yet decided" outcomes.
STATUS = {
    "passed": "pass",
    "failed": "fail",
    "error": "error",
    "manual": "warn",
    "skipped": "not-applicable",
}
# Inspector's Impact is a 0.0-1.0 float (InSpec convention); compliance.v1
# has no "critical" tier, so >=0.7 collapses into "high" rather than being
# lost. Absent/zero impact (e.g. a control that never set one) is "unknown",
# not silently "low" -- an unrated control is not the same claim as a
# reviewed-and-low-impact one.
def severity(impact):
    if impact is None:
        return "unknown"
    if impact >= 0.7:
        return "high"
    if impact >= 0.4:
        return "medium"
    if impact > 0.0:
        return "low"
    return "unknown"

node = run.get("node") or ""
if not node:
    sys.stderr.write("warning: native report has no \"node\" (certname) -- falling back to hostname\n")
    import socket
    node = socket.getfqdn() or socket.gethostname()

profile_name = run.get("profile") or "unknown"
profile_version = run.get("version") or ""
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

results = []
for c in run.get("controls", []):
    status = STATUS.get(c.get("status"))
    if status is None:
        continue  # unknown status value -- never fabricate an outcome
    refs = c.get("refs") or {}
    # refs is {framework: id}, e.g. {"cis": "5.2.8", "nist": "AC-6"}. There is
    # no single compliance.v1 field for a multi-framework crosswalk, so the
    # CIS ref (Inspector/InSpec's most common anchor) becomes remediation_ref
    # when present; the full crosswalk is not lost, just not representable in
    # v1 -- a real gap, noted in docs/compliance-schema.md's Inspector section.
    remediation_ref = refs.get("cis") or ""
    message = c.get("error") or ""
    if not message and c.get("status") == "failed":
        reasons = []
        for chk in c.get("checks") or []:
            if not chk.get("passed") and chk.get("reason"):
                reasons.append(chk["reason"])
        message = "; ".join(reasons)
    results.append({
        "node": node,
        "benchmark_id": profile_name,
        "profile_id": profile_version,
        "control_id": c.get("id") or "unknown",
        "status": status,
        "severity": severity(c.get("impact")),
        "timestamp": now,
        **({"remediation_ref": remediation_ref} if remediation_ref else {}),
        **({"message": message} if message else {}),
    })

if not results:
    sys.stderr.write("no controls found in native report -- is this a puppet-inspector RunResult?\n")
    sys.exit(1)

json.dump({
    "schema_version": "compliance.v1",
    "source": {
        "scanner": "puppet-inspector",
        **({"scanner_version": tool_version} if tool_version else {}),
        "adapter_version": "1.0.0",
    },
    "results": results,
}, sys.stdout)
print()
PYEOF
