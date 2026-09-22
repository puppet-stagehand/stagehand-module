# @summary Roll out the patchbot posture fact and keep its inputs fresh.
#
# This is the **pull path** for patch posture: classify a node with
# `include stagehand::patching` and, on its next Puppet run, the `patchbot`
# external fact reaches the console via PuppetDB — the Patching page, the
# Action Center, and (behind the Labs `computed_findings` flag) the
# correlation engine read it with no Bolt push.
# The console's own PQL queries (backend/internal/httpapi/patching.go,
# dashboard.go, hipogamo.go) already query the fact by its `patchbot` name —
# see docs/design/patchbot-fact-rollout.md.
#
# The fact scripts themselves ship in the module's `facts.d/` and are
# delivered to agents by pluginsync. This class only guarantees the inputs
# those facts count against stay reasonably fresh.
#
# **Linux** (`patchbot.sh`) reads the package manager's metadata cache, so
# this class manages a small refresh timer. The fact is cheap and always
# current-ish.
#
# **Windows** (`patchbot.ps1`) is split in two, because a Windows Update
# Agent search reaches WSUS or Windows Update and routinely takes minutes —
# doing that inside a fact would stall every Puppet run on the box. So:
#
#   * the fact reads the registry (four-part OS build, reboot-pending) live,
#     in microseconds, and merges a cache off disk;
#   * `patchbot_refresh.ps1` does the slow WUA scan on a scheduled task and
#     writes that cache.
#
# A cold cache is not a failure. `os_build` still resolves, and the build
# number is the entire input to Windows vulnerability correlation — comparing
# it against MSRC's `FixedBuild` sidesteps the cumulative-update supersedence
# problem that produces thousands of false positives in KB-set matching. See
# docs/design/patch-fact-schema.md.
#
# The active `stagehand::patch` Bolt task (console "Patch" button) is the push
# complement; it does not need this class.
#
# Dependency-light on purpose: native systemd unit files on Linux and
# `schtasks.exe` on Windows rather than puppet/systemd and
# puppetlabs/scheduled_task, so the whole pack pins only puppetlabs/stdlib.
#
# @param manage_cache
#   Linux: keep the package manager's update metadata fresh (a small systemd
#   timer) so the fact's counts are current. Default true.
# @param cache_refresh
#   Linux: systemd OnCalendar expression for the refresh timer. Default 'daily'.
# @param manage_windows_scan
#   Windows: manage the scheduled task that refreshes the WUA cache.
#   Default true.
# @param windows_scan_hour
#   Windows: hour (0-23) the daily WUA scan runs. The minute is derived
#   per-node from fqdn_rand so a large fleet does not hit WSUS in one burst —
#   the splay that patching_as_code omits and that turns a 4,000-node estate
#   into a thundering herd. Default 3.
#
# @example
#   include stagehand::patching
class stagehand::patching (
  Boolean           $manage_cache        = true,
  String[1]         $cache_refresh       = 'daily',
  Boolean           $manage_windows_scan = true,
  Integer[0, 23]    $windows_scan_hour   = 3,
) {
  case $facts['os']['family'] {
    'windows': {
      if $manage_windows_scan {
        $system32 = $facts.dig('os', 'windows', 'system32') ? {
          undef   => 'C:\Windows\System32',
          default => $facts['os']['windows']['system32'],
        }
        $patchbot_dir = 'C:\ProgramData\PuppetLabs\patchbot'
        $script_path  = "${patchbot_dir}\\patchbot_refresh.ps1"
        $task_name    = 'patchbot-refresh'
        $boot_task    = 'patchbot-refresh-boot'

        # Per-node minute: same hour across the fleet, spread across it.
        $scan_minute = fqdn_rand(60, 'patchbot-refresh')
        $scan_time   = sprintf('%02d:%02d', $windows_scan_hour, $scan_minute)

        file { $patchbot_dir:
          ensure => directory,
        }

        file { $script_path:
          ensure  => file,
          # The module-prefix here MUST match the real module name
          # (stagehand) or Puppet's fileserver can't resolve it (the same
          # autoload bug this class's own name previously had).
          source  => 'puppet:///modules/stagehand/patchbot_refresh.ps1',
          require => File[$patchbot_dir],
        }

        # No inner quoting around the script path: schtasks does not nest
        # quotes reliably, and this path is fixed and space-free by
        # construction. Quoting it anyway is how /TR silently produces a task
        # that never runs.
        $runner = "powershell.exe -NonInteractive -NoProfile -ExecutionPolicy Bypass -File ${script_path}"

        # schtasks rather than a scheduled_task resource: one fewer module in
        # the Puppetfile, and /F makes create idempotent enough that the
        # `unless` guard only exists to keep runs quiet.
        exec { 'patchbot-refresh-daily':
          command => "schtasks.exe /Create /TN \"${task_name}\" /TR \"${runner}\" /SC DAILY /ST ${scan_time} /RU SYSTEM /RL HIGHEST /F",
          unless  => "schtasks.exe /Query /TN \"${task_name}\"",
          path    => $system32,
          require => File[$script_path],
        }

        # Fresh posture after a reboot — the run most likely to have changed
        # it. Five-minute delay so it does not compete with boot.
        exec { 'patchbot-refresh-boot':
          command => "schtasks.exe /Create /TN \"${boot_task}\" /TR \"${runner}\" /SC ONSTART /DELAY 0005:00 /RU SYSTEM /RL HIGHEST /F",
          unless  => "schtasks.exe /Query /TN \"${boot_task}\"",
          path    => $system32,
          require => File[$script_path],
        }
      }
    }

    default: {
      # The fact is delivered by pluginsync from stagehand/facts.d/patchbot.sh;
      # nothing to manage here for the fact itself. Keep metadata fresh so the
      # counts are live.
      if $manage_cache {
        $refresh_cmd = $facts['os']['family'] ? {
          'Debian' => '/usr/bin/apt-get -qq update',
          'RedHat' => '/usr/bin/dnf -q makecache',
          default  => undef,
        }

        if $refresh_cmd =~ String[1] {
          $unit = 'patchbot-refresh'

          file { "/etc/systemd/system/${unit}.service":
            ensure  => file,
            owner   => 'root',
            group   => 'root',
            mode    => '0644',
            content => "[Unit]\nDescription=stagehand: refresh package metadata for the patchbot fact\n\n[Service]\nType=oneshot\nExecStart=${refresh_cmd}\n",
            notify  => Exec['patchbot-systemd-daemon-reload'],
          }

          file { "/etc/systemd/system/${unit}.timer":
            ensure  => file,
            owner   => 'root',
            group   => 'root',
            mode    => '0644',
            content => "[Unit]\nDescription=stagehand: schedule package-metadata refresh for patchbot\n\n[Timer]\nOnCalendar=${cache_refresh}\nRandomizedDelaySec=1h\nPersistent=true\n\n[Install]\nWantedBy=timers.target\n",
            notify  => Exec['patchbot-systemd-daemon-reload'],
          }

          exec { 'patchbot-systemd-daemon-reload':
            command     => '/usr/bin/systemctl daemon-reload',
            refreshonly => true,
          }

          service { "${unit}.timer":
            ensure  => running,
            enable  => true,
            require => [File["/etc/systemd/system/${unit}.timer"], Exec['patchbot-systemd-daemon-reload']],
          }
        }
      }
    }
  }
}
