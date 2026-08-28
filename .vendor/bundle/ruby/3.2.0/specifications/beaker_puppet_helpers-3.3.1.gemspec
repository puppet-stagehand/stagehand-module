# -*- encoding: utf-8 -*-
# stub: beaker_puppet_helpers 3.3.1 ruby lib

Gem::Specification.new do |s|
  s.name = "beaker_puppet_helpers".freeze
  s.version = "3.3.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/voxpupuli/beaker_puppet_helpers/issues", "changelog_uri" => "https://github.com/voxpupuli/beaker_puppet_helpers/blob/main/CHANGELOG.md", "rubygems_mfa_required" => "true", "source_code_uri" => "https://github.com/voxpupuli/beaker_puppet_helpers" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Vox Pupuli".freeze]
  s.date = "1980-01-02"
  s.description = "For use for the Beaker acceptance testing tool".freeze
  s.email = ["voxpupuli@groups.io".freeze]
  s.homepage = "https://github.com/voxpupuli/beaker_puppet_helpers".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Beaker's Puppet DSL Extension Helpers".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<beaker>.freeze, [">= 5.8.1", "< 8"])
  s.add_runtime_dependency(%q<nokogiri>.freeze, ["~> 1.18", ">= 1.18.10"])
  s.add_runtime_dependency(%q<open-uri>.freeze, ["< 0.6"])
  s.add_runtime_dependency(%q<puppet-modulebuilder>.freeze, [">= 0.3", "< 3"])
  s.add_development_dependency(%q<voxpupuli-rubocop>.freeze, ["~> 5.1.0"])
end
