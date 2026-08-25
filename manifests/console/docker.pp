# @summary Run the Puppet Stagehand Console as a digest-pinned Docker container.
#
# The container-lifecycle sibling of `stagehand::console` (native/systemd) --
# same repo, same `$ensure`/`$purge_data` parameter-naming convention, but a
# completely different resource set (`docker::image`/`docker::run` from
# `puppetlabs/docker`, never a hand-rolled `Exec` for container start/stop/
# recreate -- D-09).
#
# ## Trigger model (D-07)
# A one-shot Bolt task/plan (lives outside this module, per Open Question 1
# in 999.1-RESEARCH.md) handles the INITIAL deploy via `apply_prep`/`apply`.
# This class's ongoing job is pure declarative convergence: a scheduled
# Puppet agent run reads `$image_ref` from Hiera (automatic class-parameter
# lookup -- D-08's GitOps trigger) and converges the running container to
# match. There is no Bolt re-invocation for a routine update, ever.
#
# ## Update safety (D-10/D-11/D-12/D-13)
# `$image_ref` is a full `registry@sha256:<digest>` reference (type-enforced
# by `Stagehand::DockerImageRef`, never a mutable tag). The same digest half
# feeds both `docker::image`'s `image_digest` and `docker::run`'s
# `verify_digest` -- one parsed source of truth, not two independently-typed
# digests. There is deliberately no health-check-polling or automatic
# rollback anywhere in this class (D-12): reverting the Hiera commit and
# letting the next agent run re-converge to the prior digest IS the recovery
# mechanism. A guarded `pg_dump` Exec (the one legitimate hand-rolled `Exec`
# in this class -- D-13, not a D-09 violation, see 999.1-RESEARCH.md Pattern
# 2) runs immediately before a digest change is applied.
#
# ## Postgres topology (resolved via this plan's checkpoint: postgres-in-container)
# Postgres runs as its own `docker::run` container (`stagehand-postgres`),
# data on a named Docker volume, port bound to `127.0.0.1` only (T-999.1-04)
# -- matching `puppet-installer`'s existing Compose-path (`dockerstack.go`)
# topology, not `stagehand::console`'s native co-located-host-Postgres
# assumption. Switching topology later is a one-way door (a live
# pg_dump/restore data migration, not a manifest edit) -- see
# 999.1-CONTEXT.md's checkpoint rationale.
#
# ## Docker engine ownership (resolves RESEARCH.md Open Question 3)
# When `$manage_docker_engine` (the default), this class `include`s
# `docker` (the `puppetlabs/docker` module's own engine-install class) and
# takes ownership of engine install/config on the container host -- unlike
# `stagehand::console`'s Postgres-server assumption, no existing code path
# in this repo set installs a bare Docker engine ahead of this class.
#
# ## Known, disclosed gap: no `hierascope_*` support
# Unlike `stagehand::console`, this class does not thread through any
# `hierascope_*` parameters or stage a hierascope binary -- CONTEXT.md's
# locked decisions (D-01..D-13) never ask for it on the container path. This
# is an explicit, disclosed omission (not a silent drop), matching this
# project's "flag deferred work, never silently drop it" convention. A
# future plan may add it if/when hierascope needs to run against a
# container-deployed console.
#
# ## Known, disclosed gap: `ensure => 'absent'` does not tear down the container
# Passing `ensure => 'absent'` stops this class from declaring
# `Docker::Image['stagehand-console']`/`Docker::Run['stagehand-console']` at
# all -- Puppet simply stops managing them going forward, it does not
# actively stop/remove a container left running by a prior apply. This
# mirrors D-12's "no automatic machinery beyond convergence" philosophy but
# is a real, disclosed limitation: an operator who wants the container
# actually removed needs a separate manual `docker rm`/Bolt task, not just
# this ensure flip. `$purge_data` still has real effect independent of this:
# when `true` and `$ensure == 'absent'`, the Postgres-in-container topology's
# named data volume is also dropped.
#
# @param ensure
#   'present' declares and converges the console + Postgres containers;
#   'absent' stops this class from declaring them at all (see the disclosed
#   gap above -- this does NOT actively remove a running container).
#   Deliberately no 'latest' value here, unlike `stagehand::console`'s
#   ensure Enum -- digest pinning removes the floating-tag concept 'latest'
#   represents; a new digest is how you get a new version, not `ensure`.
# @param purge_data
#   When `$ensure == 'absent'`, also drops the Postgres-in-container
#   topology's named data volume (`stagehand-postgres-data`). Has no effect
#   otherwise.
# @param image_ref
#   The console image to run, as a full digest-pinned reference
#   (`registry@sha256:<64-hex>`). No compiled-in default -- supplied via
#   Hiera automatic parameter lookup once this class is classified/applied
#   (D-08's GitOps trigger model). Type-constrained by
#   `Stagehand::DockerImageRef` so a malformed/tag-only reference fails
#   catalog compilation rather than being silently accepted.
# @param db_password
#   Password for the console's Postgres role, both inside the
#   `stagehand-postgres` container's `POSTGRES_PASSWORD` env and the
#   console's own `PSH_DATABASE_URL`.
# @param ingest_token
#   Bearer token the console accepts on its ingest API (`PSH_INGEST_TOKEN`).
# @param dataservice_token
#   Bearer token the console accepts on its Hiera Data Service API
#   (`PSH_DATASERVICE_TOKEN`).
# @param console_port
#   Port the console binary listens on inside its container, published on
#   all host interfaces (the console itself must stay externally
#   reachable, unlike Postgres).
# @param puppetserver_fqdn
#   FQDN of the puppetserver primary this console instance seeds data from.
#   Defaults to the applying node's own fqdn (co-located install).
# @param postgres_image
#   Full image reference (registry/repo:tag) for the `stagehand-postgres`
#   container. Not digest-pinned -- D-10/D-11's verification requirement is
#   specific to the console image, not its database.
# @param manage_docker_engine
#   When true (the default), this class `include`s `docker` and takes
#   ownership of Docker engine install/config on this host. Set false if
#   the engine is already managed elsewhere (e.g. an operator's own
#   pre-existing `docker` classification).
#
# @example Hiera-driven, GitOps-triggered container deploy
#   class { 'stagehand::console::docker':
#     db_password       => Sensitive($facts['psh_db_password']),
#     ingest_token      => Sensitive($facts['psh_ingest_token']),
#     dataservice_token => Sensitive($facts['psh_dataservice_token']),
#     # image_ref supplied via Hiera: stagehand::console::docker::image_ref
#   }
class stagehand::console::docker (
  Stagehand::Docker_image_ref $image_ref,
  Sensitive[String[1]]        $db_password,
  Sensitive[String[1]]        $ingest_token,
  Sensitive[String[1]]        $dataservice_token,
  Enum['present', 'absent']   $ensure                = 'present',
  Boolean                     $purge_data             = false,
  Integer[1, 65535]           $console_port           = 8443,
  String[1]                   $puppetserver_fqdn      = $facts['networking']['fqdn'],
  String[1]                   $postgres_image         = 'postgres:16',
  Boolean                     $manage_docker_engine   = true,
) {
  $db_user = 'psh'
  $db_name = 'psh'

  # Parse the single, type-validated $image_ref into its registry-path half
  # (for docker::image's `image` param) and its digest half (used, in
  # "sha256:<hex>" form, as BOTH docker::image's `image_digest` and
  # docker::run's `verify_digest` -- one parsed source of truth, never two
  # independently-typed digests, per this plan's key_links contract).
  $registry_repo    = regsubst($image_ref, '\A(.*)@sha256:[0-9a-f]{64}\z', '\1')
  $image_digest_hex = regsubst($image_ref, '\A.*@sha256:([0-9a-f]{64})\z', '\1')
  $image_digest     = "sha256:${image_digest_hex}"

  $docker_run_ensure = $ensure ? {
    'absent' => 'absent',
    default  => 'present',
  }

  if $manage_docker_engine {
    include docker
  }

  # pg_dump-client package name resolution, keyed on $facts['os']['family'].
  # Declared exactly once, top-level (not nested inside the postgres-in-
  # container-vs-on-host conditional below) -- mirrors console.pp's own
  # unconditional ensure_packages(['openssl']) placement. Closes
  # 999.1-RESEARCH.md Assumption A4's flagged untested-compatibility gap:
  # puppetlabs/docker's own declared operatingsystem_support omits RedHat/
  # Rocky/AlmaLinux/Ubuntu 24.04/Debian 12, all of which stagehand itself
  # supports -- this class's own client-package resolution stays correct
  # across the full stagehand-supported OS matrix regardless.
  $pg_client_package = $facts['os']['family'] ? {
    'RedHat' => 'postgresql',
    default  => 'postgresql-client',
  }
  ensure_packages([$pg_client_package])

  # Postgres-in-container topology (this plan's resolved checkpoint).
  # Bound to 127.0.0.1 only -- never a wildcard interface (T-999.1-04) --
  # so the database is unreachable from anything but host-local traffic.
  $postgres_host = '127.0.0.1'
  $postgres_port = 5432
  $database_url  = "postgres://${db_user}:${db_password.unwrap}@${postgres_host}:${postgres_port}/${db_name}?sslmode=disable"

  # Named Docker volume backing Postgres's data directory. Declared
  # unconditionally (not nested inside the `if $ensure != 'absent'` branch
  # below) so `$purge_data` can flip it to `absent` independently of
  # whether this class still declares the console/Postgres containers
  # themselves -- see the "known, disclosed gap" doc-comment above.
  $postgres_volume_ensure = ($ensure == 'absent' and $purge_data) ? {
    true    => 'absent',
    default => 'present',
  }

  docker_volume { 'stagehand-postgres-data':
    ensure => $postgres_volume_ensure,
  }

  if $ensure != 'absent' {
    $postgres_tag = regsubst($postgres_image, '\A[^:]+:(.+)\z', '\1')

    docker::image { 'stagehand-postgres':
      image     => 'postgres',
      image_tag => $postgres_tag,
    }

    docker::run { 'stagehand-postgres':
      ensure  => $docker_run_ensure,
      image   => $postgres_image,
      ports   => ["${postgres_host}:${postgres_port}:5432"],
      volumes => ['stagehand-postgres-data:/var/lib/postgresql/data'],
      env     => [
        "POSTGRES_USER=${db_user}",
        "POSTGRES_PASSWORD=${db_password.unwrap}",
        "POSTGRES_DB=${db_name}",
      ],
      restart => 'always',
      require => [Docker::Image['stagehand-postgres'], Docker_volume['stagehand-postgres-data']],
    }

    docker::image { 'stagehand-console':
      image        => $registry_repo,
      image_digest => $image_digest,
    }

    # D-13: guarded pg_dump snapshot, immediately before a digest change is
    # applied. The ONLY hand-rolled Exec in this class -- D-09's
    # "no hand-rolled Exec" rule targets container start/stop/recreate
    # specifically (docker::run owns that), not this data-safety
    # side-effect (999.1-RESEARCH.md Pattern 2).
    #
    # onlyif guard: compares the running container's current RepoDigest
    # (from `docker inspect`, which returns "registry@sha256:<hex>" -- the
    # same shape as $image_ref) against $image_ref. An absent/errored
    # inspect (no prior container) is treated as "always snapshot-skip
    # since there is nothing to protect yet" -- the `test -n` check below
    # short-circuits false when CURRENT is empty, before the digest
    # comparison ever runs.
    #
    # Credentials pass via the exec's `environment` parameter only --
    # mirroring backend/internal/selfupdate/snapshot.go's pgEnv convention
    # (WR-01) -- never interpolated into `command`/`onlyif`, so `ps aux`/
    # `/proc/<pid>/cmdline` never expose them (T-999.1-02).
    $pg_snapshot_dir    = '/var/backups/stagehand-console'
    $current_digest_cmd = "docker inspect --format='{{index .RepoDigests 0}}' stagehand-console 2>/dev/null"

    file { $pg_snapshot_dir:
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0700',
    }

    exec { 'stagehand::console::docker::pg_snapshot':
      command     => "/bin/sh -c 'pg_dump -Fc -f \"${pg_snapshot_dir}/pre-update-\$(date +%s).dump\"'",
      onlyif      => "/bin/sh -c 'CURRENT=\$(${current_digest_cmd}); test -n \"\$CURRENT\" && [ \"\$CURRENT\" != \"${image_ref}\" ]'",
      path        => ['/usr/bin', '/bin', '/usr/local/bin'],
      environment => [
        "PGHOST=${postgres_host}",
        "PGPORT=${postgres_port}",
        "PGUSER=${db_user}",
        "PGPASSWORD=${db_password.unwrap}",
        "PGDATABASE=${db_name}",
      ],
      require     => [File[$pg_snapshot_dir], Package[$pg_client_package]],
      before      => Docker::Run['stagehand-console'],
    }

    docker::run { 'stagehand-console':
      ensure        => $docker_run_ensure,
      image         => $image_ref,
      verify_digest => $image_digest,
      ports         => ["${console_port}:${console_port}"],
      env           => [
        "PSH_ADDR=:${console_port}",
        "PSH_DATABASE_URL=${database_url}",
        "PSH_INGEST_TOKEN=${ingest_token.unwrap}",
        "PSH_DATASERVICE_TOKEN=${dataservice_token.unwrap}",
        "PSH_EXTERNAL_URL=http://${puppetserver_fqdn}:${console_port}",
      ],
      restart       => 'always',
      require       => Docker::Image['stagehand-console'],
    }
  }
}
