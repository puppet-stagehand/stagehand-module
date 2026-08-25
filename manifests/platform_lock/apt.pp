# @summary Apply exact APT package versions, preferences, and native holds.
class stagehand::platform_lock::apt (
  Hash[String, String] $packages,
) {
  $names = $packages.keys.sort
  $preferences = $names.map |String $name| {
    "Package: ${name}\nPin: version ${packages[$name]}\nPin-Priority: 1001\n"
  }.join("\n")

  file { '/etc/apt/preferences.d/stagehand-platform-lock':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => $preferences,
  }

  $names.each |String $name| {
    package { "stagehand-platform-lock-${name}":
      ensure => $packages[$name],
      name   => $name,
    }
    exec { "stagehand-platform-lock-apt-${name}":
      command => "/usr/bin/apt-mark hold ${name}",
      unless  => "/usr/bin/apt-mark showhold | /bin/grep -Fqx -- ${name}",
      path    => ['/usr/bin', '/bin'],
      require => [Package["stagehand-platform-lock-${name}"], File['/etc/apt/preferences.d/stagehand-platform-lock']],
    }
  }
}
