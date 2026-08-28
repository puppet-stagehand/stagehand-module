# -*- encoding: utf-8 -*-
# stub: beaker-docker 3.1.3 ruby lib

Gem::Specification.new do |s|
  s.name = "beaker-docker".freeze
  s.version = "3.1.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Vox Pupuli".freeze, "Rishi Javia".freeze, "Kevin Imber".freeze, "Tony Vu".freeze]
  s.date = "1980-01-02"
  s.description = "Allows running Beaker tests using Docker".freeze
  s.email = ["voxpupuli@groups.io".freeze]
  s.executables = ["beaker-docker".freeze]
  s.files = ["bin/beaker-docker".freeze]
  s.homepage = "https://github.com/voxpupuli/beaker-docker".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new([">= 3.2".freeze, "< 5".freeze])
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Docker hypervisor for Beaker acceptance testing framework".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<fakefs>.freeze, [">= 1.3", "< 4"])
  s.add_development_dependency(%q<irb>.freeze, ["< 2"])
  s.add_development_dependency(%q<rake>.freeze, ["~> 13.0"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0"])
  s.add_development_dependency(%q<voxpupuli-rubocop>.freeze, ["~> 5.1.0"])
  s.add_runtime_dependency(%q<beaker>.freeze, [">= 4", "< 8"])
  s.add_runtime_dependency(%q<docker-api>.freeze, ["~> 2.3"])
  s.add_runtime_dependency(%q<excon>.freeze, [">= 1.2.5", "< 2", "!= 1.2.6"])
  s.add_runtime_dependency(%q<stringify-hash>.freeze, ["~> 0.0.0"])
end
