# -*- encoding: utf-8 -*-
# stub: beaker-rspec 9.1.0 ruby lib

Gem::Specification.new do |s|
  s.name = "beaker-rspec".freeze
  s.version = "9.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Vox Pupuli".freeze]
  s.date = "1980-01-02"
  s.description = "RSpec bindings for beaker, see https://github.com/voxpupuli/beaker".freeze
  s.email = ["voxpupuli@groups.io".freeze]
  s.homepage = "https://github.com/voxpupuli/beaker-rspec".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new([">= 3.2.0".freeze, "< 5.0.0".freeze])
  s.rubygems_version = "3.4.20".freeze
  s.summary = "RSpec bindings for beaker".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<fakefs>.freeze, [">= 0.6", "< 4"])
  s.add_development_dependency(%q<minitest>.freeze, [">= 5.4", "< 7"])
  s.add_development_dependency(%q<rake>.freeze, ["~> 13.0"])
  s.add_development_dependency(%q<voxpupuli-rubocop>.freeze, ["~> 5.1.0"])
  s.add_runtime_dependency(%q<beaker>.freeze, [">= 4.0", "< 8"])
  s.add_runtime_dependency(%q<rspec>.freeze, ["~> 3.0"])
  s.add_runtime_dependency(%q<serverspec>.freeze, ["~> 2"])
  s.add_runtime_dependency(%q<specinfra>.freeze, ["~> 2"])
end
