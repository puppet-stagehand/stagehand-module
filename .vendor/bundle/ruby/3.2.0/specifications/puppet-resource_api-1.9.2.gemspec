# -*- encoding: utf-8 -*-
# stub: puppet-resource_api 1.9.2 ruby lib

Gem::Specification.new do |s|
  s.name = "puppet-resource_api".freeze
  s.version = "1.9.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["David Schmitt".freeze]
  s.bindir = "exe".freeze
  s.date = "2026-05-18"
  s.email = ["david.schmitt@puppet.com".freeze]
  s.homepage = "https://github.com/puppetlabs/puppet-resource_api".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.rubygems_version = "3.4.20".freeze
  s.summary = "This library provides a simple way to write new native resources for puppet.".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<hocon>.freeze, [">= 1.0"])
end
