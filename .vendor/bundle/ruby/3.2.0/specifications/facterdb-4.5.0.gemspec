# -*- encoding: utf-8 -*-
# stub: facterdb 4.5.0 ruby lib

Gem::Specification.new do |s|
  s.name = "facterdb".freeze
  s.version = "4.5.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Vox Pupuli".freeze]
  s.date = "1980-01-02"
  s.description = "Contains facts from many Facter version on many Operating Systems".freeze
  s.email = ["voxpupuli@groups.io".freeze]
  s.executables = ["facterdb".freeze, "legacy-facts-striper".freeze]
  s.files = ["bin/facterdb".freeze, "bin/legacy-facts-striper".freeze]
  s.homepage = "http://github.com/voxpupuli/facterdb".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2.0".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "A Database of OS facts provided by Facter".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<coveralls>.freeze, ["~> 0.8.23"])
  s.add_development_dependency(%q<rake>.freeze, ["~> 13.2", ">= 13.2.1"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.13"])
  s.add_development_dependency(%q<voxpupuli-rubocop>.freeze, ["~> 5.2.0"])
  s.add_runtime_dependency(%q<jgrep>.freeze, ["~> 1.5", ">= 1.5.4"])
end
