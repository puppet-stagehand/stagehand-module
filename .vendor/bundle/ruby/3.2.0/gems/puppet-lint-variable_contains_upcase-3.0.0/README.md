# Puppet lint check for upcase variables

[![License](https://img.shields.io/github/license/voxpupuli/puppet-lint-variable_contains_upcase.svg)](https://github.com/voxpupuli/puppet-lint-variable_contains_upcase/blob/master/LICENSE)
[![Test](https://github.com/voxpupuli/puppet-lint-variable_contains_upcase/actions/workflows/test.yml/badge.svg)](https://github.com/voxpupuli/puppet-lint-variable_contains_upcase/actions/workflows/test.yml)
[![Release](https://github.com/voxpupuli/puppet-lint-variable_contains_upcase/actions/workflows/release.yml/badge.svg)](https://github.com/voxpupuli/puppet-lint-variable_contains_upcase/actions/workflows/release.yml)
[![RubyGem Version](https://img.shields.io/gem/v/puppet-lint-variable_contains_upcase.svg)](https://rubygems.org/gems/puppet-lint-variable_contains_upcase)
[![RubyGem Downloads](https://img.shields.io/gem/dt/puppet-lint-variable_contains_upcase.svg)](https://rubygems.org/gems/puppet-lint-variable_contains_upcase)
[![Donated by Chris Spence](https://img.shields.io/badge/donated%20by-Chris%%20Spence-fb7047.svg)](#transfer-notice)

The future parser disallows mixed case variables, so this check implements
warnings for them

## Transfer Notice

This plugin was originally authored by [Chris Spence](https://github.com/fiddyspence).
The maintainer preferred that [Vox Pupuli](https://voxpupuli.org/) take ownership of the module for future improvement and maintenance.

## License

This gem is licensed under the MIT license.

## Release information

To make a new release, please do:
* Update the version in the `puppet-lint-variable_contains_upcase.gemspec` file
* Install gems with `bundle install --with release --path .vendor`
* generate the changelog with `bundle exec rake changelog`
* Create a PR with it
* After it got merged, push a tag. A github workflow will do the actual release
