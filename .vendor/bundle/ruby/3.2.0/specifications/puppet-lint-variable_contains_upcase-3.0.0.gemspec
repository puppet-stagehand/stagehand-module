# -*- encoding: utf-8 -*-
# stub: puppet-lint-variable_contains_upcase 3.0.0 ruby lib

Gem::Specification.new do |s|
  s.name = "puppet-lint-variable_contains_upcase".freeze
  s.version = "3.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Chris Spence".freeze, "Vox Pupuli".freeze]
  s.date = "1980-01-02"
  s.description = "    Extends puppet-lint to ensure that your variables are all lower case\n".freeze
  s.email = "voxpupuli@groups.io".freeze
  s.homepage = "https://github.com/fiddyspence/puppetlint-variablecase".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "puppet-lint variable_case check".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<puppet-lint>.freeze, ["~> 5.1"])
end
