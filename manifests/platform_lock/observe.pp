# @summary Publish desired state and derive a verified observation on the target.
class stagehand::platform_lock::observe (
  Hash  $desired,
  Array $after = [],
) {
  $root = '/var/lib/stagehand/platform-lock'
  $helper = '/usr/local/sbin/stagehand-platform-lock-observe'
  $desired_json = inline_template('<%= require "json"; JSON.generate(@desired) %>')
  $desired_json_b64 = inline_template('<%= require "base64"; Base64.strict_encode64(@desired_json) %>')
  $role_names = $desired['desired']['roles'].map |Hash $role| { $role['role'] }
  $postgresql_majors = unique($desired['desired']['roles'].map |Hash $role| { $role['runtime']['postgresql_major'] }.filter |$major| { $major != undef })
  $postgresql_service = $postgresql_majors.empty ? {
    true    => undef,
    default => $desired['desired']['os']['family'] ? {
      'debian' => "postgresql@${postgresql_majors[0]}-main",
      'redhat' => "postgresql-${postgresql_majors[0]}",
      default  => 'postgresql',
    },
  }
  $health_services = [
    'puppet_server' in $role_names ? { true => 'puppetserver', false => undef },
    'puppetdb' in $role_names ? { true => 'puppetdb', false => undef },
    ('postgresql' in $role_names or 'puppetdb' in $role_names) ? { true => $postgresql_service, false => undef },
  ].filter |$service| { $service != undef }

  file { '/var/lib/stagehand':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0700',
  }
  file { $root:
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    require => File['/var/lib/stagehand'],
  }
  file { $helper:
    ensure    => file,
    owner     => 'root',
    group     => 'root',
    mode      => '0700',
    content   => epp('stagehand/platform_lock/observe.rb.epp', { 'desired_json_b64' => $desired_json_b64 }),
    show_diff => false,
  }
  $health_services.each |String $service| {
    # These health probes intentionally run on every Puppet application.
    # lint:ignore:exec_idempotency
    exec { "stagehand-platform-lock-health-${service}":
      command   => "/bin/systemctl is-active --quiet ${service}",
      path      => ['/usr/bin', '/bin'],
      logoutput => false,
      timeout   => 30,
      require   => $after,
    }
    # lint:endignore
  }
  $health_after = $health_services.map |String $service| { Exec["stagehand-platform-lock-health-${service}"] }
  # Observation intentionally refreshes evidence on every Puppet application.
  # lint:ignore:exec_idempotency
  exec { 'stagehand-platform-lock-observe':
    command   => $helper,
    path      => ['/opt/puppetlabs/puppet/bin', '/usr/bin', '/bin'],
    logoutput => false,
    timeout   => 120,
    require   => [File[$root], File[$helper]] + $after + $health_after,
  }
  # lint:endignore
}
