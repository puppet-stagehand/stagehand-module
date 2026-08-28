# -*- encoding: utf-8 -*-
# stub: puppet_metadata 6.3.0 ruby lib

Gem::Specification.new do |s|
  s.name = "puppet_metadata".freeze
  s.version = "6.3.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Vox Pupuli".freeze, "Ewoud Kohl van Wijngaarden".freeze]
  s.date = "1980-01-02"
  s.description = "A package that provides abstractions for the Puppet Metadata".freeze
  s.email = ["voxpupuli@groups.io".freeze]
  s.executables = ["metadata2gha".freeze, "puppet-metadata".freeze, "setfiles".freeze, "update_eol_dates".freeze]
  s.extra_rdoc_files = ["README.md".freeze]
  s.files = ["README.md".freeze, "bin/metadata2gha".freeze, "bin/puppet-metadata".freeze, "bin/setfiles".freeze, "bin/update_eol_dates".freeze]
  s.homepage = "https://github.com/voxpupuli/puppet_metadata".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.rdoc_options = ["--main".freeze, "README.md".freeze]
  s.required_ruby_version = Gem::Requirement.new([">= 3.2".freeze, "< 5".freeze])
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Data structures for the Puppet Metadata".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<metadata-json-lint>.freeze, [">= 2.0", "< 6"])
  s.add_runtime_dependency(%q<semantic_puppet>.freeze, ["~> 1.0"])
  s.add_development_dependency(%q<rake>.freeze, ["~> 13.0"])
  s.add_development_dependency(%q<rdoc>.freeze, [">= 6.0", "< 9"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0"])
  s.add_development_dependency(%q<rspec-its>.freeze, [">= 1.0", "< 3"])
  s.add_development_dependency(%q<voxpupuli-rubocop>.freeze, ["~> 5.2.0"])
  s.add_development_dependency(%q<yard>.freeze, ["~> 0.9"])
end
