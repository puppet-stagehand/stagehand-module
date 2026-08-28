# -*- encoding: utf-8 -*-
# stub: rspec-puppet-facts 6.2.0 ruby lib

Gem::Specification.new do |s|
  s.name = "rspec-puppet-facts".freeze
  s.version = "6.2.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Vox Pupuli".freeze]
  s.date = "1980-01-02"
  s.description = "Contains facts from many Facter version on many Operating Systems".freeze
  s.email = ["voxpupuli@groups.io".freeze]
  s.homepage = "http://github.com/voxpupuli/rspec-puppet-facts".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2.0".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Standard facts fixtures for Puppet".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<mime-types>.freeze, ["~> 3.5", ">= 3.5.2"])
  s.add_development_dependency(%q<rake>.freeze, ["~> 13.1"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.12"])
  s.add_development_dependency(%q<yard>.freeze, ["~> 0.9.34"])
  s.add_development_dependency(%q<voxpupuli-rubocop>.freeze, ["~> 5.2.0"])
  s.add_runtime_dependency(%q<deep_merge>.freeze, ["~> 1.2"])
  s.add_runtime_dependency(%q<facterdb>.freeze, [">= 3.1", "< 5.0"])
  s.add_runtime_dependency(%q<openfact>.freeze, ["~> 5.0"])
end
