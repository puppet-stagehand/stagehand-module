# -*- encoding: utf-8 -*-
# stub: puppet-strings 4.1.2 ruby lib

Gem::Specification.new do |s|
  s.name = "puppet-strings".freeze
  s.version = "4.1.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Puppet Inc.".freeze]
  s.date = "2023-12-05"
  s.email = "info@puppet.com".freeze
  s.extra_rdoc_files = ["CHANGELOG.md".freeze, "CONTRIBUTING.md".freeze, "LICENSE".freeze, "README.md".freeze]
  s.files = ["CHANGELOG.md".freeze, "CONTRIBUTING.md".freeze, "LICENSE".freeze, "README.md".freeze]
  s.homepage = "https://github.com/puppetlabs/puppet-strings".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.7.0".freeze)
  s.requirements = ["puppet, >= 7.0.0".freeze]
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Puppet documentation via YARD".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<rgen>.freeze, ["~> 0.9"])
  s.add_runtime_dependency(%q<yard>.freeze, ["~> 0.9"])
end
