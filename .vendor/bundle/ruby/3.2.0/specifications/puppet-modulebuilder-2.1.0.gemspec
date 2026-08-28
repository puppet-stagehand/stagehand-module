# -*- encoding: utf-8 -*-
# stub: puppet-modulebuilder 2.1.0 ruby lib

Gem::Specification.new do |s|
  s.name = "puppet-modulebuilder".freeze
  s.version = "2.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://github.com/puppetlabs/puppet-modulebuilder/blob/main/CHANGELOG.md", "homepage_uri" => "https://github.com/puppetlabs/puppet-modulebuilder", "source_code_uri" => "https://github.com/puppetlabs/puppet-modulebuilder" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Sheena".freeze, "Team IAC".freeze]
  s.bindir = "exe".freeze
  s.date = "2025-05-21"
  s.email = ["sheena@puppet.com".freeze, "https://puppetlabs.github.io/iac/".freeze]
  s.homepage = "https://github.com/puppetlabs/puppet-modulebuilder".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.1.0".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "A gem to set up puppet-modulebuilder".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<minitar>.freeze, [">= 0.9", "< 2"])
  s.add_runtime_dependency(%q<pathspec>.freeze, [">= 0.2.1", "< 3.0.0"])
  s.add_development_dependency(%q<voxpupuli-rubocop>.freeze, ["~> 4.0.0"])
end
