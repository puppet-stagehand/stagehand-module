# -*- encoding: utf-8 -*-
# stub: beaker-hostgenerator 3.8.0 ruby lib

Gem::Specification.new do |s|
  s.name = "beaker-hostgenerator".freeze
  s.version = "3.8.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Branan Purvine-Riley".freeze, "Wayne Warren".freeze, "Nate Wolfe".freeze, "Vox Pupuli".freeze]
  s.date = "1980-01-02"
  s.description = "The beaker-hostgenerator tool will take a Beaker SUT (System Under Test) spec as\nits first positional argument and use that to generate a Beaker host\nconfiguration file.\n".freeze
  s.email = ["pmc@voxpupuli.org".freeze]
  s.executables = ["beaker-hostgenerator".freeze]
  s.files = ["bin/beaker-hostgenerator".freeze]
  s.homepage = "https://github.com/puppetlabs/beaker-hostgenerator".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Beaker Host Generator Utility".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<fakefs>.freeze, [">= 0.6", "< 4.0"])
  s.add_development_dependency(%q<minitest>.freeze, [">= 5.18", "< 7"])
  s.add_development_dependency(%q<pry>.freeze, ["~> 0.10"])
  s.add_development_dependency(%q<rake>.freeze, ["~> 13.0"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0"])
  s.add_development_dependency(%q<rspec-its>.freeze, [">= 1.3.1", "< 3"])
  s.add_development_dependency(%q<voxpupuli-rubocop>.freeze, ["~> 5.2.0"])
  s.add_runtime_dependency(%q<deep_merge>.freeze, ["~> 1.0"])
end
