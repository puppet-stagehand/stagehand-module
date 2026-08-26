# frozen_string_literal: true

# Managed by modulesync - DO NOT EDIT
# https://voxpupuli.org/docs/updating-files-managed-with-modulesync/

# puppetlabs_spec_helper will set up coverage if the env variable is set.
# We want to do this if lib exists and it hasn't been explicitly set.
ENV['COVERAGE'] ||= 'yes' if Dir.exist?(File.expand_path('../lib', __dir__))

require 'voxpupuli/test/spec_helper'

module StagehandExplicitTestFacts
  TEST_PLATFORM_MATRIX = [
    {
      'operatingsystem' => 'Ubuntu',
      'operatingsystemrelease' => ['24.04'],
    },
    {
      'operatingsystem' => 'RedHat',
      'operatingsystemrelease' => ['9'],
    },
  ].freeze

  # Public support metadata is evidence-gated and intentionally empty until
  # all required live identities pass. Catalog specs still need deterministic
  # release-intent facts without turning test coverage into a support claim.
  def on_supported_os(opts = {})
    explicit = opts.dup
    explicit[:supported_os] = TEST_PLATFORM_MATRIX unless explicit.key?(:supported_os)
    super(explicit)
  end
end

RspecPuppetFacts.prepend(StagehandExplicitTestFacts)

RSpec.configure do |c|
  c.facterdb_string_keys = false
end

add_mocked_facts!

if File.exist?(File.join(__dir__, 'default_module_facts.yml'))
  facts = YAML.safe_load(File.read(File.join(__dir__, 'default_module_facts.yml')))
  facts&.each do |name, value|
    add_custom_fact name.to_sym, value
  end
end
Dir['./spec/support/spec/**/*.rb'].sort.each { |f| require f }
