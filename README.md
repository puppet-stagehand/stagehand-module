# stagehand — Puppet Stagehand

The **stagehand** module (Forge: `puppetlabs-stagehand`): one namespace for every ops task the
Puppet Stagehand Console invokes, plus `stagehand::console_integration` — the idempotent
class that wires a puppetserver primary to the console. **This repo is stagehand's
permanent home**; the `puppet-core-installer` vendors it onto the target
basemodulepath from GitHub at build time (see the top-level README's Vendoring
section).

## Classes

- **`stagehand::console_integration`** — apply on the **primary** to wire it to the
  console at compile time: cache-aware ENC shim (`GET /api/v1/enc/<cert>`),
  self-contained trusted-external command (`GET /api/v1/external-data/<cert>`
  → `trusted.external.psh.*`), the `stagehand::hiera_data` Hiera Data-Service tier,
  and the policy-autosign hook (`GET /api/v1/autosign/<challenge>`). Edits
  puppet.conf idempotently (guarded `puppet config set`, no inifile dep). This
  is the permanent replacement for `hack/tier1-wire.sh`. Needs a console
  service token with `hiera:read` + `nodedata:read`.
- **`stagehand::compilers`** — `include node_encrypt::certificates` so every compile
  server can encrypt for any agent (multi-primary). Absorbed from the retired
  `puppet_core::compilers`.
- **`stagehand`** — inert anchor; `include stagehand` does nothing. Patch
  posture (`patchbot`) and compliance scanning (`trivy`/`openscap`) live in
  their own sibling modules — see [Sibling first-party modules](../README.md).

## Functions

- **`stagehand::secret(Variant[String,Sensitive[String]])` → `Deferred`** — branded
  wrapper over `node_encrypt::secret()`; encrypts at compile time with the
  requesting node's cert, decrypted only on that agent. Absorbed from the
  retired `puppet_core::secret`. Requires the `node_encrypt` dependency
  (declared in metadata; vendored alongside stagehand).

## Tasks (all self-contained; the console calls `stagehand::*` only)

Compliance scanning (`trivy::trivy_scan`, `openscap::openscap_scan`) and
patching (`patchbot::patch`) used to live here — they've moved to their own
sibling modules (`trivy`, `openscap`, `patchbot`) so third parties can swap in
their own scanner/patcher without depending on `stagehand` at all. See
[Sibling first-party modules](../README.md) below and each module's own
README for its task and, for the scanners, the `compliance.v1` schema.

- `stagehand::recert` — guarded re-certification (challenge + `ext_pp_*` identity
  extensions, `input_method: environment` so they pass through).
- `stagehand::r10k_deploy` — deploy one environment's code via r10k (pull-based).
- `stagehand::run_playbook` — run a pasted Ansible playbook against the node itself
  via `ansible-playbook --connection=local -i localhost,` (Bolt pushes this
  task; no separate Ansible control node exists). Installs Ansible first per
  `install_method` (`auto`/`package`/`pip`/`pipx`/`wsl`/`skip`) unless
  `skip`, sourcing `install_ansible.sh` so a chained install lands in the
  same run record. Playbook/extra_vars content is delivered only via stdin
  JSON, written to 0600 temp files, never argv; rejects a playbook that
  doesn't declare both `hosts: localhost` and `connection: local`
  (defense-in-depth — the console API is authoritative). Stdout is a single
  JSON object: `{"install": {...}, "play": {...}}`.
- `stagehand::install_ansible` — standalone entry point for the same install
  logic `stagehand::run_playbook` sources; useful for pre-staging Ansible on a
  node directly.

## Functions / facts / templates

- `lib/puppet/functions/stagehand/hiera_data.rb` — the `stagehand::hiera_data` Hiera
  `data_hash` backend (last-good cache; `on_error` use_cache|continue|fail).
- `templates/*.epp` — the shims/config `stagehand::console_integration` renders
  (client.yaml, ENC shim, trusted-external, autosign hook, hiera.yaml).

## Standing up the console: secrets explained

`stagehand::console` (runs the console app) and `stagehand::console_integration` (wires a
puppetserver primary to it) between them take five sensitive-ish values. None
of them come from an external identity system — they're shared secrets **you
invent**, except `console_binary_source`, which is a file you have to obtain
separately. Traced from the actual templates/functions this module renders
(not just the docstrings), here's what each one does and where it has to
match another one:

| Param | On class | What it's for | Where it comes from |
|---|---|---|---|
| `db_password` | `stagehand::console` | Password for the console's own Postgres role/db (`psh`/`psh`). Purely local — nothing to do with puppetserver. | You invent it, e.g. `openssl rand -base64 32`. `stagehand::console` creates/syncs the Postgres role to match. |
| `ingest_token` | `stagehand::console` | Doorkey for things **pushing data into** the console — the Bolt tasks in the sibling `trivy`, `openscap`, and `patchbot` modules (`trivy::trivy_scan`, `openscap::openscap_scan`, `patchbot::patch`) POST scan/patch results to the console's ingest API. Becomes `PSH_INGEST_TOKEN` (`templates/console.env.epp`). | You invent it, e.g. `openssl rand -hex 32`, and give the same value to whatever calls the ingest API. |
| `dataservice_token` | `stagehand::console` | Doorkey for things **pulling data out** — becomes `PSH_DATASERVICE_TOKEN` (`templates/console.env.epp`). | You invent it — **and it must equal `stagehand::console_integration`'s `token` param below.** |
| `token` | `stagehand::console_integration` | The Bearer token puppetserver presents when it calls the console. `templates/psh-trusted-external.sh.epp` and `lib/puppet/functions/stagehand/hiera_data.rb` both send `Authorization: Bearer <token>`; `console.env.epp` only defines one inbound token for those two APIs (`PSH_DATASERVICE_TOKEN`) — so this has to be the **same string** as `dataservice_token`. | Same invented string as `dataservice_token`, reused. |
| `console_binary_source` | `stagehand::console` | The compiled `puppet-console` binary, staged wherever the target can read it (local path or `puppet:///modules/...`) — `stagehand::console` just copies it into place. | **Not produced by this repo.** Comes from the separate `puppet_console` installer repo; stage it yourself (Bolt `upload_file`, artifact download, package, etc.) before applying `stagehand::console`. |

Note the asymmetry: `psh-enc.sh.epp` (the ENC shim) sends **no auth header at
all**, and `psh-autosign.sh.epp` authenticates via the CSR's challenge
password, not a Bearer token — so `token`/`dataservice_token` only cover 2 of
the 4 integration points (trusted-external data, Hiera Data Service lookups).

Other `stagehand::console` params are non-secret lifecycle/network knobs:
`console_port` (default `8443`, which port the app listens on),
`puppetserver_fqdn` (default: applying node's own fqdn — co-located
single-box setup), `ensure` (`present`/`latest`/`absent`), `purge_data`
(whether `absent` also drops the Postgres role/db), and `version`
(informational only — `file`'s checksum comparison already re-copies a
changed binary regardless).

### Example: profile wiring both classes together

```puppet
class profile::psh::all_in_one (
  String[1]            $console_binary_source,
  Sensitive[String[1]] $db_password,
  Sensitive[String[1]] $ingest_token,
  Sensitive[String[1]] $shared_console_token,   # == dataservice_token == console_integration's token
) {
  class { 'core_module_pack':
    console_url         => "https://${facts['networking']['fqdn']}",
    token                => $shared_console_token,
    manage_console       => false,        # skip the separate puppet_console module
    manage_console_app   => true,         # use stagehand::console instead
    console_app_options  => {
      'console_binary_source' => $console_binary_source,
      'db_password'            => $db_password,
      'ingest_token'           => $ingest_token,
      'dataservice_token'      => $shared_console_token,
    },
  }
}
```

```yaml
lookup_options:
  '^profile::psh::all_in_one::.+_token$':
    convert_to: 'Sensitive'
  '^profile::psh::all_in_one::.+_password$':
    convert_to: 'Sensitive'

profile::psh::all_in_one::console_binary_source: '/opt/staging/puppet-console'
profile::psh::all_in_one::db_password:           'ENC[PKCS7,...]'
profile::psh::all_in_one::ingest_token:          'ENC[PKCS7,...]'
profile::psh::all_in_one::shared_console_token:  'ENC[PKCS7,...]'
```

### Platform notes: OpenVox / Puppet Core / PE

`stagehand` only touches puppetserver through generic, standard mechanisms — an ENC
(`node_terminus`/`external_nodes`), a `trusted-external-command`, a Hiera 5
custom backend, and an `autosign` executable. Those exist identically across
flavors, so most differences are about what's already on the box, not code:

| Platform | What's different | What to set |
|---|---|---|
| **OpenVox** | Community fork, no built-in classifier or license server. This is the baseline case the module's defaults assume. | Defaults as-is. |
| **Puppet Core** (Perforce) | Same AIO install layout (`/opt/puppetlabs`, `/etc/puppetlabs`) as OpenVox. Only difference is needing a Puppet Core EULA + Forge API key to install puppetserver itself — a procurement step, not a `stagehand` setting. | Defaults as-is once puppetserver is installed. |
| **Puppet Enterprise (PE)** | PE ships its own node classifier (console node groups) and its own autosign policy machinery, using the same `puppet.conf` settings (`node_terminus`/`external_nodes`, `autosign`) this module manages. Leaving `manage_enc`/`manage_autosign` at their `true` defaults overwrites PE's classification/signing wiring. | Decide who's the source of truth. If Stagehand should classify: leave defaults. If PE should stay in charge: set `manage_enc => false, manage_autosign => false` and keep only `manage_trusted_external => true, manage_hiera => true` (those two are additive and don't collide with PE). |

`console_integration`'s default paths (`confdir`/`codedir`) are the shared
AIO layout and don't need to change across any of the above.

## Stage it (dev loop, until the installer vendors the pack)

```
./hack/install-stagehand.sh [MODULEPATH_DIR]
bolt task show stagehand::recert
puppet parser validate <modulepath>/stagehand/manifests/console_integration.pp
```
