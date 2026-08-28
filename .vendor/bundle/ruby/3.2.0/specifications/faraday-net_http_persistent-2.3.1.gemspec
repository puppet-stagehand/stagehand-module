# -*- encoding: utf-8 -*-
# stub: faraday-net_http_persistent 2.3.1 ruby lib

Gem::Specification.new do |s|
  s.name = "faraday-net_http_persistent".freeze
  s.version = "2.3.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://github.com/lostisland/faraday-net_http_persistent/releases/tag/v2.3.1", "homepage_uri" => "https://github.com/lostisland/faraday-net_http_persistent", "source_code_uri" => "https://github.com/lostisland/faraday-net_http_persistent" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Mike Rogers".freeze]
  s.date = "1980-01-02"
  s.description = "Faraday adapter for NetHttpPersistent".freeze
  s.email = ["me@mikerogers.io".freeze]
  s.homepage = "https://github.com/lostisland/faraday-net_http_persistent".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.6.0".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Faraday adapter for NetHttpPersistent".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<faraday>.freeze, ["~> 2.5"])
  s.add_runtime_dependency(%q<net-http-persistent>.freeze, [">= 4.0.4", "< 5"])
end
