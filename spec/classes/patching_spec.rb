# frozen_string_literal: true

require 'spec_helper'

# Covers stagehand::patching -- the opt-in class that rolls the patchbot
# external fact onto agents and keeps its inputs fresh (999.12-03 D-03 port
# from adapters/stagehand/manifests/patching.pp, verbatim).
describe 'stagehand::patching' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }
    end
  end
end
