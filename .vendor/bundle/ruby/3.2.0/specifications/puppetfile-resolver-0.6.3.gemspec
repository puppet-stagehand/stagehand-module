# -*- encoding: utf-8 -*-
# stub: puppetfile-resolver 0.6.3 ruby lib

Gem::Specification.new do |s|
  s.name = "puppetfile-resolver".freeze
  s.version = "0.6.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Glenn Sarti".freeze]
  s.date = "2024-02-14"
  s.description = "Resolves the Puppet Modules in a Puppetfile with a full dependency graph, including Puppet version checks.".freeze
  s.email = ["glennsarti@users.noreply.github.com".freeze]
  s.homepage = "https://glennsarti.github.io/puppetfile-resolver/".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.5.3".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Dependency resolver for Puppetfiles".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<molinillo>.freeze, ["~> 0.6"])
  s.add_runtime_dependency(%q<semantic_puppet>.freeze, ["~> 1.0"])
  s.add_development_dependency(%q<webrick>.freeze, ["~> 1.8"])
end
