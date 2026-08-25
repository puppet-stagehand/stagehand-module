# @summary A fully-qualified, digest-pinned Docker image reference.
#
# Matches `<registry-path>@sha256:<64-lowercase-hex-chars>` -- e.g.
# `ghcr.io/puppet-stagehand/console@sha256:5f3b1c...`. A bare tag
# (`registry/repo:latest`) or a missing/malformed digest fails Puppet
# catalog compilation (ASVS V5) instead of being silently accepted and only
# failing later at `docker pull` time. `stagehand::console::docker`'s
# `$image_ref` parameter uses this type -- it is the sole mechanism D-10/D-11
# rely on to guarantee a Hiera-supplied image reference is well-formed
# before it ever reaches `docker::image`/`docker::run` or the pg_snapshot
# Exec's digest-comparison guard.
#
# Named `Docker_image_ref` (not `DockerImageRef`) to match Puppet's real
# file-to-typename autoloading convention: path segments map to type-name
# segments verbatim (underscores preserved, only the first letter
# capitalized) -- confirmed against this same module's fixture copy of
# `puppetlabs/apt`'s `types/auth_conf_entry.pp` -> `Apt::Auth_conf_entry`.
type Stagehand::Docker_image_ref = Pattern[/\A\S+@sha256:[0-9a-f]{64}\z/]
