# -*- encoding: utf-8 -*-
# stub: voxpupuli-acceptance 4.4.0 ruby lib

Gem::Specification.new do |s|
  s.name = "voxpupuli-acceptance".freeze
  s.version = "4.4.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/voxpupuli/voxpupuli-acceptance/issues", "changelog_uri" => "https://github.com/voxpupuli/voxpupuli-acceptance/blob/main/CHANGELOG.md", "rubygems_mfa_required" => "true", "source_code_uri" => "https://github.com/voxpupuli/voxpupuli-acceptance" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Vox Pupuli".freeze]
  s.date = "1980-01-02"
  s.description = "A package that depends on all the gems Vox Pupuli modules need and methods to simplify acceptance spec helpers".freeze
  s.email = ["voxpupuli@groups.io".freeze]
  s.homepage = "https://github.com/voxpupuli/voxpupuli-acceptance".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new([">= 3.2".freeze, "< 5".freeze])
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Helpers for acceptance testing Vox Pupuli modules".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<bcrypt_pbkdf>.freeze, ["~> 1.1"])
  s.add_runtime_dependency(%q<beaker>.freeze, [">= 6.0", "< 8"])
  s.add_runtime_dependency(%q<beaker-docker>.freeze, [">= 2.1", "< 4"])
  s.add_runtime_dependency(%q<beaker-hiera>.freeze, [">= 1.0", "< 3"])
  s.add_runtime_dependency(%q<beaker-hostgenerator>.freeze, [">= 2.2", "< 4"])
  s.add_runtime_dependency(%q<beaker_puppet_helpers>.freeze, [">= 2.2", "< 4"])
  s.add_runtime_dependency(%q<beaker-rspec>.freeze, [">= 8.0.1", "< 10"])
  s.add_runtime_dependency(%q<beaker-vagrant>.freeze, [">= 1.2", "< 3"])
  s.add_runtime_dependency(%q<puppet_fixtures>.freeze, [">= 0.1", "< 3"])
  s.add_runtime_dependency(%q<puppet-modulebuilder>.freeze, ["~> 2.0", ">= 2.0.2"])
  s.add_runtime_dependency(%q<rake>.freeze, ["~> 13.0", ">= 13.0.6"])
  s.add_runtime_dependency(%q<rspec-github>.freeze, [">= 2.0", "< 4"])
  s.add_runtime_dependency(%q<serverspec>.freeze, ["~> 2.42", ">= 2.42.2"])
  s.add_runtime_dependency(%q<winrm>.freeze, ["~> 2.3", ">= 2.3.6"])
  s.add_development_dependency(%q<voxpupuli-rubocop>.freeze, ["~> 5.2.0"])
end
