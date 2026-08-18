# @summary Let every compile server encrypt for any agent (node_encrypt).
#
# node_encrypt is zero-config for a single server via the agent's
# `clientcert_pem` fact. With multiple compilers, include this class on the
# compile servers so they collect all agents' public certificates and can
# encrypt from any node. Absorbed from the retired `puppet_core::compilers` at
# the 2026-07 consolidation.
#
# @example on compilers (via classification or the control repo)
#   include stagehand::compilers
class stagehand::compilers {
  include node_encrypt::certificates
}
