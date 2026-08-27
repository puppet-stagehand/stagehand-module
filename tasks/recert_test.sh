#!/bin/sh
# stagehand::recert test harness (02-02-PLAN.md Task 1). Follows
# patch_test.sh's env -i invocation pattern; recert.json's input_method is
# "environment" (undeclared parameters block, PT_ext_* passthrough by
# design), so params are fed via PT_* env vars, not stdin JSON. recert.sh
# had zero test coverage before this phase.
#
# Cases (see 02-02-PLAN.md Task 1 <behavior>):
#   (1) PT_challenge unset -> setup-gate die()/exit 1 (unchanged regression).
#   (2) PT_ext_department containing an embedded double-quote and colon
#       round-trips exactly through YAML (AUDIT-01 regression).
#   (3) PT_ext_role containing a literal backslash round-trips exactly
#       through YAML (AUDIT-01 regression).
#   (4) simulated puppet agent RC=1 -> embedded JSON error, exit 0 (AUDIT-04).
#   (5) simulated puppet agent RC=3 (catch-all) -> embedded JSON error,
#       exit 0 (AUDIT-04).
#   (6) simulated puppet agent RC=0 (success) -> embedded JSON success,
#       exit 0 (AUDIT-04).
#   (7) simulated mv ssldir failure (SSLDIR missing) -> embedded JSON
#       error, exit 0 (AUDIT-04).

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd) || exit 1
TARGET_SH="$SCRIPT_DIR/recert.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
info() { printf '>>> %s\n' "$*"; }

[ -f "$TARGET_SH" ] || fail "recert.sh not found at $TARGET_SH"
command -v jq >/dev/null 2>&1 || fail "jq is required to run this test harness"
command -v ruby >/dev/null 2>&1 || fail "ruby is required to run this test harness (YAML round-trip assertions)"

WORK=$(mktemp -d) || fail "mktemp -d failed"
trap 'rm -rf "$WORK"' EXIT

SHIMDIR="$WORK/shims"
mkdir -p "$SHIMDIR" || fail "could not create shim dir"

# write_puppet_stub CONFDIR SSLDIR AGENT_RC
# Writes a PATH shim named "puppet" that answers the exact 4 invocations
# recert.sh makes: `config print confdir`, `config print ssldir`,
# `agent -t --waitforcert 60` (exits AGENT_RC), and
# `facts show trusted.extensions`.
write_puppet_stub() {
  confdir="$1"
  ssldir="$2"
  agent_rc="$3"
  printf '%s\n' "$confdir" > "$WORK/stub-confdir"
  printf '%s\n' "$ssldir" > "$WORK/stub-ssldir"
  cat > "$SHIMDIR/puppet" <<SHIM
#!/bin/sh
case "\$*" in
  "config print confdir") cat "$WORK/stub-confdir"; exit 0 ;;
  "config print ssldir") cat "$WORK/stub-ssldir"; exit 0 ;;
  "agent -t --waitforcert 60") exit $agent_rc ;;
  "facts show trusted.extensions") printf 'trusted.extensions: {}\n'; exit 0 ;;
  *) printf 'STUB: unhandled puppet invocation: %s\n' "\$*" >&2; exit 99 ;;
esac
SHIM
  chmod +x "$SHIMDIR/puppet"
}

TEST_PATH="$SHIMDIR:/usr/bin:/bin:/usr/sbin:/sbin"

run_recert() {
  # shellcheck disable=SC2086
  env -i \
    PATH="$TEST_PATH" \
    HOME="$HOME" \
    STAGEHAND_RECERT_PUPPET_BIN="$SHIMDIR/puppet" \
    ${PT_challenge:+PT_challenge="$PT_challenge"} \
    ${PT_ext_department:+PT_ext_department="$PT_ext_department"} \
    ${PT_ext_role:+PT_ext_role="$PT_ext_role"} \
    sh "$TARGET_SH"
}

reset() {
  unset PT_challenge PT_ext_department PT_ext_role
}

# assert_yaml_roundtrip FILE YAML_KEY EXPECTED LABEL
# Parses FILE's extension_requests.<YAML_KEY> via ruby -ryaml and confirms
# it equals EXPECTED exactly (not just "parses without crashing").
assert_yaml_roundtrip() {
  file="$1"
  yaml_key="$2"
  expected="$3"
  label="$4"
  actual=$(YAML_FILE="$file" YAML_KEY="$yaml_key" ruby -ryaml -e '
    data = YAML.safe_load(File.read(ENV["YAML_FILE"]))
    val = data.dig("extension_requests", ENV["YAML_KEY"])
    print val.nil? ? "" : val
  ') || fail "$label: ruby YAML parse failed for $file"
  [ "$actual" = "$expected" ] || fail "$label: round-trip mismatch — expected [$expected], got [$actual]"
}

# --- Case 1: PT_challenge unset -> setup-gate die()/exit 1 (unchanged). ---
reset
write_puppet_stub "$WORK/case1/confdir" "$WORK/case1/ssldir" 0
OUT=$(run_recert 2>"$WORK/stderr.1")
RC=$?
STDERR=$(cat "$WORK/stderr.1")
[ "$RC" -eq 1 ] || fail "case 1 (challenge unset): expected exit 1, got $RC. stdout: $OUT"
case "$STDERR" in
  *'challenge parameter is required'*) : ;;
  *) fail "case 1 (challenge unset): expected stderr to contain 'challenge parameter is required', got: $STDERR" ;;
esac
info "case 1 (challenge unset): OK (exit 1, setup gate unchanged)"

# --- Case 2: PT_ext_department with an embedded double-quote and colon round-trips. ---
reset
CONFDIR2="$WORK/case2/confdir"; SSLDIR2="$WORK/case2/ssldir"
mkdir -p "$CONFDIR2" "$SSLDIR2" || fail "case 2 setup: mkdir failed"
write_puppet_stub "$CONFDIR2" "$SSLDIR2" 0
PT_challenge='tok-2'
PT_ext_department='finance": injected_key: true'
OUT=$(run_recert)
RC=$?
[ "$RC" -eq 0 ] || fail "case 2 (department quote/colon): expected exit 0, got $RC. stdout: $OUT"
assert_yaml_roundtrip "$CONFDIR2/csr_attributes.yaml" "pp_department" "$PT_ext_department" "case 2 (department quote/colon)"
info "case 2 (department quote/colon): OK (YAML round-trips exactly)"

# --- Case 3: PT_ext_role with a literal backslash round-trips. ---
reset
CONFDIR3="$WORK/case3/confdir"; SSLDIR3="$WORK/case3/ssldir"
mkdir -p "$CONFDIR3" "$SSLDIR3" || fail "case 3 setup: mkdir failed"
write_puppet_stub "$CONFDIR3" "$SSLDIR3" 0
PT_challenge='tok-3'
PT_ext_role='back\slash\role'
OUT=$(run_recert)
RC=$?
[ "$RC" -eq 0 ] || fail "case 3 (role backslash): expected exit 0, got $RC. stdout: $OUT"
assert_yaml_roundtrip "$CONFDIR3/csr_attributes.yaml" "pp_role" "$PT_ext_role" "case 3 (role backslash)"
info "case 3 (role backslash): OK (YAML round-trips exactly)"

# --- Case 4: simulated puppet agent RC=1 -> embedded JSON error, exit 0. ---
reset
CONFDIR4="$WORK/case4/confdir"; SSLDIR4="$WORK/case4/ssldir"
mkdir -p "$CONFDIR4" "$SSLDIR4" || fail "case 4 setup: mkdir failed"
write_puppet_stub "$CONFDIR4" "$SSLDIR4" 1
PT_challenge='tok-4'
OUT=$(run_recert)
RC=$?
[ "$RC" -eq 0 ] || fail "case 4 (agent RC=1): expected exit 0, got $RC. stdout: $OUT"
STATUS4=$(printf '%s' "$OUT" | jq -r '.status' 2>/dev/null)
ERROR4=$(printf '%s' "$OUT" | jq -r '.error' 2>/dev/null)
[ "$STATUS4" = "error" ] || fail "case 4 (agent RC=1): expected status 'error', got: $STATUS4. stdout: $OUT"
case "$ERROR4" in
  *'agent exited 1'*) : ;;
  *) fail "case 4 (agent RC=1): expected error to mention 'agent exited 1', got: $ERROR4" ;;
esac
info "case 4 (agent RC=1): OK (embedded JSON error, exit 0)"

# --- Case 5: simulated puppet agent RC=3 (catch-all) -> embedded JSON error, exit 0. ---
reset
CONFDIR5="$WORK/case5/confdir"; SSLDIR5="$WORK/case5/ssldir"
mkdir -p "$CONFDIR5" "$SSLDIR5" || fail "case 5 setup: mkdir failed"
write_puppet_stub "$CONFDIR5" "$SSLDIR5" 3
PT_challenge='tok-5'
OUT=$(run_recert)
RC=$?
[ "$RC" -eq 0 ] || fail "case 5 (agent RC=3): expected exit 0, got $RC. stdout: $OUT"
STATUS5=$(printf '%s' "$OUT" | jq -r '.status' 2>/dev/null)
ERROR5=$(printf '%s' "$OUT" | jq -r '.error' 2>/dev/null)
[ "$STATUS5" = "error" ] || fail "case 5 (agent RC=3): expected status 'error', got: $STATUS5. stdout: $OUT"
case "$ERROR5" in
  *'agent exited 3'*) : ;;
  *) fail "case 5 (agent RC=3): expected error to mention 'agent exited 3', got: $ERROR5" ;;
esac
info "case 5 (agent RC=3): OK (embedded JSON error, exit 0)"

# --- Case 6: simulated puppet agent RC=0 (success) -> embedded JSON success. ---
reset
CONFDIR6="$WORK/case6/confdir"; SSLDIR6="$WORK/case6/ssldir"
mkdir -p "$CONFDIR6" "$SSLDIR6" || fail "case 6 setup: mkdir failed"
write_puppet_stub "$CONFDIR6" "$SSLDIR6" 0
PT_challenge='tok-6'
OUT=$(run_recert)
RC=$?
[ "$RC" -eq 0 ] || fail "case 6 (success): expected exit 0, got $RC. stdout: $OUT"
STATUS6=$(printf '%s' "$OUT" | jq -r '.status' 2>/dev/null)
SSL_BACKUP6=$(printf '%s' "$OUT" | jq -r '.ssl_backup' 2>/dev/null)
[ "$STATUS6" = "recertified" ] || fail "case 6 (success): expected status 'recertified', got: $STATUS6. stdout: $OUT"
case "$SSL_BACKUP6" in
  "${SSLDIR6}.recert-"*) : ;;
  *) fail "case 6 (success): expected ssl_backup to start with ${SSLDIR6}.recert-, got: $SSL_BACKUP6" ;;
esac
[ -d "$SSL_BACKUP6" ] || fail "case 6 (success): ssl_backup directory does not exist on disk: $SSL_BACKUP6"
info "case 6 (success): OK (embedded JSON success, exit 0)"

# --- Case 7: simulated mv ssldir failure (SSLDIR does not exist) -> embedded JSON error. ---
reset
CONFDIR7="$WORK/case7/confdir"
SSLDIR7="$WORK/case7/ssldir_missing"
mkdir -p "$CONFDIR7" || fail "case 7 setup: mkdir failed"
write_puppet_stub "$CONFDIR7" "$SSLDIR7" 0
PT_challenge='tok-7'
OUT=$(run_recert)
RC=$?
[ "$RC" -eq 0 ] || fail "case 7 (mv failure): expected exit 0, got $RC. stdout: $OUT"
STATUS7=$(printf '%s' "$OUT" | jq -r '.status' 2>/dev/null)
ERROR7=$(printf '%s' "$OUT" | jq -r '.error' 2>/dev/null)
[ "$STATUS7" = "error" ] || fail "case 7 (mv failure): expected status 'error', got: $STATUS7. stdout: $OUT"
case "$ERROR7" in
  *'could not move ssldir'*) : ;;
  *) fail "case 7 (mv failure): expected error to mention 'could not move ssldir', got: $ERROR7" ;;
esac
info "case 7 (mv failure): OK (embedded JSON error, exit 0)"

# --- Case 8: a Puppet ssldir containing JSON-special characters round-trips
# through the success payload without corrupting its JSON contract. ---
reset
CONFDIR8="$WORK/case8/confdir"
SSLDIR8=$(printf '%s/case8/ssl"dir\nwith-tab\t' "$WORK")
mkdir -p "$CONFDIR8" "$SSLDIR8" || fail "case 8 setup: mkdir failed"
write_puppet_stub "$CONFDIR8" "$SSLDIR8" 0
PT_challenge='tok-8'
OUT=$(run_recert)
RC=$?
[ "$RC" -eq 0 ] || fail "case 8 (JSON-special ssldir): expected exit 0, got $RC. stdout: $OUT"
SSL_BACKUP8=$(printf '%s' "$OUT" | jq -er '.ssl_backup' 2>/dev/null) \
  || fail "case 8 (JSON-special ssldir): output is not valid success JSON: $OUT"
case "$SSL_BACKUP8" in
  "${SSLDIR8}.recert-"*) : ;;
  *) fail "case 8 (JSON-special ssldir): ssl_backup did not round-trip: $SSL_BACKUP8" ;;
esac
[ -d "$SSL_BACKUP8" ] || fail "case 8 (JSON-special ssldir): backup directory missing: $SSL_BACKUP8"
info "case 8 (JSON-special ssldir): OK (valid JSON, path round-trips)"

info "all recert.sh safety cases PASSED"
exit 0
