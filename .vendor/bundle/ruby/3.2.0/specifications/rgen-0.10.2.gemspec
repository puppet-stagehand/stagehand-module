# -*- encoding: utf-8 -*-
# stub: rgen 0.10.2 ruby lib

Gem::Specification.new do |s|
  s.name = "rgen".freeze
  s.version = "0.10.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Martin Thiede".freeze]
  s.date = "2023-12-13"
  s.description = "RGen is a framework for Model Driven Software Development (MDSD) in Ruby. This means that it helps you build Metamodels, instantiate Models, modify and transform Models and finally generate arbitrary textual content from it.".freeze
  s.extra_rdoc_files = ["README.rdoc".freeze, "CHANGELOG".freeze, "MIT-LICENSE".freeze]
  s.files = ["CHANGELOG".freeze, "MIT-LICENSE".freeze, "README.rdoc".freeze]
  s.homepage = "http://ruby-gen.org".freeze
  s.rdoc_options = ["--main".freeze, "README.rdoc".freeze, "-x".freeze, "test".freeze, "-x".freeze, "metamodels".freeze, "-x".freeze, "ea_support/uml13*".freeze]
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Ruby Modelling and Generator Framework".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<nokogiri>.freeze, [">= 1.15.4", "< 1.16"])
  s.add_development_dependency(%q<rake>.freeze, [">= 13.0.0", "< 14.0"])
  s.add_development_dependency(%q<minitest>.freeze, [">= 5.20.0", "< 6.0"])
  s.add_development_dependency(%q<minitest-fail-fast>.freeze, [">= 0.1.0", "< 0.2"])
  s.add_development_dependency(%q<andand>.freeze, [">= 1.3.3", "< 1.4"])
end
