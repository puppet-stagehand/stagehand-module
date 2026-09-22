# frozen_string_literal: true

require 'spec_helper'

# Covers stagehand -- the inert anchor class -- and its manage_patching
# opt-in (999.12-03 D-01/D-02/D-03: the anchor class's only supported entry
# point for rolling the patchbot fact onto agents).
describe 'stagehand' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with manage_patching left at its default' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_class('stagehand::patching') }
      end

      context 'with manage_patching set true' do
        let(:params) { { 'manage_patching' => true } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('stagehand::patching') }
      end
    end
  end
end
