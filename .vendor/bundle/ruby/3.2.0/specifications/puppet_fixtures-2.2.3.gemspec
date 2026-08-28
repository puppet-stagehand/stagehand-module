# -*- encoding: utf-8 -*-
# stub: puppet_fixtures 2.2.3 ruby lib

Gem::Specification.new do |s|
  s.name = "puppet_fixtures".freeze
  s.version = "2.2.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "source_code_uri" => "https://github.com/voxpupuli/puppet_fixtures" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Ewoud Kohl van Wijngaarden".freeze, "Vox Pupuli".freeze]
  s.date = "1980-01-02"
  s.description = "Originally part of puppetlabs_spec_helper, but with a significant\nrefactoring to make it available standalone.\n".freeze
  s.executables = ["puppet-fixtures".freeze]
  s.files = ["bin/puppet-fixtures".freeze]
  s.homepage = "https://github.com/voxpupuli/puppet_fixtures".freeze
  s.licenses = ["GPL-2.0-only".freeze]
  s.required_ruby_version = Gem::Requirement.new([">= 3.2".freeze, "< 5".freeze])
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Set up fixtures for Puppet testing".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<logger>.freeze, ["< 2"])
  s.add_runtime_dependency(%q<rake>.freeze, ["~> 13.0"])
  s.add_development_dependency(%q<voxpupuli-rubocop>.freeze, ["~> 5.2.0"])
end
