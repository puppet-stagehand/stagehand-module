# -*- encoding: utf-8 -*-
# stub: metadata-json-lint 4.3.0 ruby lib

Gem::Specification.new do |s|
  s.name = "metadata-json-lint".freeze
  s.version = "4.3.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Vox Pupuli".freeze]
  s.date = "1980-01-02"
  s.description = "Utility to verify Puppet metadata.json files".freeze
  s.email = "voxpupuli@groups.io".freeze
  s.executables = ["metadata-json-lint".freeze]
  s.files = ["bin/metadata-json-lint".freeze]
  s.homepage = "https://github.com/voxpupuli/metadata-json-lint".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.7.0".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "metadata-json-lint /path/to/metadata.json".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<json-schema>.freeze, [">= 2.8", "< 7.0"])
  s.add_runtime_dependency(%q<semantic_puppet>.freeze, ["~> 1.0"])
  s.add_runtime_dependency(%q<spdx-licenses>.freeze, ["~> 1.0"])
  s.add_development_dependency(%q<rake>.freeze, ["~> 13.0", ">= 13.0.6"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.12"])
  s.add_development_dependency(%q<voxpupuli-rubocop>.freeze, ["~> 3.1.0"])
end
