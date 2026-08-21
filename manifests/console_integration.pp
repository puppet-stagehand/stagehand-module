# @summary Wire a puppetserver primary to the Puppet Stagehand Console.
#
# The permanent, idempotent replacement for `hack/tier1-wire.sh`. Apply this
# on the **puppetserver primary** (the installer does this at install time;
# it is not a node-group classification) and the primary gains, at compile
# time, everything the console drives:
#
#   1. ENC via exec         → a cache-aware shim hits GET /api/v1/enc/<cert>
#                             (last-good cache; authoritative-empty on 404;
#                             serve cache on transport failure; always exit 0).
#   2. Trusted external      → a self-contained shell command hits
#                             GET /api/v1/external-data/<cert> (Bearer token),
#                             emitting trusted.external.psh.{data,groups,
#                             primary_group}. No console binary required.
#   3. Hiera Data Service    → the environment hiera.yaml gains a
#                             `stagehand::hiera_data` tier (console-served data,
#                             on_error=use_cache) above the on-disk tiers.
#   4. Policy autosign       → CSRs from the console's one-paste registration
#                             verify their challenge against
#                             GET /api/v1/autosign/<challenge>?certname=<cert>.
#
# Puppet.conf is edited idempotently with guarded `puppet config set` execs
# (server section) so the module pins only puppetlabs/stdlib — no inifile.
#
# @param console_url
#   Console base URL as reachable FROM the puppetserver (e.g.
#   'https://console.example.com' or, in Compose, 'http://console:8767').
# @param token
#   Console service token with scopes hiera:read + nodedata:read. Feeds the
#   Hiera backend (client.yaml) and the trusted-external command.
# @param confdir       Puppet confdir. Default '/etc/puppetlabs/puppet'.
# @param codedir       Puppet codedir. Default '/etc/puppetlabs/code'.
# @param environment   Environment whose hiera.yaml gets the console tier.
# @param cache_root    Parent dir for the last-good caches. Default
#                      '/opt/puppetlabs/server/data'.
# @param puppet_user   Owner for client config + caches. Default 'puppet'.
# @param puppet_group  Group for client config + caches. Default 'puppet'.
# @param manage_enc                 Manage the ENC shim + node_terminus. Default true.
# @param manage_trusted_external    Manage the trusted-external command. Default true.
# @param manage_hiera               Manage the environment hiera.yaml tier. Default true.
# @param manage_autosign            Manage the policy-autosign hook. Default true.
# @param puppetserver_service
#   Service to refresh when the wiring changes. Default 'puppetserver'.
# @param manage_service
#   Whether to notify the puppetserver service on change. Default true.
#
# @example Installer/primary
#   class { 'stagehand::console_integration':
#     console_url => 'https://console.example.com',
#     token       => Sensitive('psh_...'),
#   }
class stagehand::console_integration (
  String[1]                    $console_url,
  Variant[String[1], Sensitive[String[1]]] $token,
  Stdlib::Absolutepath         $confdir                = '/etc/puppetlabs/puppet',
  Stdlib::Absolutepath         $codedir                = '/etc/puppetlabs/code',
  String[1]                    $environment            = 'production',
  Stdlib::Absolutepath         $cache_root             = '/opt/puppetlabs/server/data',
  String[1]                    $puppet_user            = 'puppet',
  String[1]                    $puppet_group           = 'puppet',
  Boolean                      $manage_enc             = true,
  Boolean                      $manage_trusted_external = true,
  Boolean                      $manage_hiera           = true,
  Boolean                      $manage_autosign        = true,
  String[1]                    $puppetserver_service   = 'puppetserver',
  Boolean                      $manage_service         = true,
) {
  $token_str = if $token =~ Sensitive { $token.unwrap } else { $token }

  $client_dir   = '/etc/puppetlabs/psh'
  $client_yaml  = "${client_dir}/client.yaml"
  $enc_path     = "${confdir}/psh-enc.sh"
  $autosign_path = "${confdir}/psh-autosign"
  $trusted_dir  = "${confdir}/trusted-external-commands"
  $trusted_cmd  = "${trusted_dir}/psh"
  $enc_cache    = "${cache_root}/psh-enc-cache"
  $ext_cache    = "${cache_root}/psh-ext-cache"
  $hiera_cache  = "${cache_root}/psh-hiera-cache"
  $env_dir      = "${codedir}/environments/${environment}"

  $bin = '/opt/puppetlabs/bin/puppet'

  # Refresh the service only if asked; collect the trigger once.
  $svc_notify = $manage_service ? {
    true    => Service[$puppetserver_service],
    default => undef,
  }

  if $manage_service {
    # Declared here so File/Exec can notify it; ensure=>running is the primary's
    # existing state (the installer starts it). We only refresh on change.
    if !defined(Service[$puppetserver_service]) {
      service { $puppetserver_service:
        ensure => running,
        enable => true,
      }
    }
  }

  # ── client config + cache dirs ──────────────────────────────────────────────
  file { $client_dir:
    ensure => directory,
    owner  => $puppet_user,
    group  => $puppet_group,
    mode   => '0750',
  }

  file { $client_yaml:
    ensure    => file,
    owner     => $puppet_user,
    group     => $puppet_group,
    mode      => '0640',
    show_diff => false,
    content   => Sensitive(epp('stagehand/client.yaml.epp', {
      'baseuri' => $console_url,
      'token'   => $token_str,
    })),
    require   => File[$client_dir],
  }

  [$enc_cache, $ext_cache, $hiera_cache].each |$dir| {
    file { $dir:
      ensure => directory,
      owner  => $puppet_user,
      group  => $puppet_group,
      mode   => '0750',
    }
  }

  # ── ENC shim (cache-aware) ──────────────────────────────────────────────────
  if $manage_enc {
    file { $enc_path:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      content => epp('stagehand/psh-enc.sh.epp', {
        'console_url' => $console_url,
        'cache_dir'   => $enc_cache,
      }),
      notify  => $svc_notify,
    }

    stagehand::console_integration::puppet_conf { 'node_terminus':
      value      => 'exec',
      bin        => $bin,
      svc_notify => $svc_notify,
    }
    stagehand::console_integration::puppet_conf { 'external_nodes':
      value      => $enc_path,
      bin        => $bin,
      svc_notify => $svc_notify,
      require    => File[$enc_path],
    }
  }

  # ── trusted external command (self-contained; no console binary) ────────────
  if $manage_trusted_external {
    file { $trusted_dir:
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }
    file { $trusted_cmd:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      content => epp('stagehand/psh-trusted-external.sh.epp', {
        'console_url' => $console_url,
        'client_yaml' => $client_yaml,
        'cache_dir'   => $ext_cache,
      }),
      require => File[$trusted_dir],
      notify  => $svc_notify,
    }
    stagehand::console_integration::puppet_conf { 'trusted_external_command':
      value      => $trusted_dir,
      bin        => $bin,
      svc_notify => $svc_notify,
      require    => File[$trusted_cmd],
    }
  }

  # ── policy autosign hook ────────────────────────────────────────────────────
  if $manage_autosign {
    file { $autosign_path:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      content => epp('stagehand/psh-autosign.sh.epp', {
        'console_url' => $console_url,
      }),
      notify  => $svc_notify,
    }
    stagehand::console_integration::puppet_conf { 'autosign':
      value      => $autosign_path,
      bin        => $bin,
      svc_notify => $svc_notify,
      require    => File[$autosign_path],
    }
  }

  # ── Hiera Data Service tier ─────────────────────────────────────────────────
  if $manage_hiera {
    file { "${env_dir}/hiera.yaml":
      ensure  => file,
      owner   => $puppet_user,
      group   => $puppet_group,
      mode    => '0644',
      content => epp('stagehand/hiera.yaml.epp', {
        'client_yaml' => $client_yaml,
      }),
      notify  => $svc_notify,
    }
  }
}
