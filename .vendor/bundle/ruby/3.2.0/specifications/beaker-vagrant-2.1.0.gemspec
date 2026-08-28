# -*- encoding: utf-8 -*-
# stub: beaker-vagrant 2.1.0 ruby lib

Gem::Specification.new do |s|
  s.name = "beaker-vagrant".freeze
  s.version = "2.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/voxpupuli/beaker-vagrant/issues", "changelog_uri" => "https://github.com/voxpupuli/beaker-vagrant/blob/main/CHANGELOG.md", "rubygems_mfa_required" => "true", "source_code_uri" => "https://github.com/voxpupuli/beaker-vagrant" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Vox Pupuli".freeze, "Rishi Javia".freeze, "Kevin Imber".freeze, "Tony Vu".freeze]
  s.date = "1980-01-02"
  s.description = "For use for the Beaker acceptance testing tool".freeze
  s.email = "voxpupuli@groups.io".freeze
  s.executables = ["beaker-vagrant".freeze]
  s.files = ["bin/beaker-vagrant".freeze]
  s.homepage = "https://github.com/puppetlabs/beaker-vagrant".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new([">= 3.2".freeze, "< 5".freeze])
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Beaker DSL Extension Helpers!".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<fakefs>.freeze, [">= 0.6", "< 4"])
  s.add_development_dependency(%q<pry>.freeze, ["~> 0.10"])
  s.add_development_dependency(%q<rake>.freeze, ["~> 13.0"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0"])
  s.add_development_dependency(%q<voxpupuli-rubocop>.freeze, ["~> 5.2.0"])
  s.add_runtime_dependency(%q<beaker>.freeze, [">= 4", "< 8"])
end
