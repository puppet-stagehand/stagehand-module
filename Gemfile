# Managed by modulesync - DO NOT EDIT
# https://voxpupuli.org/docs/updating-files-managed-with-modulesync/

source ENV['GEM_SOURCE'] || 'https://rubygems.org'

group :test do
  gem 'voxpupuli-test', '~> 14.0',  :require => false
  gem 'puppet_metadata', '~> 6.1',  :require => false
end

group :development do
  gem 'guard-rake',               :require => false
  gem 'overcommit', '>= 0.39.1',  :require => false
end

# puppet_litmus pulls in `bolt`, which hard-requires the `puppet` gem
# (`puppet >= 6.18.0`), which in turn caps puppet-resource_api at `~> 1.5`.
# openvox >= 8.24 (which includes every openvox9 pre-release currently on
# rubygems.org -- 9.0.0.pre.alpha2/pre.beta1/pre.beta2) requires
# puppet-resource_api `~> 2.0`, so the two are mutually unresolvable in one
# bundle. There is no meaningful litmus/acceptance target for the openvox9
# beta line anyway (see ci.yml's openvox9-beta job: dependency-resolution
# only, continue-on-error), so skip this group entirely for that scenario
# rather than let Bundler's resolver fail closed on an unresolvable graph.
openvox_gem_version = ENV['OPENVOX_GEM_VERSION']
skip_system_tests_for_openvox_beta = openvox_gem_version && openvox_gem_version.match?(/\A9\.|pre|beta|alpha/i)

group :system_tests do
  gem 'puppet_litmus', '~> 2.5', :require => false
  gem 'voxpupuli-acceptance', '~> 4.4',  :require => false
end unless skip_system_tests_for_openvox_beta

group :release do
  gem 'voxpupuli-release', '~> 5.3',  :require => false
end

gem 'rake', :require => false

# `puppet` and `openvox` cannot be declared into the bundle at the same
# time once openvox reaches its >= 8.24 line: those releases require
# puppet-resource_api ~> 2.0, while every released `puppet` gem (up to the
# current 8.10.0 ceiling -- there is no puppet9 rubygem yet) requires
# puppet-resource_api ~> 1.5, so bundler cannot satisfy both at once. Each
# CI leg (puppet7/puppet8 vs openvox8/openvox9) only ever sets ONE of
# PUPPET_GEM_VERSION/OPENVOX_GEM_VERSION, so select exactly one gem here
# rather than declaring both unconditionally.
if ENV['OPENVOX_GEM_VERSION']
  gem 'openvox', ENV['OPENVOX_GEM_VERSION'], :require => false, :groups => [:test]
else
  gem 'puppet', ENV.fetch('PUPPET_GEM_VERSION', [">= 7", "< 9"]), :require => false, :groups => [:test]
end

# vim: syntax=ruby
