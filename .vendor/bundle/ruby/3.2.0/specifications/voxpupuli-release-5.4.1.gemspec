# -*- encoding: utf-8 -*-
# stub: voxpupuli-release 5.4.1 ruby lib

Gem::Specification.new do |s|
  s.name = "voxpupuli-release".freeze
  s.version = "5.4.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Vox Pupuli".freeze]
  s.date = "1980-01-02"
  s.email = ["voxpupuli@groups.io".freeze]
  s.homepage = "https://github.com/voxpupuli/voxpupuli-release".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Helpers for deploying Vox Pupuli modules".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<faraday-retry>.freeze, ["~> 2.1"])
  s.add_runtime_dependency(%q<github_changelog_generator>.freeze, ["~> 1.16", ">= 1.16.4"])
  s.add_runtime_dependency(%q<openvox>.freeze, ["< 9"])
  s.add_runtime_dependency(%q<openvox-strings>.freeze, ["~> 7.0"])
  s.add_runtime_dependency(%q<puppet-blacksmith>.freeze, [">= 8.0", "< 10"])
  s.add_runtime_dependency(%q<rake>.freeze, ["~> 13.0", ">= 13.0.6"])
  s.add_runtime_dependency(%q<syslog>.freeze, [">= 0.3.0", "< 0.5"])
  s.add_development_dependency(%q<voxpupuli-rubocop>.freeze, ["~> 5.2.0"])
end
