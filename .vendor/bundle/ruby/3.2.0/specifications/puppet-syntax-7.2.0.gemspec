# -*- encoding: utf-8 -*-
# stub: puppet-syntax 7.2.0 ruby lib

Gem::Specification.new do |s|
  s.name = "puppet-syntax".freeze
  s.version = "7.2.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Vox Pupuli".freeze]
  s.date = "1980-01-02"
  s.description = "Syntax checks for Puppet manifests and templates".freeze
  s.email = ["voxpupuli@groups.io".freeze]
  s.homepage = "https://github.com/voxpupuli/puppet-syntax".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Syntax checks for Puppet manifests, templates, and Hiera YAML".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<openvox>.freeze, [">= 8", "< 9"])
  s.add_runtime_dependency(%q<rake>.freeze, ["~> 13.1"])
  s.add_development_dependency(%q<voxpupuli-rubocop>.freeze, ["~> 5.1.0"])
end
