require 'spec_helper'

describe 'anchor_resource' do
  let(:msg) { 'manifest includes anchor resource' }

  context 'stdlib ntp example' do
    let(:code) do
      <<~CODE
        class ntp {
          # These classes will have the correct order relationship with each
          # other. However, without anchors, they won't have any order
          # relationship to Class['ntp'].
          class { 'ntp::package': }
          -> class { 'ntp::config': }
          -> class { 'ntp::service': }

          # These two resources "anchor" the composed classes within the ntp
          # class.
          anchor { 'ntp::begin': } -> Class['ntp::package']
          Class['ntp::service']    -> anchor { 'ntp::end': }
        }
      CODE
    end

    it 'creates two warnings' do
      expect(problems).to have(2).problems
    end

    it { expect(problems).to contain_warning(msg).on_line(11).in_column(3) }
    it { expect(problems).to contain_warning(msg).on_line(12).in_column(31) }
  end
end
