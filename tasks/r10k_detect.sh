#!/bin/sh
# stagehand::r10k_detect — read-only discovery of an existing r10k/Puppetfile
# configuration on the primary (D-17, the control-repo setup wizard's
# auto-detecting first step, D-02). Reads r10k.yaml (if present) and, when a
# control-repo checkout already exists at its configured basedir, that
# checkout's Puppetfile content — verbatim, unparsed. Puppetfile parsing
# already happens console-side via gitops.ParsePuppetfile (RESEARCH.md's
# "Don't Hand-Roll" table: no second parser lives here).
#
# Contract (Task 1's <action>): this task NEVER executes r10k, NEVER writes
# anything, NEVER mutates state — the console's D-2 new-setup-vs-import-
# existing signal depends on this being strictly side-effect-free, matching
# discover.sh's own read-only contract (T-47-08).
#
# This script's stdout is a single JSON object, always emitted with exit 0:
#   - no r10k.yaml found anywhere probed:  {"r10k_yaml_found": false}
#     (the new-setup signal, D-2 — an expected, non-exceptional outcome,
#     never a task failure)
#   - r10k.yaml found and fully parses:
#     {"r10k_yaml_found": true, "r10k_yaml_path": ..., "sources": [...],
#      "puppetfile_raw": string|null, "parse_warnings": [],
#      "deploy_key_found": bool, "deploy_key_path": string|null}
#   - r10k.yaml found but some/all of it fails to parse: the same shape
#     PLUS "parsed" (whatever DID parse) and "raw" (the full verbatim file
#     content) — D-18, never a silent drop, never a bare failure.
#
# r10k.yaml's real location is not a documented single fixed path anywhere
# in this codebase (confirmed by RESEARCH.md/this task's <read_first> —
# no existing r10k.yaml path reference exists to reuse) — probe both of
# r10k's own conventional locations and report whichever exists, never
# assume one silently.
#
# deploy_key_found/deploy_key_path (D-19's console-side signal, Plan 47-07
# Task 3): this task ONLY checks whether a file EXISTS at one of the same
# conventional deploy-key locations the dedicated key-read task (Plan
# 47-07 Task 1, a genuinely separate task, T-47-16 -- see that task's own
# script for its name) defaults to when it isn't given an explicit
# key_path -- it NEVER opens/reads that file's content. Reading private
# key bytes is exclusively that other task's job; this detection task
# stays read-only-of-config, never secret-reading.
set -u

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Ruby interpreter for the structured r10k.yaml parse below, matching
# discover.sh's established convention (targets frequently have NO system
# ruby on PATH — only the puppet-agent bundled one — so prefer the bundled
# interpreter and fall back to PATH ruby for dev machines / the test
# harness). PCM_R10K_DETECT_RUBY_BIN is a test-only override, mirroring
# discover.sh's PCM_RUBY_BIN convention.
RUBY="${PCM_R10K_DETECT_RUBY_BIN:-}"
if [ -z "$RUBY" ]; then
  if [ -x /opt/puppetlabs/puppet/bin/ruby ]; then
    RUBY=/opt/puppetlabs/puppet/bin/ruby
  else
    RUBY=ruby
  fi
fi

# PCM_R10K_DETECT_YAML_PATH is a test-only override letting
# r10k_detect_test.sh point this script at a fixture file instead of a real
# /etc path — never a Bolt PT_ param.
R10K_YAML_PATH=""
for cand in "${PCM_R10K_DETECT_YAML_PATH:-}" /etc/puppetlabs/r10k/r10k.yaml "$HOME/.r10k.yaml"; do
  [ -n "$cand" ] || continue
  if [ -f "$cand" ]; then
    R10K_YAML_PATH="$cand"
    break
  fi
done

if [ -z "$R10K_YAML_PATH" ]; then
  printf '{"r10k_yaml_found": false}\n'
  exit 0
fi

# Existence-only probe (never opens the file) for an already-in-use deploy
# key at one of the dedicated key-read task's own default candidate
# locations -- kept in exact sync with that script's candidate list so a
# path this task surfaces is always resolvable by that other task
# unmodified. PCM_R10K_DETECT_DEPLOY_KEY_PATH is a test-only override,
# mirroring PCM_R10K_DETECT_YAML_PATH.
DEPLOY_KEY_PATH=""
for cand in "${PCM_R10K_DETECT_DEPLOY_KEY_PATH:-}" /etc/puppetlabs/r10k/ssh/id_rsa /etc/puppetlabs/r10k/ssh/id_ed25519 "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa"; do
  [ -n "$cand" ] || continue
  if [ -f "$cand" ]; then
    DEPLOY_KEY_PATH="$cand"
    break
  fi
done

"$RUBY" -ryaml -rjson -e '
path = ARGV[0]
deploy_key_path = ARGV[1]
deploy_key_path = nil if deploy_key_path.nil? || deploy_key_path.empty?

raw = begin
  File.read(path)
rescue StandardError => e
  # A file we just confirmed exists (test -f) that cannot be read (perms,
  # race) is genuinely exceptional -- surface it the same shape as any
  # other parse failure rather than crashing the task.
  ""
end

lines = raw.split("\n", -1)
parsed_doc = nil
parse_error = nil
begin
  parsed_doc = YAML.safe_load(raw, permitted_classes: [Symbol], aliases: true)
rescue StandardError => e
  parse_error = e.message
  # D-18: never silently drop what DID parse. YAML documents are not
  # line-recoverable in general, but a common real-world shape (valid
  # config followed by trailing garbage/a syntax slip) IS recoverable by
  # chopping trailing lines until the remaining prefix parses -- try that
  # before giving up and reporting nothing parsed.
  n = lines.length
  while n > 0
    candidate = lines[0...n].join("\n")
    begin
      parsed_doc = YAML.safe_load(candidate, permitted_classes: [Symbol], aliases: true)
      break
    rescue StandardError
      parsed_doc = nil
    end
    n -= 1
  end
end

sources = []
warnings = []
if parsed_doc.is_a?(Hash) && parsed_doc["sources"].is_a?(Hash)
  parsed_doc["sources"].each do |name, cfg|
    if cfg.is_a?(Hash) && cfg["remote"]
      sources << {"name" => name.to_s, "remote" => cfg["remote"], "basedir" => cfg["basedir"]}
    else
      warnings << "source '"'"'#{name}'"'"' is malformed or missing '"'"'remote'"'"'"
    end
  end
elsif !parsed_doc.nil?
  warnings << "no top-level '"'"'sources'"'"' hash found"
end
warnings << "r10k.yaml parse warning: #{parse_error}" if parse_error

# If a control-repo checkout already exists at the first source'"'"'s basedir,
# read its Puppetfile content VERBATIM -- never parsed here (that already
# happens console-side via gitops.ParsePuppetfile). Prefer the conventional
# "production" environment directory; otherwise fall back to whichever
# environment directory sorts first and actually has a Puppetfile.
puppetfile_raw = nil
if !sources.empty?
  basedir = sources.first["basedir"]
  if basedir && File.directory?(basedir)
    candidates = []
    prod = File.join(basedir, "production", "Puppetfile")
    candidates << prod if File.file?(prod)
    if candidates.empty?
      Dir.glob(File.join(basedir, "*", "Puppetfile")).sort.each { |c| candidates << c }
    end
    if (first = candidates.first)
      begin
        puppetfile_raw = File.read(first)
      rescue StandardError
        puppetfile_raw = nil
      end
    end
  end
end

result = {
  "r10k_yaml_found" => true,
  "r10k_yaml_path" => path,
  "sources" => sources,
  "puppetfile_raw" => puppetfile_raw,
  "parse_warnings" => warnings,
  "deploy_key_found" => !deploy_key_path.nil?,
  "deploy_key_path" => deploy_key_path,
}
if parse_error
  result["parsed"] = parsed_doc || {}
  result["raw"] = raw
end
puts JSON.generate(result)
' "$R10K_YAML_PATH" "$DEPLOY_KEY_PATH"

exit 0
