# -*- encoding: utf-8 -*-
# stub: beaker 7.7.0 ruby lib

Gem::Specification.new do |s|
  s.name = "beaker".freeze
  s.version = "7.7.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Puppet".freeze, "Vox Pupuli".freeze]
  s.date = "1980-01-02"
  s.description = "Puppet's accceptance testing harness".freeze
  s.email = ["voxpupuli@groups.io".freeze]
  s.executables = ["beaker".freeze]
  s.files = ["bin/beaker".freeze]
  s.homepage = "https://github.com/voxpupuli/beaker".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Let's test Puppet!".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<fakefs>.freeze, [">= 2.4", "< 4"])
  s.add_development_dependency(%q<rake>.freeze, ["~> 13.0"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0"])
  s.add_development_dependency(%q<rspec-github>.freeze, ["~> 3.0"])
  s.add_development_dependency(%q<voxpupuli-rubocop>.freeze, ["~> 5.2.0"])
  s.add_runtime_dependency(%q<base64>.freeze, [">= 0.2.0", "< 1"])
  s.add_runtime_dependency(%q<benchmark>.freeze, [">= 0.3", "< 0.6"])
  s.add_runtime_dependency(%q<minitar>.freeze, [">= 0.12", "< 2"])
  s.add_runtime_dependency(%q<minitest>.freeze, [">= 5.4", "< 7"])
  s.add_runtime_dependency(%q<rexml>.freeze, ["~> 3.2", ">= 3.2.5"])
  s.add_runtime_dependency(%q<readline>.freeze, ["~> 0.0.4"])
  s.add_runtime_dependency(%q<pstore>.freeze, ["< 1"])
  s.add_runtime_dependency(%q<logger>.freeze, ["< 2"])
  s.add_runtime_dependency(%q<bcrypt_pbkdf>.freeze, [">= 1.0", "< 2.0"])
  s.add_runtime_dependency(%q<ed25519>.freeze, [">= 1.2", "< 2.0"])
  s.add_runtime_dependency(%q<hocon>.freeze, ["~> 1.0"])
  s.add_runtime_dependency(%q<inifile>.freeze, ["~> 3.0"])
  s.add_runtime_dependency(%q<net-scp>.freeze, [">= 1.2", "< 5.0"])
  s.add_runtime_dependency(%q<net-ssh>.freeze, ["~> 7.1"])
  s.add_runtime_dependency(%q<in-parallel>.freeze, [">= 0.1", "< 2.0"])
  s.add_runtime_dependency(%q<rsync>.freeze, ["~> 1.0.9"])
  s.add_runtime_dependency(%q<thor>.freeze, [">= 1.0.1", "< 2.0"])
  s.add_runtime_dependency(%q<beaker-hostgenerator>.freeze, ["~> 3.0"])
  s.add_runtime_dependency(%q<stringify-hash>.freeze, ["~> 0.0"])
end
