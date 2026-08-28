# -*- encoding: utf-8 -*-
# stub: net-ssh-krb 0.5.1 ruby lib

Gem::Specification.new do |s|
  s.name = "net-ssh-krb".freeze
  s.version = "0.5.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Joe Khoobyar".freeze, "Chris Beer".freeze]
  s.date = "2020-02-05"
  s.description = "Extends Net::SSH by adding Kerberos authentication capability for password-less logins on multiple platforms.\n".freeze
  s.email = "joe@ankhcraft.com cabeer@stanford.edu".freeze
  s.extra_rdoc_files = ["LICENSE".freeze, "README.md".freeze]
  s.files = ["LICENSE".freeze, "README.md".freeze]
  s.homepage = "http://github.com/cbeer/net-ssh-kerberos".freeze
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Add Kerberos support to Net::SSH".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<net-ssh>.freeze, [">= 2.0"])
  s.add_runtime_dependency(%q<gssapi>.freeze, ["~> 1.3.0"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0"])
end
