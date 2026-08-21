#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

# stagehand::class_enumerate — read-only report of a node's currently-applied
# Puppet classes, for the console's ENC discovery/import path. Reads the
# agent's local applied-classes state file (classes.txt) directly — this is
# NEVER a live catalog compile and NEVER a set-form Puppet Server call,
# matching discover.sh's read-only RAL-enumeration discipline for this
# module's other Bolt tasks.
#
# Ruby (not sh, unlike discover.sh) because this task must work identically
# on Linux AND Windows targets — Bolt's cross-platform task convention.
# Targets frequently have no system ruby on PATH, only the puppet-agent
# bundled interpreter, hence the shebang above (mirrors discover.sh's own
# "prefer the bundled interpreter" comment) — Bolt's ruby task runner
# invokes the script directly via this shebang, not via a separate `ruby`
# subprocess launch.
#
# No declared task parameters (input_method: environment, class_enumerate.json)
# — this task always reports the node's full currently-applied class list.
#
# Task protocol: stdout is a single JSON object,
#   {"classes": [<sorted, non-blank class names>]}
# or, when no applied-classes state file exists yet (a node that has never
# applied a catalog — a legitimate empty-class-set input, not a failure):
#   {"classes": [], "note": "no applied-classes state file found"}
# Always exits 0 — a missing/unreadable state file is not a task failure,
# matching discover.sh's "a per-node condition is not a task failure"
# convention.

require 'json'
require 'rbconfig'
require 'English'

# STAGEHAND_CLASS_ENUMERATE_PUPPET_BIN / STAGEHAND_CLASS_ENUMERATE_STATEDIR_OVERRIDE
# override the puppet binary path / statedir directly for local/dev testing,
# mirroring discover.sh's STAGEHAND_DISCOVER_PUPPET_BIN convention. Never a
# Bolt PT_ param -- these are test-only escape hatches, never set by a real
# Bolt dispatch.
PUPPET_BIN = ENV['STAGEHAND_CLASS_ENUMERATE_PUPPET_BIN'] || '/opt/puppetlabs/bin/puppet'
STATEDIR_OVERRIDE = ENV['STAGEHAND_CLASS_ENUMERATE_STATEDIR_OVERRIDE']

def windows?
  RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
end

def default_statedir
  windows? ? 'C:\\ProgramData\\PuppetLabs\\puppet\\cache\\state' : '/opt/puppetlabs/puppet/cache/state'
end

# resolve_statedir shells out to `puppet config print statedir` so a target
# whose statedir has been customized away from the OS default is still read
# correctly. Falls back to the OS-appropriate default (never errors) if the
# puppet binary is missing or the subprocess fails for any reason — a
# best-effort resolution, not a hard requirement for this task to run.
def resolve_statedir
  return STATEDIR_OVERRIDE if STATEDIR_OVERRIDE && !STATEDIR_OVERRIDE.empty?
  return default_statedir unless File.executable?(PUPPET_BIN)

  out = `#{PUPPET_BIN.inspect} config print statedir 2>&1`
  return default_statedir unless $CHILD_STATUS && $CHILD_STATUS.success?

  resolved = out.to_s.strip
  resolved.empty? ? default_statedir : resolved
rescue StandardError
  default_statedir
end

statedir = resolve_statedir
classes_path = File.join(statedir, 'classes.txt')

result =
  if File.readable?(classes_path)
    classes = File.readlines(classes_path).map(&:strip).reject(&:empty?).sort.uniq
    { classes: classes }
  else
    { classes: [], note: 'no applied-classes state file found' }
  end

puts JSON.generate(result)
exit 0
