# @summary Install Windows Puppet packages at exact display versions from immutable MSIs.
class stagehand::platform_lock::windows (
  Hash[String, String] $packages,
  Hash[String, Hash]   $sources,
) {
  $packages.keys.sort.each |String $name| {
    package { "stagehand-platform-lock-${name}":
      ensure => $packages[$name],
      name   => $name,
      source => $sources[$name]['source'],
    }
  }
}
