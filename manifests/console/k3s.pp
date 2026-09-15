# @summary Render the Console profile (console, PostgreSQL, Zot) from
#   Hiera into the k3s manifests directory for k3s to reconcile.
#
# The manifests-directory-rendering sibling of `stagehand::console::docker`
# -- same repo, same `$ensure` parameter-naming convention, but a
# completely different delivery mechanism: this class declares NO
# `docker::image`/`docker::run` and NO hand-rolled `Exec` for the apply
# loop. It writes `file` resources into `$manifests_dir` and stops --
# k3s's own bundled helm-controller watches that directory for HelmChart
# manifests (and its manifest-deploy controller for plain manifests) and
# reconciles them on file change (D-05, RESEARCH.md Architecture
# Pattern 2). Applied via a real `bolt apply()` of a compiled catalog
# (D-05's agentless mechanism), never a persistent puppet-agent pull
# relationship against the appliance itself.
#
# Plan 01 proved this mechanism with Zot alone (no database, no secrets in
# its default configuration). Plan 02 expands it to the full Console
# profile: the console workload itself and PostgreSQL (CloudNativePG,
# chosen at Plan 02's blocking checkpoint), plus the first Kubernetes
# Secret this class renders -- the secret-handling path Zot's own
# configuration never exercised.
#
# ## Known, disclosed gap: k3s install/lifecycle is out of scope (D-05)
# Ignition bakes k3s into the appliance image at build time, so this class
# carries ZERO k3s installation/lifecycle logic -- there is nothing to
# install on the only target this phase has. This resolves
# 999.22-RESEARCH.md Open Question 2 to "not needed." `$manage_k3s`
# defaults to `false`; flipping it to `true` fails catalog compilation
# rather than silently doing nothing, because a real non-appliance target
# for that escape hatch has not been confirmed yet -- a future phase should
# implement it deliberately, not have a reader assume it was forgotten.
#
# ## Known, disclosed gap: `ensure => 'absent'` does not retract applied resources
# Passing `ensure => 'absent'` stops this class from declaring any of its
# five rendered `File` resources at all -- Puppet simply stops managing
# them going forward. Removing a file from the k3s manifests directory
# does NOT retract Kubernetes resources k3s already applied from it --
# including the `stagehand-console-secrets` Secret object itself, which
# stays live in the cluster even after this class stops rendering the file
# that originally created it. k3s's apply-on-change mechanism has no
# observed retract-on-delete behavior. This mirrors
# `stagehand::console::docker`'s own disclosed `ensure => 'absent'` gap
# (RESEARCH.md Pitfall 3): an operator who wants the workload (or the
# Secret) actually gone needs a separate deliberate removal step, not just
# this ensure flip.
#
# @param sizing_tier
#   The operator-chosen sizing tier (D-03), type-constrained by
#   `Stagehand::K3s::Sizing_tier`. No compiled-in default -- supplied via
#   Hiera automatic parameter lookup
#   (`stagehand::console::k3s::sizing_tier`), matching
#   `stagehand::console::docker::image_ref`'s GitOps trigger model. An
#   unknown tier name fails catalog compilation rather than silently
#   rendering a wrong resource profile. Drives ALL THREE services'
#   resource-request profiles from one selector in this class's body
#   (`$sizing_profiles`) -- one tier value, never three independently
#   drifting per-service tables.
# @param image_ref
#   Fully-qualified, digest-pinned console image reference. Reuses
#   `Stagehand::Docker_image_ref` verbatim -- the SAME type
#   `stagehand::console::docker::image_ref` uses (RESEARCH.md Architecture
#   Pattern 1, Don't Hand-Roll table row 2: one validated digest-pinning
#   type for the whole project, never a second one for the k3s path). No
#   compiled-in default -- Hiera-supplied
#   (`stagehand::console::k3s::image_ref`). A tag-only or malformed
#   reference fails catalog compilation before it ever reaches the
#   rendered manifest.
# @param db_password
#   The `psh` application-owner PostgreSQL password. Unwrapped exactly
#   once, in this class's own `epp()` call for the Secret template's
#   parameter hash -- never anywhere else, and never composed into a URL
#   that lands in the console manifest (unlike
#   `stagehand::console::docker`'s `$database_url`, which DOES embed the
#   unwrapped password because it renders directly into a `docker::run`
#   `env` array, not a file k3s applies). Here the password reaches the
#   console container only via a `secretKeyRef`'d env var Kubernetes
#   substitutes into `PSH_DATABASE_URL` at container start -- see
#   `$database_url_template` below.
# @param ingest_token
#   The console's ingest API token. Unwrapped exactly once, alongside
#   `$db_password` and `$dataservice_token`, in the Secret template's
#   parameter hash only.
# @param dataservice_token
#   The console's Data Service API token. Unwrapped exactly once,
#   alongside `$db_password` and `$ingest_token`, in the Secret template's
#   parameter hash only.
# @param ensure
#   'present' declares and renders all five manifest files; 'absent' stops
#   this class from declaring them at all (see the disclosed gap above --
#   this does NOT actively retract already-applied Kubernetes resources,
#   including the Secret object). Deliberately no 'latest' value here,
#   matching `docker.pp`'s own digest/version-pinning divergence.
# @param manifests_dir
#   Absolute path to the k3s manifests directory this class renders files
#   into. Defaults to k3s's own packaged-components path
#   (`/var/lib/rancher/k3s/server/manifests`); overridable for lab/test
#   targets (this plan's own k3d harness overrides it to a bind-mounted
#   subdirectory).
# @param namespace
#   Kubernetes namespace the rendered console, PostgreSQL and Zot
#   workloads and their NetworkPolicies target.
# @param zot_chart
#   OCI reference for the Zot Helm chart. Defaults to the project's own
#   official chart (appliance ADR 0007's explicit choice for its
#   signature-aware search, break-glass UI and sync features) -- this
#   class does not reopen that choice.
# @param zot_chart_version
#   Pinned Zot Helm chart version. Sourced from
#   `stagehand-appliance/build/versions.env`'s `ZOT_CHART_VERSION` -- one
#   pinned source of truth across both repos, never two drifting pins.
# @param zot_app_version
#   Pinned Zot registry image version (the chart's `image.tag` override).
#   Sourced from `stagehand-appliance/build/versions.env`'s `ZOT_VERSION`.
# @param manage_k3s
#   Escape hatch mirroring `docker.pp`'s `$manage_docker_engine` shape.
#   Defaults to `false` (k3s is baked in by Ignition -- nothing to
#   install). Setting `true` fails catalog compilation with a message
#   naming this deliberate omission rather than silently doing nothing --
#   see the disclosed gap above.
# @param console_port
#   TCP port the console binary listens on and its Service/NetworkPolicy
#   expose. Matches `stagehand::console::docker::console_port`'s default.
# @param puppetserver_fqdn
#   FQDN used to compose the console's `PSH_EXTERNAL_URL`. Matches
#   `stagehand::console::docker::puppetserver_fqdn`'s default (the node's
#   own `networking.fqdn` fact).
# @param purge_data
#   Reserved for future PVC-purge wiring, mirroring
#   `stagehand::console::docker::purge_data`'s naming. This class does not
#   yet declare any resource this parameter changes -- Kubernetes PVC
#   lifecycle for the PostgreSQL/Zot volumes is left to the operator/chart
#   defaults for now; accepted here so a future revision can wire it in
#   without a breaking parameter-name change.
#
# @example Hiera-driven Console-profile render
#   class { 'stagehand::console::k3s':
#     db_password       => Sensitive($facts['psh_db_password']),
#     ingest_token      => Sensitive($facts['psh_ingest_token']),
#     dataservice_token => Sensitive($facts['psh_dataservice_token']),
#     # sizing_tier, image_ref supplied via Hiera
#   }
class stagehand::console::k3s (
  Stagehand::K3s::Sizing_tier $sizing_tier,
  Stagehand::Docker_image_ref $image_ref,
  Sensitive[String[1]]        $db_password,
  Sensitive[String[1]]        $ingest_token,
  Sensitive[String[1]]        $dataservice_token,
  Enum['present', 'absent']   $ensure             = 'present',
  Stdlib::Absolutepath        $manifests_dir       = '/var/lib/rancher/k3s/server/manifests',
  String[1]                   $namespace           = 'stagehand',
  String[1]                   $zot_chart           = 'oci://ghcr.io/project-zot/helm-charts/zot',
  String[1]                   $zot_chart_version   = '0.1.124',
  String[1]                   $zot_app_version     = 'v2.1.21',
  Boolean                     $manage_k3s          = false,
  Integer[1, 65535]           $console_port        = 8443,
  String[1]                   $puppetserver_fqdn   = $facts['networking']['fqdn'],
  Boolean                     $purge_data          = false,
) {
  if $manage_k3s {
    fail('stagehand::console::k3s: k3s installation is deliberately unimplemented. Ignition bakes k3s into the appliance image at build time (D-05), and 999.22-RESEARCH.md Open Question 2 resolved this to "not needed" for the only target this phase has. A future phase with a confirmed non-appliance target should implement this deliberately, not assume it was forgotten.')
  }

  # PostgreSQL delivery mechanism: CloudNativePG operator + `cluster`
  # chart, chosen at this plan's blocking checkpoint (appliance ADR 0006
  # already commits to CloudNativePG at the three-node HA tier, so
  # adopting it now for the single instance avoids a second data
  # migration). Chart refs/versions are fixed constants, not class
  # parameters -- 999.22-02-PLAN.md's Task 2 action explicitly scopes
  # postgresql.epp's interpolated values to namespace/sizing/major-version
  # only, matching `stagehand-appliance/build/versions.env`'s
  # CNPG_OPERATOR_CHART_VERSION/CNPG_CLUSTER_CHART_VERSION pins.
  $postgres_operator_chart         = 'oci://ghcr.io/cloudnative-pg/charts/cloudnative-pg'
  $postgres_operator_chart_version = '0.29.0'
  $postgres_cluster_chart          = 'oci://ghcr.io/cloudnative-pg/charts/cluster'
  $postgres_cluster_chart_version  = '0.8.1'
  # Matches build/versions.env's POSTGRES_MAJOR and the `postgres:16`
  # default `stagehand::console::docker` uses -- one major version, never
  # two independently-drifting pins across the two deployment paths.
  $postgres_major = '16'

  # Sizing-tier resource-request profile: ONE selector, in this class's
  # body, producing CPU/memory requests+limits for the console and
  # PostgreSQL (plus PostgreSQL's storage size). Zot's own PVC-size tier
  # selector stays inline in zot-helmchart.epp (Plan 01, unmodified this
  # plan) -- both derive from the identical $sizing_tier value, so the
  # tier still fans out consistently to all three services even though
  # the mapping tables live in two places. Values scaled from appliance
  # ADR 0006's recorded hardware tiers (4 vCPU/8 GiB/100 GiB small,
  # 8/16/250 medium, three-node large).
  $sizing_profiles = {
    'small'  => {
      'console'  => {
        'cpu_request' => '250m', 'cpu_limit' => '1', 'memory_request' => '256Mi', 'memory_limit' => '512Mi',
      },
      'postgres' => {
        'cpu_request' => '500m', 'cpu_limit' => '2', 'memory_request' => '1Gi', 'memory_limit' => '2Gi',
        'storage'     => '10Gi',
      },
    },
    'medium' => {
      'console'  => {
        'cpu_request' => '500m', 'cpu_limit' => '2', 'memory_request' => '512Mi', 'memory_limit' => '1Gi',
      },
      'postgres' => {
        'cpu_request' => '1', 'cpu_limit' => '4', 'memory_request' => '2Gi', 'memory_limit' => '4Gi',
        'storage'     => '50Gi',
      },
    },
    'large'  => {
      'console'  => {
        'cpu_request' => '1', 'cpu_limit' => '4', 'memory_request' => '1Gi', 'memory_limit' => '2Gi',
      },
      'postgres' => {
        'cpu_request' => '2', 'cpu_limit' => '8', 'memory_request' => '4Gi', 'memory_limit' => '8Gi',
        'storage'     => '200Gi',
      },
    },
  }
  $sizing_profile = $sizing_profiles[$sizing_tier]

  # Parse the single, type-validated $image_ref into its registry-path
  # half and its digest half -- same regsubst approach
  # stagehand::console::docker uses (docker.pp lines 137-139), so both
  # deployment paths parse the same reference the same way.
  $registry_repo    = regsubst($image_ref, '\A(.*)@sha256:[0-9a-f]{64}\z', '\1')
  $image_digest_hex = regsubst($image_ref, '\A.*@sha256:([0-9a-f]{64})\z', '\1')
  $image_digest     = "sha256:${image_digest_hex}"

  # Database URL, assembled the same way docker.pp line 170 does (same
  # `psh` user/database constants) -- but with one deliberate difference:
  # the password is NEVER interpolated here as a literal, because this
  # string lands in a Puppet-rendered FILE k3s applies (docker.pp's
  # equivalent lands directly in a `docker::run` `env` array, never
  # written to disk as a file). Instead this is a URL TEMPLATE containing
  # the literal Kubernetes env-substitution placeholder `$(PSH_DB_PASSWORD)`
  # -- Kubernetes itself substitutes that placeholder from a
  # secretKeyRef'd env var at container start (see
  # console-helmchart.epp). The `psh` user/database/host/port pieces are
  # not secret and are safe to interpolate directly.
  $db_user          = 'psh'
  $db_name          = 'psh'
  $postgres_host    = "stagehand-postgres-rw.${namespace}.svc.cluster.local"
  $postgres_port    = 5432
  $database_url_template = "postgres://${db_user}:\$(PSH_DB_PASSWORD)@${postgres_host}:${postgres_port}/${db_name}?sslmode=disable"

  if $ensure != 'absent' {
    file { "${manifests_dir}/stagehand-zot.yaml":
      ensure  => 'file',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => epp('stagehand/console/k3s/zot-helmchart.epp', {
        'namespace'     => $namespace,
        'chart'         => $zot_chart,
        'chart_version' => $zot_chart_version,
        'app_version'   => $zot_app_version,
        'sizing_tier'   => $sizing_tier,
      }),
    }

    file { "${manifests_dir}/stagehand-zot-networkpolicy.yaml":
      ensure  => 'file',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => epp('stagehand/console/k3s/networkpolicy.epp', {
        'namespace' => $namespace,
        'service'   => 'zot',
      }),
    }

    file { "${manifests_dir}/stagehand-console.yaml":
      ensure  => 'file',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => epp('stagehand/console/k3s/console-helmchart.epp', {
        'namespace'             => $namespace,
        'registry_repo'         => $registry_repo,
        'image_digest'          => $image_digest,
        'console_port'          => $console_port,
        'puppetserver_fqdn'     => $puppetserver_fqdn,
        'database_url_template' => $database_url_template,
        'cpu_request'           => $sizing_profile['console']['cpu_request'],
        'cpu_limit'             => $sizing_profile['console']['cpu_limit'],
        'memory_request'        => $sizing_profile['console']['memory_request'],
        'memory_limit'          => $sizing_profile['console']['memory_limit'],
      }),
    }

    file { "${manifests_dir}/stagehand-postgresql.yaml":
      ensure  => 'file',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => epp('stagehand/console/k3s/postgresql.epp', {
        'namespace'              => $namespace,
        'operator_chart'         => $postgres_operator_chart,
        'operator_chart_version' => $postgres_operator_chart_version,
        'cluster_chart'          => $postgres_cluster_chart,
        'cluster_chart_version'  => $postgres_cluster_chart_version,
        'postgres_major'         => $postgres_major,
        'storage_size'           => $sizing_profile['postgres']['storage'],
        'cpu_request'            => $sizing_profile['postgres']['cpu_request'],
        'cpu_limit'              => $sizing_profile['postgres']['cpu_limit'],
        'memory_request'         => $sizing_profile['postgres']['memory_request'],
        'memory_limit'           => $sizing_profile['postgres']['memory_limit'],
      }),
    }

    # The Secret manifest: the ONLY rendered file carrying secret
    # material. Its restrictive permission and Puppet's own diff
    # suppression (see below) are both mandatory -- RESEARCH.md's
    # Security Domain table and this project's puppet-best-practices
    # secret-handling conventions require the pairing. The three
    # parameter-hash calls that reach into the Sensitive values below are
    # the only such calls anywhere in this class.
    file { "${manifests_dir}/stagehand-secrets.yaml":
      ensure    => 'file',
      owner     => 'root',
      group     => 'root',
      mode      => '0600',
      show_diff => false,
      content   => epp('stagehand/console/k3s/secrets.epp', {
        'namespace'         => $namespace,
        'db_password'       => $db_password.unwrap,
        'ingest_token'      => $ingest_token.unwrap,
        'dataservice_token' => $dataservice_token.unwrap,
      }),
    }
  }
}
