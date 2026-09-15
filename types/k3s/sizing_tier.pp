# @summary The appliance's operator-chosen sizing tier for a k3s-hosted
#   Console deployment.
#
# A first-class, type-constrained Hiera value (D-03) -- an operator choice,
# never auto-detected from host resources. The Hiera key an operator sets
# is `stagehand::console::k3s::sizing_tier`, reachable by automatic
# class-parameter lookup exactly like `stagehand::console::docker::image_ref`
# already is. Per D-03, the appliance's first-boot setup wizard is meant to
# collect this value directly -- that wizard does not exist yet (it is
# `stagehand-appliance/ROADMAP.md` Phase 4, two phases after this one), so
# this type exists to make the value a typed, Hiera-addressable class
# parameter now, ready for the wizard to write once it ships.
#
# Maps to appliance ADR 0006's three recorded tiers:
#   - `small`:  the target-customer tier (4 vCPU / 8 GiB / 100 GiB)
#   - `medium`: the few-thousand-node tier (8 vCPU / 16 GiB / 250 GiB)
#   - `large`:  the three-node tier with external or operator-supplied
#     PostgreSQL
#
# An unknown tier name fails catalog compilation, not a silent render of a
# wrong resource profile.
#
# Named `k3s/sizing_tier.pp` (not `types/K3sSizingTier.pp`), matching
# Puppet's file-to-typename autoloading convention documented in
# `types/docker_image_ref.pp`'s closing paragraph: path segments map to
# type-name segments verbatim, underscores preserved, only the first
# letter capitalized.
type Stagehand::K3s::Sizing_tier = Enum['small', 'medium', 'large']
