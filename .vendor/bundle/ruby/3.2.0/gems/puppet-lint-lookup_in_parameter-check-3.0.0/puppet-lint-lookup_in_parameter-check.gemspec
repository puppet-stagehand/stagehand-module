# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'puppet-lint-lookup_in_parameter-check'
  spec.version       = '3.0.0'
  spec.authors       = ['Romain Tartière', 'Vox Pupuli']
  spec.email         = ['voxpupuli@groups.io']

  spec.summary       = 'Check lookup is not used in parameters'
  spec.homepage      = 'https://github.com/voxpupuli/puppet-lint-lookup_in_parameter-check'
  spec.license       = 'MIT'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 3.2'

  spec.add_dependency 'puppet-lint', '~> 5.1'
end
