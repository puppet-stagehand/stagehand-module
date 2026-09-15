# frozen_string_literal: true

require 'spec_helper'

# Covers stagehand::console::k3s -- the manifests-directory-rendering
# sibling of stagehand::console::docker (see console_docker_spec.rb).
# No hand-rolled Exec, no Kubernetes/Helm CLI invocation anywhere: this
# class's entire job is rendering Hiera-supplied values into two `file`
# resources that k3s's own helm-controller reconciles.
describe 'stagehand::console::k3s' do
  let(:required_params) do
    {
      'sizing_tier' => 'small',
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context "with ensure => 'present' (default)" do
        let(:params) { required_params }

        it { is_expected.to compile.with_all_deps }

        it { is_expected.to contain_class('stagehand::console::k3s') }

        it {
          is_expected.to contain_file('/var/lib/rancher/k3s/server/manifests/stagehand-zot.yaml')
            .with_ensure('file')
            .with_owner('root')
            .with_group('root')
            .with_mode('0644')
        }

        it {
          is_expected.to contain_file('/var/lib/rancher/k3s/server/manifests/stagehand-zot.yaml')
            .with_content(%r{0\.1\.124})
            .with_content(%r{v2\.1\.21})
        }

        it {
          is_expected.to contain_file('/var/lib/rancher/k3s/server/manifests/stagehand-zot-networkpolicy.yaml')
            .with_ensure('file')
            .with_owner('root')
            .with_group('root')
            .with_mode('0644')
        }

        it {
          is_expected.to contain_file('/var/lib/rancher/k3s/server/manifests/stagehand-zot-networkpolicy.yaml')
            .with_content(%r{Ingress})
        }

        it 'declares no Exec resource for the apply loop' do
          catalogue.resources.each do |resource|
            expect(resource.type).not_to eq('Exec')
          end
        end
      end

      context 'with a non-default manifests_dir' do
        let(:params) { required_params.merge('manifests_dir' => '/opt/stagehand-lab-manifests') }

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_file('/opt/stagehand-lab-manifests/stagehand-zot.yaml')
        }

        it {
          is_expected.to contain_file('/opt/stagehand-lab-manifests/stagehand-zot-networkpolicy.yaml')
        }

        it {
          is_expected.not_to contain_file('/var/lib/rancher/k3s/server/manifests/stagehand-zot.yaml')
        }
      end

      context "with ensure => 'absent'" do
        let(:params) { required_params.merge('ensure' => 'absent') }

        it { is_expected.to compile.with_all_deps }

        # Removal path: this class stops declaring the rendered files
        # entirely (a disclosed limitation, see k3s.pp's doc-comment) --
        # it does not retract already-applied k8s resources.
        it { is_expected.not_to contain_file('/var/lib/rancher/k3s/server/manifests/stagehand-zot.yaml') }
        it { is_expected.not_to contain_file('/var/lib/rancher/k3s/server/manifests/stagehand-zot-networkpolicy.yaml') }
      end
    end
  end

  context 'with an out-of-enum sizing_tier' do
    let(:facts) { on_supported_os.first[1] }
    let(:params) { required_params.merge('sizing_tier' => 'enormous') }

    it 'fails to compile' do
      expect { catalogue }.to raise_error(Puppet::Error, %r{sizing_tier})
    end
  end

  context 'with a relative manifests_dir' do
    let(:facts) { on_supported_os.first[1] }
    let(:params) { required_params.merge('manifests_dir' => 'relative/path') }

    it 'fails to compile' do
      expect { catalogue }.to raise_error(Puppet::Error)
    end
  end

  context 'with manage_k3s => true (unimplemented escape hatch)' do
    let(:facts) { on_supported_os.first[1] }
    let(:params) { required_params.merge('manage_k3s' => true) }

    it 'fails to compile with a message naming the deliberate omission' do
      expect { catalogue }.to raise_error(Puppet::Error, %r{k3s installation is deliberately unimplemented})
    end
  end
end
