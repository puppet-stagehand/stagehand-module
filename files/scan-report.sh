#!/usr/bin/env bash
# scan-report.sh — OpenSCAP reference adapter: XCCDF/ARF results → compliance.v1
#
# Emits the normalized JSON batch on stdout; POST it (or pipe it) to the
# console's ingestion endpoint. See docs/compliance-schema.md for the mapping.
#
#   oscap xccdf eval --profile <profile> --results-arf arf.xml <datastream.xml> || true
#   ./scan-report.sh --arf arf.xml --certname "$(puppet config print certname)" \
#     | curl -sf -X POST "$CONSOLE/api/v1/compliance/results" \
#            -H "Authorization: Bearer $(cat /etc/puppetlabs/psh-ingest.token)" \
#            -H 'Content-Type: application/json' --data-binary @-
#
# (oscap exits 2 when any rule fails — hence the `|| true`.)
set -euo pipefail

ARF="" CERTNAME="$(hostname -f 2>/dev/null || hostname)"
while [ $# -gt 0 ]; do
  case "$1" in
    --arf|--xccdf) ARF="$2"; shift 2 ;;
    --certname)    CERTNAME="$2"; shift 2 ;;
    *) echo "usage: $0 --arf <results.xml> [--certname <name>]" >&2; exit 2 ;;
  esac
done
[ -n "$ARF" ] && [ -r "$ARF" ] || { echo "readable --arf <results.xml> is required" >&2; exit 2; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 2; }

ARF="$ARF" CERTNAME="$CERTNAME" python3 <<'PYEOF'
import json, os, sys, xml.etree.ElementTree as ET

path, certname = os.environ["ARF"], os.environ["CERTNAME"]

def local(tag):  # namespace-agnostic tag name
    return tag.rsplit('}', 1)[-1]

# Result-value collapse per docs/compliance-schema.md.
STATUS = {
    "pass": "pass", "fixed": "pass",
    "fail": "fail",
    "error": "error", "unknown": "error",
    "notapplicable": "not-applicable",
    "notchecked": "warn", "notselected": "warn", "informational": "warn",
}
SEV = {"low": "low", "medium": "medium", "high": "high"}

root = ET.parse(path).getroot()
results = []
for tr in (e for e in root.iter() if local(e.tag) == "TestResult"):
    profile = ""
    benchmark = ""
    end_time = tr.get("end-time") or tr.get("start-time") or ""
    for child in tr:
        if local(child.tag) == "profile":
            profile = child.get("idref") or ""
        if local(child.tag) == "benchmark":
            benchmark = child.get("id") or child.get("href") or ""
    if not benchmark:
        for e in root.iter():
            if local(e.tag) == "Benchmark":
                benchmark = e.get("id") or ""
                break
    for rr in (e for e in tr if local(e.tag) == "rule-result"):
        raw = ""
        message = ""
        for c in rr:
            if local(c.tag) == "result":
                raw = (c.text or "").strip()
            elif local(c.tag) == "message" and not message:
                message = (c.text or "").strip()
        status = STATUS.get(raw)
        if status is None:
            continue  # e.g. empty result elements
        results.append({
            "node": certname,
            "benchmark_id": benchmark or "openscap",
            "profile_id": profile,
            "control_id": rr.get("idref") or "unknown",
            "status": status,
            "severity": SEV.get((rr.get("severity") or "").lower(), "unknown"),
            "timestamp": rr.get("time") or end_time,
            "message": message,
        })

if not results:
    sys.stderr.write("no rule-results found — is this an XCCDF/ARF results file?\n")
    sys.exit(1)

json.dump({
    "schema_version": "compliance.v1",
    "source": {"scanner": "openscap", "adapter_version": "1.0.0"},
    "results": results,
}, sys.stdout)
print()
PYEOF
