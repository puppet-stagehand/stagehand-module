# @summary Install and run the Puppet Stagehand Console service itself.
#
# The permanent, idempotent replacement for the ~200-line hand-rolled Bolt
# plan that used to stage/start the console binary from a separate Go-based
# installer repo. Apply this on the **console host** (may be the same box as
# the puppetserver primary, or a dedicated node — `$puppetserver_fqdn`
# defaults to the applying node's own fqdn, matching the installer's
# co-located single-box default).
#
# Covers the binary, service user, systemd unit, env file, Postgres
# role/database, TLS cert issuance, and bolt-project scaffold for the
# `present`/`latest` path, plus the `absent` removal path (binary/unit/config
# dir cleanup, with an opt-in `$purge_data` Postgres role/database drop).
#
# @param ensure
#   'present'/'latest' install and run the service; 'absent' stops and
#   disables it, and removes the binary/unit/config dir (Postgres role/db
#   are left in place unless `$purge_data` is also set).
# @param purge_data
#   When `$ensure == 'absent'`, also drops the console's Postgres role and
#   database. Has no effect otherwise.
# @param version
#   Console version the installer has staged at `$console_binary_source`.
#   Puppet's `file` type re-compares the source checksum on every run
#   regardless of `$ensure`, so both 'present' and 'latest' already pick up
#   a newer binary as soon as the installer restages one; `$version` is
#   carried through as installer-facing metadata for that restaging step.
# @param console_binary_source
#   Local file resource path the installer stages the console binary at
#   (matches today's `upload_file($console_binary, ...)` step) — passed
#   straight through to `file { ... source => ... }`.
# @param db_password
#   Password for the console's Postgres role. Drives both Postgres role
#   creation/password-sync (`Exec['stagehand::console::pg_role']` and
#   `Exec['stagehand::console::pg_role_password_sync']` below) and is threaded
#   into `PSH_DATABASE_URL` in the env file.
# @param ingest_token
#   Bearer token the console accepts on its ingest API (`PSH_INGEST_TOKEN`).
# @param dataservice_token
#   Bearer token the console accepts on its Hiera Data Service API
#   (`PSH_DATASERVICE_TOKEN`).
# @param console_port
#   Port the console binary listens on. Feeds `PSH_ADDR` and
#   `PSH_EXTERNAL_URL`.
# @param puppetserver_fqdn
#   FQDN of the puppetserver primary this console instance seeds data from.
#   Defaults to the applying node's own fqdn (co-located install).
#
# @example Co-located console + puppetserver primary
#   class { 'stagehand::console':
#     console_binary_source => '/opt/staging/puppet-console',
#     db_password           => Sensitive($facts['psh_db_password']),
#     ingest_token          => Sensitive($facts['psh_ingest_token']),
#     dataservice_token     => Sensitive($facts['psh_dataservice_token']),
#   }
class stagehand::console (
  Enum['present', 'latest', 'absent'] $ensure                = 'present',
  Boolean                             $purge_data             = false,
  String[1]                           $version                = 'latest',
  String[1]                           $console_binary_source,
  Sensitive[String[1]]                $db_password,
  Sensitive[String[1]]                $ingest_token,
  Sensitive[String[1]]                $dataservice_token,
  Integer[1, 65535]                   $console_port           = 8443,
  String[1]                           $puppetserver_fqdn      = $facts['networking']['fqdn'],
) {
  $binary_path       = '/usr/local/bin/puppet-console'
  $service_user       = 'psh'
  $service_group      = 'psh'
  $service_home       = '/var/lib/puppet-console'
  $config_dir         = '/etc/puppet-console'
  $env_file           = "${config_dir}/console.env"
  $unit_file          = '/etc/systemd/system/puppet-console.service'

  # Seed connections: single-box default. The console reaches its own
  # Postgres and the co-located puppetserver/puppetdb on localhost/self.
  $db_host            = '127.0.0.1'
  $db_port            = 5432
  $db_name            = 'psh'
  $db_user            = 'psh'
  $database_url       = "postgres://${db_user}:${db_password.unwrap}@${db_host}:${db_port}/${db_name}?sslmode=disable"

  $puppetserver_port  = 8140
  $puppetdb_host      = $puppetserver_fqdn
  $puppetdb_port      = 8081

  $seed_cert          = '/etc/puppet-console/certs/console.crt.pem'
  $seed_key           = '/etc/puppet-console/certs/console.key.pem'
  $seed_cacert        = '/etc/puppet-console/certs/ca.pem'
  $certs_dir          = "${config_dir}/certs"

  $bolt_path          = '/opt/puppetlabs/bin/bolt'
  $bolt_project       = "${config_dir}/bolt-project"

  $external_url       = "http://${puppetserver_fqdn}:${console_port}"

  # Shared exec path for both the Postgres role/db/pg_hba execs (present
  # branch) and the purge_data drop-role/drop-db execs (absent branch), plus
  # the TLS cert generation exec — declared here (rather than nested inside
  # `if $ensure != 'absent'`) so it's in scope for both branches.
  $pg_exec_path = ['/usr/bin', '/bin', '/usr/sbin', '/sbin']

  # `latest` and `present` manage identical resources here — the file
  # source's checksum comparison already re-validates content every run.
  $service_ensure = $ensure ? {
    'absent' => 'stopped',
    default  => 'running',
  }
  $service_enable = $ensure ? {
    'absent' => false,
    default  => true,
  }
  # The Postgres role/db/pg_hba execs below are only declared when
  # $ensure != 'absent'; on that path the service has nothing to require.
  $console_service_requires = $ensure ? {
    'absent' => undef,
    default  => [
      Exec['stagehand::console::pg_role_password_sync'],
      Exec['stagehand::console::pg_db'],
      Exec['stagehand::console::pg_hba'],
    ],
  }

  if $ensure != 'absent' {
    user { $service_user:
      ensure => present,
      system => true,
      home   => $service_home,
      shell  => '/bin/false',
    }

    file { $service_home:
      ensure  => directory,
      owner   => $service_user,
      group   => $service_group,
      mode    => '0750',
      require => User[$service_user],
    }

    file { $binary_path:
      ensure => file,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
      source => $console_binary_source,
      notify => Service['puppet-console'],
    }

    file { $config_dir:
      ensure  => directory,
      owner   => 'root',
      group   => $service_group,
      mode    => '0750',
      require => User[$service_user],
    }

    # Postgres role/db/pg_hba provisioning — ported verbatim (guarded
    # exec+unless, matching idempotency checks) from the original Go
    # installer's bolt.go:475-499. No puppetlabs/postgresql module
    # dependency is introduced; Postgres server installation itself is
    # out of scope here (assumed already present on this host).
    exec { 'stagehand::console::pg_role':
      command => Sensitive("psql -c \"CREATE ROLE ${db_user} LOGIN PASSWORD '${db_password.unwrap}'\""),
      unless  => "psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname='${db_user}'\" | grep -q 1",
      user    => 'postgres',
      path    => $pg_exec_path,
    }

    # Idempotency guard for the password sync below: Postgres doesn't expose
    # a way to compare a plaintext password against the role's stored
    # (hashed) password, so a marker file holding a SHA-256 of the last
    # password we synced stands in for that comparison. The marker lives in
    # a directory owned/readable only by the `postgres` user (0700) so a
    # hash derived from a secret isn't left world-readable, even though a
    # one-way hash is low sensitivity.
    #
    # Deliberately NOT nested under $config_dir ("${config_dir}/pg-state"):
    # $config_dir (/etc/puppet-console) is `root:psh 0750`, and the `unless`
    # guard/hash_record execs below run `user => 'postgres'`. `postgres` is
    # neither `root` nor a member of `psh`, so it falls under "other" on
    # $config_dir, which is `0750` -> other = `---` (no traverse). Any
    # `test -f`/`cat`/`>` under $config_dir as `postgres` would fail with
    # permission-denied on the directory traversal itself, well before
    # reaching the marker file -- silently defeating the `unless` guard (so
    # the sync exec would run every apply) and hard-failing the refreshonly
    # hash_record exec outright.
    #
    # Instead this is a sibling directory directly under `/etc`, which is
    # `root:root 0755` (world traverse+read, per standard OS defaults) --
    # so `postgres` can reach it -- with the directory itself owned
    # `postgres:postgres 0700`, so `postgres` (as owner) has full
    # read/write/traverse on it and no other non-root user does. Full chain
    # for `postgres`: `/` (root, world x) -> `/etc` (root:root 0755, world
    # rx) -> `/etc/puppet-console-pg-state` (postgres:postgres 0700, owner
    # rwx) -> `db_password.sha256` (owner-writable). Do not relocate this
    # back under $config_dir, and do not change $config_dir's own
    # mode/group to accommodate it -- other files there are intentionally
    # `root:psh` for the `psh` service user, not `postgres`.
    $pg_state_dir           = '/etc/puppet-console-pg-state'
    $db_password_hash       = sha256($db_password.unwrap)
    $db_password_hash_file  = "${pg_state_dir}/db_password.sha256"

    file { $pg_state_dir:
      ensure => directory,
      owner  => 'postgres',
      group  => 'postgres',
      mode   => '0700',
    }

    exec { 'stagehand::console::pg_role_password_sync':
      command => Sensitive("psql -c \"ALTER ROLE ${db_user} WITH PASSWORD '${db_password.unwrap}'\""),
      unless  => "test -f ${db_password_hash_file} && [ \"\$(cat ${db_password_hash_file})\" = '${db_password_hash}' ]",
      user    => 'postgres',
      path    => $pg_exec_path,
      require => [Exec['stagehand::console::pg_role'], File[$pg_state_dir]],
    }

    # Records the just-synced password's hash so the `unless` guard above
    # is a no-op on the next run unless $db_password actually changes.
    # refreshonly + subscribe means this only runs right after the sync
    # exec above actually ran (i.e. only when the password changed).
    exec { 'stagehand::console::pg_role_password_hash_record':
      command     => "/bin/sh -c 'umask 077; echo ${db_password_hash} > ${db_password_hash_file}'",
      user        => 'postgres',
      path        => $pg_exec_path,
      refreshonly => true,
      subscribe   => Exec['stagehand::console::pg_role_password_sync'],
    }

    exec { 'stagehand::console::pg_db':
      command => "createdb -O ${db_user} ${db_name}",
      unless  => "psql -tAc \"SELECT 1 FROM pg_database WHERE datname='${db_name}'\" | grep -q 1",
      user    => 'postgres',
      path    => $pg_exec_path,
      require => Exec['stagehand::console::pg_role'],
    }

    # pg_hba.conf lives at a distro-dependent path (Debian:
    # /etc/postgresql/<ver>/main/, RHEL: /var/lib/pgsql/<ver>/data/), so
    # discover it the same way the original installer's shell script did
    # rather than hardcoding a path. Query `SHOW hba_file` (not `SHOW
    # data_directory`) — that's the query that directly asks Postgres where
    # pg_hba.conf actually lives; on RHEL/CentOS it happens to be colocated
    # with data_directory, but on Debian/Ubuntu (a declared supported OS)
    # it is not, so deriving the path from data_directory silently writes
    # to the wrong file there. `hba_file` already returns the full file
    # path, not a directory, so it's used directly (no `/pg_hba.conf`
    # suffix). This has to stay a single guarded exec instead of stdlib's
    # file_line: file_line needs a static Puppet-side path, and there is no
    # clean way to feed it a shell-discovered path without more machinery
    # (a custom fact or a generate() call) than this task warrants.
    # Shared "find pg_hba.conf via psql" snippet, reused by both the append
    # command and its idempotency guard below.
    $pg_hba_file_cmd = "su - postgres -c \"psql -tAc 'SHOW hba_file'\" | tr -d '[:space:]'"

    exec { 'stagehand::console::pg_hba':
      command => "PG_HBA_FILE=\$(${pg_hba_file_cmd}) && cat >> \${PG_HBA_FILE} <<'RULES'\n# puppet-console: console local TCP auth\nhost    ${db_name}    ${db_user}    127.0.0.1/32    scram-sha-256\nhost    ${db_name}    ${db_user}    ::1/128         scram-sha-256\nRULES\n",
      unless  => "grep -q 'puppet-console' \$(${pg_hba_file_cmd})",
      path    => $pg_exec_path,
      require => Exec['stagehand::console::pg_db'],
      notify  => Exec['stagehand::console::pg_hba_reload'],
    }

    exec { 'stagehand::console::pg_hba_reload':
      command     => 'systemctl reload postgresql',
      path        => $pg_exec_path,
      refreshonly => true,
    }

    # TLS cert issuance — ported verbatim (creates-guarded exec, matching
    # the original `test -f ... || { ... }` idempotency guard) from the
    # original Go installer's bolt.go:500-508. Generates a console cert off
    # the puppetserver CA, then copies cert/key/CA into the seed paths the
    # console reads at startup (referenced in console.env.epp above).
    exec { 'stagehand::console::ca_cert':
      command => "/bin/sh -c 'systemctl stop puppetserver && /opt/puppetlabs/bin/puppetserver ca generate --certname console.${puppetserver_fqdn} --ca-client; rc=\$?; systemctl start puppetserver; exit \$rc'",
      creates => "/etc/puppetlabs/puppet/ssl/certs/console.${puppetserver_fqdn}.pem",
      path    => $pg_exec_path,
    }

    file { $certs_dir:
      ensure  => directory,
      owner   => $service_user,
      group   => $service_group,
      mode    => '0750',
      require => [User[$service_user], File[$config_dir]],
    }

    file { $seed_cert:
      ensure  => file,
      owner   => $service_user,
      group   => $service_group,
      mode    => '0644',
      source  => "/etc/puppetlabs/puppet/ssl/certs/console.${puppetserver_fqdn}.pem",
      require => [Exec['stagehand::console::ca_cert'], File[$certs_dir]],
      notify  => Service['puppet-console'],
    }

    file { $seed_key:
      ensure  => file,
      owner   => $service_user,
      group   => $service_group,
      mode    => '0600',
      source  => "/etc/puppetlabs/puppet/ssl/private_keys/console.${puppetserver_fqdn}.pem",
      require => [Exec['stagehand::console::ca_cert'], File[$certs_dir]],
      notify  => Service['puppet-console'],
    }

    file { $seed_cacert:
      ensure  => file,
      owner   => $service_user,
      group   => $service_group,
      mode    => '0644',
      source  => '/etc/puppetlabs/puppet/ssl/certs/ca.pem',
      require => File[$certs_dir],
      notify  => Service['puppet-console'],
    }

    # bolt-project scaffold — ported from the original Go installer's
    # bolt.go:653-673 (`install -d -o psh -g psh ...` + static
    # bolt-project.yaml/inventory.yaml content).
    file { $bolt_project:
      ensure  => directory,
      owner   => $service_user,
      group   => $service_group,
      mode    => '0750',
      require => User[$service_user],
    }

    file { "${bolt_project}/bolt-project.yaml":
      ensure  => file,
      owner   => $service_user,
      group   => $service_group,
      mode    => '0644',
      content => epp('stagehand/bolt-project.yaml.epp'),
      require => File[$bolt_project],
    }

    file { "${bolt_project}/inventory.yaml":
      ensure  => file,
      owner   => $service_user,
      group   => $service_group,
      mode    => '0644',
      content => epp('stagehand/inventory.yaml.epp', {
          'puppetserver_fqdn' => $puppetserver_fqdn,
      }),
      require => File[$bolt_project],
    }

    file { $env_file:
      ensure    => file,
      owner     => 'root',
      group     => $service_group,
      mode      => '0640',
      show_diff => false,
      content   => Sensitive(epp('stagehand/console.env.epp', {
            'addr'                   => ":${console_port}",
            'database_url'           => $database_url,
            'seed_puppetserver_host' => $puppetserver_fqdn,
            'seed_puppetserver_port' => $puppetserver_port,
            'seed_puppetdb_host'     => $puppetdb_host,
            'seed_puppetdb_port'     => $puppetdb_port,
            'seed_cert'              => $seed_cert,
            'seed_key'               => $seed_key,
            'seed_cacert'            => $seed_cacert,
            'bolt_path'              => $bolt_path,
            'bolt_project'           => $bolt_project,
            'external_url'           => $external_url,
            'ingest_token'           => $ingest_token.unwrap,
            'dataservice_token'      => $dataservice_token.unwrap,
      })),
      require   => File[$config_dir],
      notify    => Service['puppet-console'],
    }

    file { $unit_file:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => epp('stagehand/puppet-console.service.epp', {
          'binary'            => $binary_path,
          'env_file'          => $env_file,
          'user'              => $service_user,
          'group'             => $service_group,
          'working_directory' => $service_home,
      }),
      notify  => Exec['puppet-console-systemd-reload'],
    }

    # Present-path ordering/refresh: a changed unit file triggers a reload,
    # and a reload (if it actually ran) restarts the service so it picks up
    # the new unit. Declared here (rather than as `notify` on the shared
    # Exec['puppet-console-systemd-reload'] below) so the absent branch can
    # declare the opposite-direction edge it needs without creating a
    # dependency cycle — see the absent branch for why.
    Exec['puppet-console-systemd-reload'] ~> Service['puppet-console']
  } else {
    # Removal path — stop/disable already happens via the unconditional
    # `service` resource below (ensure/enable are $ensure-driven). This
    # branch additionally removes the binary, systemd unit, and config dir
    # (which recursively takes the env file, certs/, and bolt-project/ with
    # it via `force`). Deliberately out of scope here, per the plan's hard
    # rule: `stagehand::console_integration`'s ENC/autosign/Hiera wiring (not
    # managed by this class at all) and the Postgres role/db (only dropped
    # below when $purge_data == true).
    file { $binary_path:
      ensure => absent,
    }

    file { $unit_file:
      ensure => absent,
      notify => Exec['puppet-console-systemd-reload'],
    }

    file { $config_dir:
      ensure => absent,
      force  => true,
    }

    file { $service_home:
      ensure => absent,
      force  => true,
    }

    # $pg_state_dir lives outside $config_dir (see the present branch for
    # why — postgres can't traverse config_dir's root:psh 0750), so it isn't
    # swept up by $config_dir's recursive removal above and needs its own
    # cleanup here.
    file { '/etc/puppet-console-pg-state':
      ensure => absent,
      force  => true,
    }

    # Teardown ordering: without an explicit edge here, Puppet is free to
    # remove the unit file (and reload systemd) before the service is
    # actually stopped, since File[$unit_file]'s only declared relationship
    # is to Exec['puppet-console-systemd-reload'] (subscribe), not to the
    # service. Force the correct order: stop service -> reload systemd
    # (via the existing subscribe below) -> unit/binary already gone by
    # the time reload runs. This is the reverse direction of the present
    # branch's `Exec[...reload] ~> Service[...]` edge above, so it's
    # declared here instead of as a `notify` on the shared exec — the two
    # directions can't coexist on the same resource pair without a cycle,
    # and only one of these two branches is ever in the same catalog.
    Service['puppet-console'] -> File[$unit_file]
    Service['puppet-console'] -> File[$binary_path]

    if $purge_data {
      # Destructive drop-role/drop-db execs, mirroring the create-side
      # execs above (Task 2.2) but inverted to `onlyif` since these should
      # only run when the role/database actually exist.
      exec { 'stagehand::console::pg_db_drop':
        command => "dropdb ${db_name}",
        onlyif  => "psql -tAc \"SELECT 1 FROM pg_database WHERE datname='${db_name}'\" | grep -q 1",
        user    => 'postgres',
        path    => $pg_exec_path,
      }

      exec { 'stagehand::console::pg_role_drop':
        command => "dropuser ${db_user}",
        onlyif  => "psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname='${db_user}'\" | grep -q 1",
        user    => 'postgres',
        path    => $pg_exec_path,
        require => Exec['stagehand::console::pg_db_drop'],
      }
    }
  }

  # Declared unconditionally (rather than nested in the present branch)
  # since `File[$unit_file]` exists — with a different `ensure` — on both
  # the present and absent paths, and a daemon-reload is warranted either
  # way (unit installed vs. unit removed).
  exec { 'puppet-console-systemd-reload':
    command     => '/usr/bin/systemctl daemon-reload',
    refreshonly => true,
    subscribe   => File[$unit_file],
  }

  service { 'puppet-console':
    ensure  => $service_ensure,
    enable  => $service_enable,
    # The service shouldn't start before its database/role/pg_hba entry
    # exist, since it would fail to connect on startup otherwise.
    require => $console_service_requires,
  }
}
