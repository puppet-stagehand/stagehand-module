# -*- encoding: utf-8 -*-
# stub: bolt 4.0.0 ruby lib

Gem::Specification.new do |s|
  s.name = "bolt".freeze
  s.version = "4.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Puppet".freeze]
  s.bindir = "exe".freeze
  s.date = "2024-11-26"
  s.description = "Execute commands remotely over SSH and WinRM".freeze
  s.email = ["puppet@puppet.com".freeze]
  s.executables = ["bolt".freeze]
  s.files = ["exe/bolt".freeze]
  s.homepage = "https://github.com/puppetlabs/bolt".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.5".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Execute commands remotely over SSH and WinRM".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<addressable>.freeze, ["~> 2.5"])
  s.add_runtime_dependency(%q<aws-sdk-ec2>.freeze, ["~> 1"])
  s.add_runtime_dependency(%q<CFPropertyList>.freeze, [">= 2.2"])
  s.add_runtime_dependency(%q<concurrent-ruby>.freeze, ["~> 1.0"])
  s.add_runtime_dependency(%q<ffi>.freeze, [">= 1.9.25", "< 2.0.0"])
  s.add_runtime_dependency(%q<hiera-eyaml>.freeze, ["~> 3"])
  s.add_runtime_dependency(%q<jwt>.freeze, ["~> 2.2"])
  s.add_runtime_dependency(%q<logging>.freeze, ["~> 2.2"])
  s.add_runtime_dependency(%q<minitar>.freeze, ["~> 0.6"])
  s.add_runtime_dependency(%q<net-scp>.freeze, [">= 1.2", "< 5.0"])
  s.add_runtime_dependency(%q<net-ssh>.freeze, [">= 4.0", "< 8.0"])
  s.add_runtime_dependency(%q<net-ssh-krb>.freeze, ["~> 0.5"])
  s.add_runtime_dependency(%q<orchestrator_client>.freeze, ["~> 0.7"])
  s.add_runtime_dependency(%q<puppet>.freeze, [">= 6.18.0"])
  s.add_runtime_dependency(%q<puppetfile-resolver>.freeze, [">= 0.6.2", "< 1.0"])
  s.add_runtime_dependency(%q<puppet-resource_api>.freeze, [">= 1.8.1"])
  s.add_runtime_dependency(%q<puppet-strings>.freeze, [">= 2.3.0", "< 5.0"])
  s.add_runtime_dependency(%q<r10k>.freeze, [">= 3.10", "< 5"])
  s.add_runtime_dependency(%q<ruby_smb>.freeze, ["~> 1.0"])
  s.add_runtime_dependency(%q<terminal-table>.freeze, ["~> 3.0"])
  s.add_runtime_dependency(%q<winrm>.freeze, ["~> 2.0"])
  s.add_runtime_dependency(%q<winrm-fs>.freeze, ["~> 1.3"])
  s.add_development_dependency(%q<bundler>.freeze, [">= 1.14"])
  s.add_development_dependency(%q<octokit>.freeze, [">= 4.0", "< 9"])
  s.add_development_dependency(%q<puppetlabs_spec_helper>.freeze, [">= 5.0", "< 8"])
  s.add_development_dependency(%q<rake>.freeze, [">= 12.0", "< 14"])
  s.add_development_dependency(%q<rspec>.freeze, [">= 3.0", "< 4"])
end
