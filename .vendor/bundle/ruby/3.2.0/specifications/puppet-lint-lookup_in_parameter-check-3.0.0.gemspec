# -*- encoding: utf-8 -*-
# stub: puppet-lint-lookup_in_parameter-check 3.0.0 ruby lib

Gem::Specification.new do |s|
  s.name = "puppet-lint-lookup_in_parameter-check".freeze
  s.version = "3.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://github.com/voxpupuli/puppet-lint-lookup_in_parameter-check/blob/main/CHANGELOG.md", "homepage_uri" => "https://github.com/voxpupuli/puppet-lint-lookup_in_parameter-check" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Romain Tarti\u00E8re".freeze, "Vox Pupuli".freeze]
  s.bindir = "exe".freeze
  s.date = "1980-01-02"
  s.email = ["voxpupuli@groups.io".freeze]
  s.homepage = "https://github.com/voxpupuli/puppet-lint-lookup_in_parameter-check".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Check lookup is not used in parameters".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<puppet-lint>.freeze, ["~> 5.1"])
end
