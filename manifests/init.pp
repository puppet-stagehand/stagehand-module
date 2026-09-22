# @summary Puppet Stagehand — anchor/documentation class.
#
# This anchor class itself manages nothing by default. It exists so a node
# can `include stagehand` as a stable entry point and so the module has a
# documented root.
#
# `stagehand` (this repo) is the one consolidated module for everything the
# Puppet Stagehand Console needs from Puppet — it is not split across
# sibling modules (999.12 D-01–D-03): the puppetserver-integration class,
# the console-provisioning manifests, and every Bolt task the console
# dispatches all live here, versioned together.
#
#   * stagehand::console_integration — wire a puppetserver primary to the
#                                      console (ENC shim, trusted-external,
#                                      Hiera Data Service, policy autosign).
#                                      Primary only.
#   * stagehand::console,
#     stagehand::console::docker,
#     stagehand::console::k3s          — install, configure, and run the
#                                      console binary itself (systemd unit,
#                                      Docker container, or k3s deployment).
#   * stagehand::patching             — roll the `patchbot` external fact
#                                      onto agents so the console's
#                                      Patching page has data (the PULL
#                                      path; no Bolt push required). Opt-in;
#                                      see the `manage_patching` param below.
#
# The console-invoked Bolt tasks ship in `tasks/` and need no
# classification — Bolt runs them directly: `stagehand::recert`,
# `stagehand::r10k_deploy`, `stagehand::run_playbook`,
# `stagehand::install_ansible`, `stagehand::class_enumerate`,
# `stagehand::scanner_lifecycle`, `stagehand::trivy_scan`,
# `stagehand::openscap_scan`, `stagehand::inspector_scan`, and
# `stagehand::patch` (the push complement to `stagehand::patching`'s pull
# path). None of them need an opt-in parameter here — Bolt dispatches them
# directly and they need no prior classification to run.
#
# @param manage_patching
#   When true, `include stagehand` also applies stagehand::patching (roll the
#   fact to every classified node). Off by default so `include stagehand`
#   stays inert.
#
# @example Roll the patch fact fleet-wide from a base profile
#   class profile::base {
#     include stagehand::patching
#   }
#
# @example Wire the primary (usually done by the installer, not a node group)
#   class { 'stagehand::console_integration':
#     console_url => 'https://console.example.com',
#     token       => Sensitive('psh_...'),
#   }
class stagehand (
  Boolean $manage_patching = false,
) {
  if $manage_patching {
    include stagehand::patching
  }
}
