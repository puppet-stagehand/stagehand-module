# -*- encoding: utf-8 -*-
# stub: beaker-hiera 2.1.0 ruby lib

Gem::Specification.new do |s|
  s.name = "beaker-hiera".freeze
  s.version = "2.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Vox Pupuli".freeze, "Puppetlabs".freeze]
  s.date = "1980-01-02"
  s.description = "For use for the Beaker acceptance testing tool".freeze
  s.email = ["voxpupuli@groups.io".freeze]
  s.executables = ["beaker-hiera".freeze]
  s.files = ["bin/beaker-hiera".freeze]
  s.homepage = "https://github.com/voxpupuli/beaker-hiera".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new([">= 3.2".freeze, "< 5".freeze])
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Hiera DSL Helpers!".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<pry>.freeze, ["~> 0.10"])
  s.add_development_dependency(%q<rake>.freeze, ["~> 13.0"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0"])
  s.add_development_dependency(%q<voxpupuli-rubocop>.freeze, ["~> 5.1.0"])
  s.add_runtime_dependency(%q<beaker>.freeze, [">= 4", "< 8"])
end
