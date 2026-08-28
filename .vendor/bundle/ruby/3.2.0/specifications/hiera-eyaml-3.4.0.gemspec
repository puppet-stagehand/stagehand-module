# -*- encoding: utf-8 -*-
# stub: hiera-eyaml 3.4.0 ruby lib

Gem::Specification.new do |s|
  s.name = "hiera-eyaml".freeze
  s.version = "3.4.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Vox Pupuli".freeze]
  s.date = "2023-05-26"
  s.description = "Hiera backend for decrypting encrypted yaml properties".freeze
  s.email = "voxpupuli@groups.io".freeze
  s.executables = ["eyaml".freeze]
  s.files = ["bin/eyaml".freeze]
  s.homepage = "https://github.com/voxpupuli/hiera-eyaml/".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new([">= 2.5.0".freeze, "< 4".freeze])
  s.rubygems_version = "3.4.20".freeze
  s.summary = "OpenSSL Encryption backend for Hiera".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<optimist>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<highline>.freeze, [">= 0"])
end
