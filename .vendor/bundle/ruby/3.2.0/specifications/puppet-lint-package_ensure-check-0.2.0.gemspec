# -*- encoding: utf-8 -*-
# stub: puppet-lint-package_ensure-check 0.2.0 ruby lib

Gem::Specification.new do |s|
  s.name = "puppet-lint-package_ensure-check".freeze
  s.version = "0.2.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["David Danzilio".freeze]
  s.date = "2016-10-26"
  s.description = "A puppet-lint plugin to check the ensure attribute on package resources.".freeze
  s.email = "david@danzilio.net".freeze
  s.homepage = "https://github.com/danzilio/puppet-lint-package_ensure-check".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.rubygems_version = "3.4.20".freeze
  s.summary = "A puppet-lint plugin to check the ensure attribute on package resources.".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<puppet-lint>.freeze, [">= 1.0"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0"])
  s.add_development_dependency(%q<rspec-its>.freeze, ["~> 1.0"])
  s.add_development_dependency(%q<rspec-collection_matchers>.freeze, ["~> 1.0"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
end
