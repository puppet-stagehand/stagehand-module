# @summary Encrypt a secret for the target node (branded node_encrypt wrapper).
#
# A thin, stable wrapper over `node_encrypt::secret()` so manifests can use a
# branded `stagehand::secret()` API. The value is encrypted at compile time with the
# requesting node's certificate and returned as a Deferred the agent decrypts
# at apply time — so it never appears in cleartext in the catalog, reports, or
# PuppetDB. Absorbed from the retired `puppet_core::secret` at the 2026-07
# consolidation (docs/design/stagehand-consolidation-plan.md).
#
# @param value The sensitive value to encrypt (String or Sensitive[String]).
# @return [Deferred] node-decryptable value suitable for any resource parameter.
#
# @example
#   file { '/etc/app/secret':
#     content => stagehand::secret(Sensitive(lookup('app::password'))),
#   }
function stagehand::secret(Variant[String, Sensitive[String]] $value) >> Deferred {
  node_encrypt::secret($value)
}
