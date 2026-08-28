# -*- encoding: utf-8 -*-
# stub: voxpupuli-test 14.0.0 ruby lib

Gem::Specification.new do |s|
  s.name = "voxpupuli-test".freeze
  s.version = "14.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Vox Pupuli".freeze]
  s.date = "1980-01-02"
  s.description = "A package that depends on all the gems Vox Pupuli modules need and methods to simplify spec helpers".freeze
  s.email = ["pmc@voxpupuli.org".freeze]
  s.homepage = "https://github.com/voxpupuli/voxpupuli-test".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.7.0".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Helpers for testing Vox Pupuli modules".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<rake>.freeze, ["~> 13.0", ">= 13.0.6"])
  s.add_runtime_dependency(%q<facterdb>.freeze, [">= 3.1", "< 5.0"])
  s.add_runtime_dependency(%q<metadata-json-lint>.freeze, [">= 4.0", "< 6"])
  s.add_runtime_dependency(%q<openvox-strings>.freeze, [">= 5.0", "< 8"])
  s.add_runtime_dependency(%q<parallel_tests>.freeze, [">= 4.2", "< 6"])
  s.add_runtime_dependency(%q<puppet_fixtures>.freeze, [">= 0.1", "< 3"])
  s.add_runtime_dependency(%q<puppet-syntax>.freeze, [">= 6.0", "< 8"])
  s.add_runtime_dependency(%q<rspec-github>.freeze, [">= 2.0", "< 4"])
  s.add_runtime_dependency(%q<rspec-puppet>.freeze, ["~> 5.0"])
  s.add_runtime_dependency(%q<rspec-puppet-facts>.freeze, [">= 5.4", "< 7"])
  s.add_runtime_dependency(%q<syslog>.freeze, [">= 0.3", "< 0.5"])
  s.add_runtime_dependency(%q<rubocop>.freeze, ["~> 1.85.1"])
  s.add_runtime_dependency(%q<rubocop-rake>.freeze, ["~> 0.7.1"])
  s.add_runtime_dependency(%q<rubocop-rspec>.freeze, ["~> 3.9.0"])
  s.add_runtime_dependency(%q<voxpupuli-puppet-lint-plugins>.freeze, [">= 6.0", "< 8"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.12"])
end
