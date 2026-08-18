# @summary Idempotently set one puppet.conf value in the [server] section.
#
# A dependency-light alternative to puppetlabs/inifile: guards a
# `puppet config set` with a matching `puppet config print`, so it converges
# and reports no change once the value is in place. Private to
# stagehand::console_integration.
#
# @param value       The setting value to enforce.
# @param bin         Path to the puppet binary. Default '/opt/puppetlabs/bin/puppet'.
# @param svc_notify  Optional resource reference to refresh on change.
define stagehand::console_integration::puppet_conf (
  String[1]           $value,
  Stdlib::Absolutepath $bin       = '/opt/puppetlabs/bin/puppet',
  Optional[Type[Resource]] $svc_notify = undef,
) {
  $setting = $name
  $esc     = shell_escape($value)

  exec { "stagehand-puppet-conf-${setting}":
    command => "${bin} config set ${setting} ${esc} --section server",
    unless  => "${bin} config print ${setting} --section server | grep -qxF ${esc}",
    path    => ['/opt/puppetlabs/bin', '/usr/bin', '/bin', '/usr/sbin', '/sbin'],
    notify  => $svc_notify,
  }
}
