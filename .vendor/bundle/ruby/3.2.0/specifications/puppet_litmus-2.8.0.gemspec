# -*- encoding: utf-8 -*-
# stub: puppet_litmus 2.8.0 ruby lib

Gem::Specification.new do |s|
  s.name = "puppet_litmus".freeze
  s.version = "2.8.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Puppet, Inc.".freeze]
  s.bindir = "exe".freeze
  s.date = "2026-08-18"
  s.description = "    Providing a simple command line tool for puppet content creators, to enable simple and complex test deployments.\n".freeze
  s.email = ["info@puppet.com".freeze]
  s.executables = ["matrix.json".freeze, "matrix_from_metadata_v2".freeze, "matrix_from_metadata_v3".freeze]
  s.files = ["exe/matrix.json".freeze, "exe/matrix_from_metadata_v2".freeze, "exe/matrix_from_metadata_v3".freeze]
  s.homepage = "https://github.com/puppetlabs/puppet_litmus".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.1.0".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Providing a simple command line tool for puppet content creators, to enable simple and complex test deployments.".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<bolt>.freeze, [">= 4.0", "< 6.0"])
  s.add_runtime_dependency(%q<docker-api>.freeze, [">= 1.34", "< 3.0.0"])
  s.add_runtime_dependency(%q<parallel>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<puppet-modulebuilder>.freeze, [">= 0.3.0"])
  s.add_runtime_dependency(%q<retryable>.freeze, ["~> 3.0"])
  s.add_runtime_dependency(%q<rspec>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<tty-spinner>.freeze, [">= 0.5.0", "< 1.0.0"])
end
