# puppet-lint-lookup\_in\_parameter-check

[![License](https://img.shields.io/github/license/voxpupuli/puppet-lint-lookup_in_parameter-check.svg)](https://github.com/voxpupuli/puppet-lint-lookup_in_parameter-check/blob/master/LICENSE)
[![Test](https://github.com/voxpupuli/puppet-lint-lookup_in_parameter-check/actions/workflows/test.yml/badge.svg)](https://github.com/voxpupuli/puppet-lint-lookup_in_parameter-check/actions/workflows/test.yml)
[![Release](https://github.com/voxpupuli/puppet-lint-lookup_in_parameter-check/actions/workflows/release.yml/badge.svg)](https://github.com/voxpupuli/puppet-lint-lookup_in_parameter-check/actions/workflows/release.yml)
[![RubyGem Version](https://img.shields.io/gem/v/puppet-lint-lookup_in_parameter-check.svg)](https://rubygems.org/gems/puppet-lint-lookup_in_parameter-check)
[![RubyGem Downloads](https://img.shields.io/gem/dt/puppet-lint-lookup_in_parameter-check.svg)](https://rubygems.org/gems/puppet-lint-lookup_in_parameter-check)
[![codecov](https://codecov.io/gh/voxpupuli/puppet-lint-lookup_in_parameter-check/branch/master/graph/badge.svg)](https://codecov.io/gh/voxpupuli/puppet-lint-lookup_in_parameter-check)

A puppet-lint plugin to check for calls to `lookup` in parameters.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'puppet-lint-lookup_in_parameter-check'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install puppet-lint-lookup_in_parameter-check

## Rationale

Usage of `lookup` for fetching the default value of a parameter is a smell that prevent a strict usage of the roles and profiles pattern.

Consider a module which has a main class (`acme`) class that install the software and a defined type (`acme::module`) that extend the configuration:

```yaml
---
acme::config_dir: '/etc/acme'
```

```puppet
# manifests/init.pp
class acme (
  Stdlib::Absolutepath $config_dir,
) {
  file { $config_dir:
    ensure => directory,
  }

  file { "${config_dir}/modules":
    ensure => directory,
  }
}

# manifests/module.pp
define acme::module (
  String[1] $config,
  Stdlib::Absolutepath $config_dir = lookup('acme::config_dir'),
) {
  file { "${config_dir}/modules/${title}":
    ensure  => file,
    content => $config,
  }
}
```

When configuring this module with a custom `config_dir`, one has to explicitely set this parameter all the time:

```puppet
class { 'acme':
  config_dir => '/opt/acme',
}

acme::module { 'foo':
  config     => $foo_config,
  config_dir => '/opt/acme', # If not set, `/etc/acme` from hiera would be used
}
```

A better way is to include the main class from the defined class and use the variable from the main class like so:

```puppet
# manifests/module.pp
define acme::module (
  String[1] $config,
) {
  include acme

  file { "${acme::config_dir}/modules/${title}":
    ensure  => file,
    content => $config,
  }
}
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/voxpupuli/puppet-lint-lookup_in_parameter-check. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/voxpupuli/puppet-lint-lookup_in_parameter-check/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the puppet-lint-lookup\_in\_parameter-check project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/voxpupuli/puppet-lint-lookup_in_parameter-check/blob/main/CODE_OF_CONDUCT.md).
