# -*- encoding: utf-8 -*-
# stub: openvox-strings 7.1.0 ruby lib

Gem::Specification.new do |s|
  s.name = "openvox-strings".freeze
  s.version = "7.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Puppet Inc.".freeze, "Vox Pupuli".freeze]
  s.date = "1980-01-02"
  s.email = "voxpupuli@groups.io".freeze
  s.extra_rdoc_files = ["CHANGELOG.md".freeze, "LICENSE".freeze, "README.md".freeze]
  s.files = ["CHANGELOG.md".freeze, "LICENSE".freeze, "README.md".freeze]
  s.homepage = "https://github.com/voxpupuli/openvox-strings".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2.0".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Puppet documentation via YARD".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<irb>.freeze, ["< 2"])
  s.add_runtime_dependency(%q<rgen>.freeze, [">= 0.9", "< 0.11"])
  s.add_runtime_dependency(%q<yard>.freeze, ["~> 0.9"])
  s.add_development_dependency(%q<openvox>.freeze, [">= 8.24", "< 9"])
  s.add_development_dependency(%q<voxpupuli-rubocop>.freeze, ["~> 5.1.0"])
end
