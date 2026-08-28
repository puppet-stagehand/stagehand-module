# -*- encoding: utf-8 -*-
# stub: puppet-blacksmith 9.1.0 ruby lib

Gem::Specification.new do |s|
  s.name = "puppet-blacksmith".freeze
  s.version = "9.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["MaestroDev".freeze, "Vox Pupuli".freeze]
  s.date = "1980-01-02"
  s.description = "Puppet module tools for development and Puppet Forge management".freeze
  s.email = ["voxpupuli@groups.io".freeze]
  s.homepage = "http://github.com/voxpupuli/puppet-blacksmith".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new([">= 3.2.0".freeze, "< 5".freeze])
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Tasks to manage Puppet module builds".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<base64>.freeze, [">= 0.2", "< 0.4"])
  s.add_runtime_dependency(%q<puppet-modulebuilder>.freeze, ["~> 2.0", ">= 2.0.2"])
  s.add_development_dependency(%q<aruba>.freeze, ["~> 2.1"])
  s.add_development_dependency(%q<cucumber>.freeze, [">= 9", "< 11"])
  s.add_development_dependency(%q<rake>.freeze, ["~> 13.0", ">= 13.0.6"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.12"])
  s.add_development_dependency(%q<voxpupuli-rubocop>.freeze, ["~> 5.1.0"])
  s.add_development_dependency(%q<webmock>.freeze, [">= 2.0", "< 4"])
end
