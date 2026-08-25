# @summary Apply exact SUSE package versions and solver-visible zypper locks.
class stagehand::platform_lock::zypper (
  Hash[String, String] $packages,
) {
  $packages.keys.sort.each |String $name| {
    package { "stagehand-platform-lock-${name}":
      ensure => $packages[$name],
      name   => $name,
    }
    exec { "stagehand-platform-lock-zypper-${name}":
      command => "/usr/bin/zypper --non-interactive addlock --type package ${name}",
      unless  => "/usr/bin/zypper --xmlout locks | /bin/grep -Fq -- '<solvable name=\"${name}\"'",
      path    => ['/usr/bin', '/bin'],
      require => Package["stagehand-platform-lock-${name}"],
    }
  }
}
