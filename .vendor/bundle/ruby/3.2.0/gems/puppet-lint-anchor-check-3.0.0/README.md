puppet-lint-anchor-check
========================

[![License](https://img.shields.io/github/license/voxpupuli/puppet-lint-anchor-check.svg)](https://github.com/voxpupuli/puppet-lint-anchor-check/blob/master/LICENSE)
[![Test](https://github.com/voxpupuli/puppet-lint-anchor-check/actions/workflows/test.yml/badge.svg)](https://github.com/voxpupuli/puppet-lint-anchor-check/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/voxpupuli/puppet-lint-anchor-check/branch/master/graph/badge.svg?token=Mypkl78hvK)](https://codecov.io/gh/voxpupuli/puppet-lint-anchor-check)
[![Release](https://github.com/voxpupuli/puppet-lint-anchor-check/actions/workflows/release.yml/badge.svg)](https://github.com/voxpupuli/puppet-lint-anchor-check/actions/workflows/release.yml)
[![RubyGem Version](https://img.shields.io/gem/v/puppet-lint-anchor-check.svg)](https://rubygems.org/gems/puppet-lint-anchor-check)
[![RubyGem Downloads](https://img.shields.io/gem/dt/puppet-lint-anchor-check.svg)](https://rubygems.org/gems/puppet-lint-anchor-check)
[![Donated by Alexander Fisher](https://img.shields.io/badge/donated%20by-Alexander%20Fisher-fb7047.svg)](#copyright)

A puppet-lint plugin to check that `anchor` resources are unused.

## Installing

### From the command line

```shell
$ gem install puppet-lint-anchor-check
```

### In a Gemfile

```ruby
gem 'puppet-lint-anchor-check', :require => false
```

## Checks

### anchor resource use

The anchor pattern should be replaced with the `contain` function.

#### What you have done

```puppet
anchor { 'foo::begin': }
-> class { 'foo::install': }
-> class { 'foo::config': }
~> class { 'foo::service': }
-> anchor { 'foo::end': }
```

#### What you should have done

```puppet
contain 'foo::install'
contain 'foo::config'
contain 'foo::service'

Class['foo::install']
-> Class['foo::config']
~> Class['foo::service']
```

# Copyright

Copyright 2017 Alexander Fisher

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

## Release information

To make a new release, please do:
* update the version in the gemspec file
* Install gems with `bundle install --with release --path .vendor`
* generate the changelog with `bundle exec rake changelog`
* Check if the new version matches the closed issues/PRs in the changelog
* Create a PR with it
* After it got merged, push a tag. GitHub actions will do the actual release to rubygems and GitHub Packages
