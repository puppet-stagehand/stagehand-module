# @summary Render the Console profile's Zot registry from Hiera into the
#   k3s manifests directory, where k3s's own helm-controller reconciles it.
#
# The manifests-directory-rendering sibling of `stagehand::console::docker`
# -- same repo, same `$ensure` parameter-naming convention, but a
# completely different delivery mechanism: this class declares NO
# `docker::image`/`docker::run` and NO hand-rolled `Exec` for the apply
# loop. It writes two `file` resources into `$manifests_dir` and stops --
# k3s's own bundled helm-controller watches that directory for HelmChart
# and NetworkPolicy manifests and reconciles them on file change (D-05,
# RESEARCH.md Architecture Pattern 2). Applied via a real `bolt apply()` of
# a compiled catalog (D-05's agentless mechanism), never a persistent
# puppet-agent pull relationship against the appliance itself.
#
# Zot is this plan's tracer payload -- the simplest of the three
# console-profile services (no database, no secrets in its default
# configuration). PostgreSQL and the console itself are Plan 02's expansion
# out from this same pattern.
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
# Passing `ensure => 'absent'` stops this class from declaring either
# rendered `File` resource at all -- Puppet simply stops managing them
# going forward. Removing a file from the k3s manifests directory does NOT
# retract Kubernetes resources k3s already applied from it; k3s's
# apply-on-change mechanism has no observed retract-on-delete behavior.
# This mirrors `stagehand::console::docker`'s own disclosed
# `ensure => 'absent'` gap (RESEARCH.md Pitfall 3): an operator who wants
# the workload actually gone needs a separate deliberate removal step, not
# just this ensure flip.
#
# @param sizing_tier
#   The operator-chosen sizing tier (D-03), type-constrained by
#   `Stagehand::K3s::Sizing_tier`. No compiled-in default -- supplied via
#   Hiera automatic parameter lookup
#   (`stagehand::console::k3s::sizing_tier`), matching
#   `stagehand::console::docker::image_ref`'s GitOps trigger model. An
#   unknown tier name fails catalog compilation rather than silently
#   rendering a wrong resource profile.
# @param ensure
#   'present' declares and renders the Zot manifest files; 'absent' stops
#   this class from declaring them at all (see the disclosed gap above --
#   this does NOT actively retract already-applied Kubernetes resources).
#   Deliberately no 'latest' value here, matching `docker.pp`'s own
#   digest/version-pinning divergence.
# @param manifests_dir
#   Absolute path to the k3s manifests directory this class renders files
#   into. Defaults to k3s's own packaged-components path
#   (`/var/lib/rancher/k3s/server/manifests`); overridable for lab/test
#   targets (this plan's own k3d harness overrides it to a bind-mounted
#   subdirectory).
# @param namespace
#   Kubernetes namespace the rendered Zot workload and its NetworkPolicy
#   target (`spec.targetNamespace` on the HelmChart CR, and the
#   NetworkPolicy's own `metadata.namespace`).
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
#
# @example Hiera-driven Zot render
#   class { 'stagehand::console::k3s':
#     # sizing_tier supplied via Hiera: stagehand::console::k3s::sizing_tier
#   }
class stagehand::console::k3s (
  Stagehand::K3s::Sizing_tier $sizing_tier,
  Enum['present', 'absent']   $ensure             = 'present',
  Stdlib::Absolutepath        $manifests_dir       = '/var/lib/rancher/k3s/server/manifests',
  String[1]                   $namespace           = 'stagehand',
  String[1]                   $zot_chart           = 'oci://ghcr.io/project-zot/helm-charts/zot',
  String[1]                   $zot_chart_version   = '0.1.124',
  String[1]                   $zot_app_version     = 'v2.1.21',
  Boolean                     $manage_k3s          = false,
) {
  if $manage_k3s {
    fail('stagehand::console::k3s: k3s installation is deliberately unimplemented. Ignition bakes k3s into the appliance image at build time (D-05), and 999.22-RESEARCH.md Open Question 2 resolved this to "not needed" for the only target this phase has. A future phase with a confirmed non-appliance target should implement this deliberately, not assume it was forgotten.')
  }

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
      }),
    }
  }
}
