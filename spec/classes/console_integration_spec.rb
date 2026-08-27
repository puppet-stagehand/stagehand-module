# frozen_string_literal: true

require 'spec_helper'

describe 'stagehand::console_integration' do
  let(:params) do
    {
      'console_url' => 'https://console.example.test',
      'token'       => sensitive('test-token'),
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it 'manages the OpenSSH server package by default' do
        is_expected.to contain_package('openssh-server').with_ensure('installed')
      end

      context 'when SSH server management is disabled' do
        let(:params) { super().merge('manage_ssh_server' => false) }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_package('openssh-server') }
      end
    end
  end
end
