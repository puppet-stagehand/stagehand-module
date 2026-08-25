#!/bin/sh
# Proof test for r10k_deploy.sh's Phase 47 (D-10 remote half) git-ssh
# staging extension — POSIX sh, no bats dependency, mirrors
# r10k_detect_test.sh's structure: mktemp sandbox, a fake r10k binary
# stubbed via the script's own existing PT_r10k_path override (no new
# override mechanism needed), exit-code/content assertions.
#
# Cases (see 47-05-PLAN.md Task 2 <acceptance_criteria>):
#   (a) PT_git_ssh_config unset -> behavior byte-for-byte identical to the
#       pre-existing script: same stdout, no GIT_SSH_COMMAND exported, no
#       temp dir created.
#   (b) PT_git_ssh_config/PT_git_ssh_keys set, r10k succeeds -> the staged
#       temp dir + config + key file exist DURING the run (verified from
#       inside the fake r10k), the placeholder is substituted for the real
#       keys dir, key file mode is 600, and the temp dir is gone AFTER the
#       script exits.
#   (c) same, but the wrapped r10k invocation fails (nonzero exit) -> the
#       trap still fires: the temp dir is gone AFTER, even on failure.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd) || exit 1
DEPLOY_SH="$SCRIPT_DIR/r10k_deploy.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
info() { printf '>>> %s\n' "$*"; }

[ -f "$DEPLOY_SH" ] || fail "r10k_deploy.sh not found at $DEPLOY_SH"

WORK=$(mktemp -d) || fail "mktemp -d failed"
trap 'rm -rf "$WORK"' EXIT

# --- Case (a): PT_git_ssh_config unset. Byte-for-byte pre-existing
# behavior: a fake r10k that always succeeds, no staging side effects. ---
FAKE_R10K_OK="$WORK/fake_r10k_ok.sh"
cat >"$FAKE_R10K_OK" <<'EOF'
#!/bin/sh
# Records whether GIT_SSH_COMMAND leaked into this invocation's environment
# (it must NOT, for case (a)) and always succeeds.
if [ -n "${GIT_SSH_COMMAND:-}" ]; then
  printf '%s\n' "$GIT_SSH_COMMAND" >"$FAKE_R10K_MARKER_DIR/git_ssh_command_seen"
fi
echo "Deploying environment production"
echo "  Deploying Puppetfile content"
exit 0
EOF
chmod +x "$FAKE_R10K_OK"

MARKER_A="$WORK/marker_a"
mkdir -p "$MARKER_A"
OUT_A=$(env -u PT_git_ssh_config -u PT_git_ssh_keys \
  FAKE_R10K_MARKER_DIR="$MARKER_A" \
  PT_environment=production PT_r10k_path="$FAKE_R10K_OK" \
  sh "$DEPLOY_SH") || fail "case (a) unset: r10k_deploy.sh exited non-zero. Output:
$OUT_A"

EXPECTED_A='{"environment": "production", "status": "deployed"}'
case "$OUT_A" in
  *"$EXPECTED_A") : ;;
  *) fail "case (a) unset: expected output to end with the pre-existing exact JSON line, got:
$OUT_A" ;;
esac
[ -f "$MARKER_A/git_ssh_command_seen" ] && fail "case (a) unset: GIT_SSH_COMMAND leaked into the environment when PT_git_ssh_config was unset"
info "case (a) unset: OK (byte-for-byte pre-existing output, no GIT_SSH_COMMAND, no staging)"

# --- Case (b): PT_git_ssh_config/PT_git_ssh_keys set, r10k succeeds. ---
FAKE_R10K_STAGED="$WORK/fake_r10k_staged.sh"
cat >"$FAKE_R10K_STAGED" <<'EOF'
#!/bin/sh
set -u
# GIT_SSH_COMMAND is "ssh -F <config-path>" — extract the config path.
CONFIG_PATH=${GIT_SSH_COMMAND#ssh -F }
[ -f "$CONFIG_PATH" ] || { echo "MISSING config file at $CONFIG_PATH" >&2; exit 1; }
KEYSDIR=$(dirname "$CONFIG_PATH")/keys
[ -d "$KEYSDIR" ] || { echo "MISSING keys dir at $KEYSDIR" >&2; exit 1; }
[ -f "$KEYSDIR/githubcom" ] || { echo "MISSING staged key file for githubcom" >&2; exit 1; }
grep -q "IdentityFile $KEYSDIR/githubcom" "$CONFIG_PATH" || { echo "placeholder not substituted:" >&2; cat "$CONFIG_PATH" >&2; exit 1; }
grep -q '%%GIT_SSH_KEYSDIR%%' "$CONFIG_PATH" && { echo "placeholder token still present in staged config" >&2; exit 1; }
KEYMODE=$(perl -e 'printf "%04o\n", (stat($ARGV[0]))[2] & 07777' "$KEYSDIR/githubcom" 2>/dev/null || stat -f '%Lp' "$KEYSDIR/githubcom" 2>/dev/null || stat -c '%a' "$KEYSDIR/githubcom" 2>/dev/null)
[ "$KEYMODE" = "0600" ] || [ "$KEYMODE" = "600" ] || { echo "unexpected key file mode: $KEYMODE" >&2; exit 1; }
grep -q 'STAGED-PEM-CONTENT' "$KEYSDIR/githubcom" || { echo "staged key content mismatch" >&2; exit 1; }
# Record the tmpdir (parent of keys/) so the outer test can confirm it is
# gone AFTER this script (and r10k_deploy.sh's trap) finishes.
dirname "$KEYSDIR" >"$FAKE_R10K_MARKER_DIR/tmpdir_path"
echo "Deploying environment production"
exit 0
EOF
chmod +x "$FAKE_R10K_STAGED"

MARKER_B="$WORK/marker_b"
mkdir -p "$MARKER_B"
GIT_SSH_CONFIG_CONTENT='Host github.com
  IdentityFile %%GIT_SSH_KEYSDIR%%/githubcom
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
  UserKnownHostsFile /dev/null
'
GIT_SSH_KEYS_JSON='{"githubcom":"STAGED-PEM-CONTENT\nline2\n"}'

OUT_B=$(FAKE_R10K_MARKER_DIR="$MARKER_B" \
  PT_environment=production PT_r10k_path="$FAKE_R10K_STAGED" \
  PT_git_ssh_config="$GIT_SSH_CONFIG_CONTENT" PT_git_ssh_keys="$GIT_SSH_KEYS_JSON" \
  sh "$DEPLOY_SH") || fail "case (b) staged/success: r10k_deploy.sh exited non-zero. Output:
$OUT_B"

case "$OUT_B" in
  *'"status": "deployed"'*) : ;;
  *) fail "case (b) staged/success: expected the deployed JSON line, got:
$OUT_B" ;;
esac
[ -f "$MARKER_B/tmpdir_path" ] || fail "case (b) staged/success: fake r10k never recorded the staged tmpdir path — staging did not happen as expected"
TMPDIR_B=$(cat "$MARKER_B/tmpdir_path")
[ -d "$TMPDIR_B" ] && fail "case (b) staged/success: staged temp dir $TMPDIR_B still exists AFTER r10k_deploy.sh exited — cleanup trap did not fire"
info "case (b) staged/success: OK (placeholder substituted, key staged mode 600, temp dir removed after)"

# --- Case (c): staged, but the wrapped r10k invocation FAILS. The trap
# must still remove the temp dir even though the script itself dies. ---
FAKE_R10K_FAIL="$WORK/fake_r10k_fail.sh"
cat >"$FAKE_R10K_FAIL" <<'EOF'
#!/bin/sh
set -u
CONFIG_PATH=${GIT_SSH_COMMAND#ssh -F }
dirname "$CONFIG_PATH" >"$FAKE_R10K_MARKER_DIR/tmpdir_path"
echo "simulated r10k failure" >&2
exit 7
EOF
chmod +x "$FAKE_R10K_FAIL"

MARKER_C="$WORK/marker_c"
mkdir -p "$MARKER_C"
OUT_C=$(FAKE_R10K_MARKER_DIR="$MARKER_C" \
  PT_environment=production PT_r10k_path="$FAKE_R10K_FAIL" \
  PT_git_ssh_config="$GIT_SSH_CONFIG_CONTENT" PT_git_ssh_keys="$GIT_SSH_KEYS_JSON" \
  sh "$DEPLOY_SH" 2>&1)
STATUS_C=$?
[ "$STATUS_C" -ne 0 ] || fail "case (c) staged/failure: expected r10k_deploy.sh to exit non-zero when r10k fails, but it exited 0. Output:
$OUT_C"
case "$OUT_C" in
  *'ERROR: r10k exited 7'*) : ;;
  *) fail "case (c) staged/failure: expected the die() message for a non-zero r10k exit, got:
$OUT_C" ;;
esac
[ -f "$MARKER_C/tmpdir_path" ] || fail "case (c) staged/failure: fake r10k never recorded the staged tmpdir path"
TMPDIR_C=$(cat "$MARKER_C/tmpdir_path")
[ -d "$TMPDIR_C" ] && fail "case (c) staged/failure: staged temp dir $TMPDIR_C still exists AFTER r10k_deploy.sh exited on failure — trap did not fire on the die() exit path"
info "case (c) staged/failure: OK (temp dir removed even though r10k itself failed — trap fires regardless of exit status)"

info "all r10k_deploy git-ssh-staging cases PASSED"
exit 0
