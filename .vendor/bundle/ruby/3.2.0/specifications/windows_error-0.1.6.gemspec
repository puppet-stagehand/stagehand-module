# -*- encoding: utf-8 -*-
# stub: windows_error 0.1.6 ruby lib

Gem::Specification.new do |s|
  s.name = "windows_error".freeze
  s.version = "0.1.6"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["David Maloney".freeze]
  s.date = "2026-07-09"
  s.description = "The WindowsError gem provides an easily accessible reference for\n                          standard Windows API Error Codes. It allows you to do comparisons\n                          as well as direct lookups of error codes to translate the numerical\n                          value returned by the API, into a meaningful and human readable message.".freeze
  s.email = ["DMaloney@rapid7.com".freeze]
  s.homepage = "https://github.com/rapid7/windows_error".freeze
  s.licenses = ["BSD".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.2.0".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Provides a way to look up Windows NTSTATUS and Win32 Error Codes".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<bundler>.freeze, [">= 0"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<yard>.freeze, [">= 0"])
  s.add_development_dependency(%q<fivemat>.freeze, [">= 0"])
end
