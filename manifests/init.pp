# @summary Puppet Stagehand (stagehand) — anchor/documentation class.
#
# `stagehand` itself manages nothing. It exists so a node can `include
# stagehand` as a stable entry point and so the module has a documented root.
# The class that does real work is `stagehand::console_integration` — wire a
# puppetserver primary to the console (ENC shim, trusted-external, Hiera Data
# Service, policy autosign). Primary only.
#
# The console-invoked Bolt tasks (stagehand::recert, stagehand::r10k_deploy)
# ship in tasks/ and need no classification — Bolt runs them directly.
#
# Patch posture/patching (`patchbot`) and compliance scanning
# (`trivy`/`openscap`) live in their own sibling modules — they're optional,
# swappable add-ons, not part of the always-present puppetserver-integration
# surface this module owns. See each module's own README.
#
# @example Wire the primary (usually done by the installer, not a node group)
#   class { 'stagehand::console_integration':
#     console_url => 'https://console.example.com',
#     token       => $facts['psh_service_token'],
#   }
class stagehand {
}
