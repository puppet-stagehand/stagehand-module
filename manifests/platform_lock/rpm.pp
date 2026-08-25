# @summary Apply exact RPM NEVRAs through the native DNF versionlock plugin.
class stagehand::platform_lock::rpm (
  Hash[String, String] $packages,
) {
  $names = $packages.keys.sort
  $locks = $names.map |String $name| { "${name}-${packages[$name]}" }.join("\n")

  package { 'stagehand-platform-lock-dnf-versionlock-plugin':
    ensure => installed,
    name   => 'python3-dnf-plugin-versionlock',
  }
  file { '/etc/dnf/plugins':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }
  file { '/etc/dnf/plugins/versionlock.list':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "${locks}\n",
    require => [Package['stagehand-platform-lock-dnf-versionlock-plugin'], File['/etc/dnf/plugins']],
  }

  $names.each |String $name| {
    package { "stagehand-platform-lock-${name}":
      ensure => $packages[$name],
      name   => $name,
      before => File['/etc/dnf/plugins/versionlock.list'],
    }
  }
}
