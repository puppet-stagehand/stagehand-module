#!/bin/sh
# Read-only-contract + D-18 proof test for r10k_detect.sh (D-17).
#
# POSIX sh, no bats dependency -- follows discover_test.sh's structure:
# mktemp sandbox, PCM_R10K_DETECT_YAML_PATH env override (mirroring
# discover.sh's PCM_DISCOVER_PUPPET_BIN convention) pointing the script at
# fixture files instead of real /etc paths, exit-code/content assertions.
#
# Cases (see 47-03-PLAN.md Task 1 <acceptance_criteria>):
#   (a) absent      -> no r10k.yaml at any probed location: stdout is exactly
#                       {"r10k_yaml_found": false}, exit 0 (the expected
#                       new-setup case, D-2 -- never an error).
#   (b) well-formed  -> a real r10k.yaml with a sources hash + a Puppetfile
#                       present at the configured basedir/production path:
#                       stdout carries the sources list and the Puppetfile's
#                       raw content verbatim.
#   (c) malformed    -> a well-formed sources: block followed by a genuine
#                       YAML syntax error: exit 0, with BOTH a "parsed"
#                       (whatever DID parse -- here, the whole sources
#                       block) and "raw" (full verbatim file content) field
#                       present -- D-18, never a silent drop, never a bare
#                       failure.
#   (d) deploy key found -> a file exists at one of the conventional deploy
#                       key locations: deploy_key_found=true, deploy_key_path
#                       set, and -- proving this task stays existence-only,
#                       never secret-reading (D-19/T-47-20's Spoofing
#                       mitigation boundary) -- the fixture key's own content
#                       marker never appears anywhere in stdout.
#
# HOME is pinned to the sandbox ($WORK) on every invocation below so this
# test is hermetic: r10k_detect.sh's own default candidate probes include
# "$HOME/.r10k.yaml" and (as of the deploy-key-path probe this task's
# extension adds) "$HOME/.ssh/id_ed25519"/"$HOME/.ssh/id_rsa" -- real
# developer/CI machines commonly HAVE ssh keys at those paths, so leaving
# HOME unpinned would make cases (a)-(c) genuinely flaky depending on the
# machine running this test, not just theoretically so.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd) || exit 1
DETECT_SH="$SCRIPT_DIR/r10k_detect.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
info() { printf '>>> %s\n' "$*"; }

[ -f "$DETECT_SH" ] || fail "r10k_detect.sh not found at $DETECT_SH"

WORK=$(mktemp -d) || fail "mktemp -d failed"
trap 'rm -rf "$WORK"' EXIT

BASEDIR="$WORK/environments"
mkdir -p "$BASEDIR/production" || fail "could not create fixture basedir"

PUPPETFILE_CONTENT='mod "puppetlabs/stdlib", "9.0.0"
mod "corp/finance", git: "git@github.com:acme/finance.git"
'
printf '%s' "$PUPPETFILE_CONTENT" >"$BASEDIR/production/Puppetfile"

# --- Case (a): absent. No PCM_R10K_DETECT_YAML_PATH override and none of
# the script's own hardcoded probe paths exist in this sandbox, so it must
# fall through to the new-setup signal. ---
OUT=$(HOME="$WORK" sh "$DETECT_SH") || fail "case (a) absent: r10k_detect.sh exited non-zero. Output:
$OUT"
[ "$OUT" = '{"r10k_yaml_found": false}' ] || fail "case (a) absent: expected the exact new-setup signal, got:
$OUT"
info "case (a) absent: OK (r10k_yaml_found=false, exit 0)"

# --- Case (b): well-formed r10k.yaml + present Puppetfile. ---
cat >"$WORK/r10k.yaml" <<EOF
---
cachedir: '/var/cache/r10k'
sources:
  corp:
    remote: 'git@github.com:acme/corp-control-repo.git'
    basedir: '$BASEDIR'
EOF

OUT=$(HOME="$WORK" PCM_R10K_DETECT_YAML_PATH="$WORK/r10k.yaml" sh "$DETECT_SH") ||
  fail "case (b) well-formed: r10k_detect.sh exited non-zero. Output:
$OUT"
case "$OUT" in
  *'"r10k_yaml_found":true'*) : ;;
  *) fail "case (b) well-formed: expected r10k_yaml_found=true, got:
$OUT" ;;
esac
case "$OUT" in
  *'"remote":"git@github.com:acme/corp-control-repo.git"'*) : ;;
  *) fail "case (b) well-formed: expected the source's remote in the sources list, got:
$OUT" ;;
esac
case "$OUT" in
  *'"basedir":"'"$BASEDIR"'"'*) : ;;
  *) fail "case (b) well-formed: expected the source's basedir in the sources list, got:
$OUT" ;;
esac
case "$OUT" in
  *'mod \"puppetlabs/stdlib\", \"9.0.0\"'*) : ;;
  *) fail "case (b) well-formed: expected the Puppetfile's raw content verbatim in puppetfile_raw, got:
$OUT" ;;
esac
case "$OUT" in
  *'"parsed"'*|*'"raw"'*) fail "case (b) well-formed: a fully-parseable r10k.yaml must not carry parsed/raw fallback fields, got:
$OUT" ;;
esac
case "$OUT" in
  *'"deploy_key_found":false'*'"deploy_key_path":null'*) : ;;
  *) fail "case (b) well-formed: with HOME pinned to an empty sandbox and no matching key file, expected deploy_key_found=false/deploy_key_path=null, got:
$OUT" ;;
esac
info "case (b) well-formed: OK (sources + puppetfile_raw present, no fallback fields, deploy_key_found=false)"

# --- Case (c): malformed -- a well-formed sources: block followed by a
# genuine YAML syntax error later in the file. The whole-document parse
# fails, but the trailing-line-chop recovery in r10k_detect.sh must still
# surface the sources block that DID parse, alongside the full raw text. ---
cat >"$WORK/r10k_malformed.yaml" <<EOF
---
cachedir: '/var/cache/r10k'
sources:
  corp:
    remote: 'git@github.com:acme/corp-control-repo.git'
    basedir: '$BASEDIR'
this is: not [valid yaml at all: {{{
EOF

OUT=$(HOME="$WORK" PCM_R10K_DETECT_YAML_PATH="$WORK/r10k_malformed.yaml" sh "$DETECT_SH") ||
  fail "case (c) malformed: r10k_detect.sh exited non-zero (expected 0 even on a parse failure). Output:
$OUT"
case "$OUT" in
  *'"r10k_yaml_found":true'*) : ;;
  *) fail "case (c) malformed: expected r10k_yaml_found=true even though parsing partially failed, got:
$OUT" ;;
esac
case "$OUT" in
  *'"parsed":'*) : ;;
  *) fail "case (c) malformed: expected a \"parsed\" field carrying whatever DID parse (D-18), got:
$OUT" ;;
esac
case "$OUT" in
  *'"raw":'*'this is: not [valid yaml at all: {{{'*) : ;;
  *) fail "case (c) malformed: expected a \"raw\" field carrying the full verbatim file content including the unparseable line (D-18 -- never silently drop it), got:
$OUT" ;;
esac
case "$OUT" in
  *'"remote":"git@github.com:acme/corp-control-repo.git"'*) : ;;
  *) fail "case (c) malformed: expected the sources block that DID parse to still surface in \"sources\", got:
$OUT" ;;
esac
info "case (c) malformed: OK (exit 0, both parsed and raw present, never a bare failure)"

# --- Case (d): deploy key found -- a file exists at the
# PCM_R10K_DETECT_DEPLOY_KEY_PATH override. Proves this task reports the
# path WITHOUT ever opening/reading it (T-47-20's boundary: detection may
# reference a key's PATH, never its contents -- that is exclusively
# stagehand::r10k_read_deploy_key's job, a genuinely separate task). ---
KEY_MARKER="FIXTURE-PRIVATE-KEY-CONTENT-MARKER-9f2c"
cat >"$WORK/fixture_id_ed25519" <<EOF
-----BEGIN OPENSSH PRIVATE KEY-----
$KEY_MARKER
-----END OPENSSH PRIVATE KEY-----
EOF

OUT=$(HOME="$WORK" PCM_R10K_DETECT_YAML_PATH="$WORK/r10k.yaml" \
  PCM_R10K_DETECT_DEPLOY_KEY_PATH="$WORK/fixture_id_ed25519" sh "$DETECT_SH") ||
  fail "case (d) deploy key found: r10k_detect.sh exited non-zero. Output:
$OUT"
case "$OUT" in
  *'"deploy_key_found":true'*) : ;;
  *) fail "case (d) deploy key found: expected deploy_key_found=true, got:
$OUT" ;;
esac
case "$OUT" in
  *'"deploy_key_path":"'"$WORK"'/fixture_id_ed25519"'*) : ;;
  *) fail "case (d) deploy key found: expected deploy_key_path to carry the resolved path, got:
$OUT" ;;
esac
case "$OUT" in
  *"$KEY_MARKER"*) fail "case (d) deploy key found: the fixture key's own content marker leaked into stdout -- this task must be existence-only, NEVER read the key's content. Got:
$OUT" ;;
  *) : ;;
esac
info "case (d) deploy key found: OK (deploy_key_found=true, path surfaced, content never read)"

info "all r10k_detect safety cases PASSED"
exit 0
