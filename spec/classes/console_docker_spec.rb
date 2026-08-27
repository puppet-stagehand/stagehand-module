# frozen_string_literal: true

require 'spec_helper'

# Covers stagehand::console::docker -- the container-lifecycle sibling of
# stagehand::console (see console_spec.rb).
describe 'stagehand::console::docker' do
  let(:valid_image_ref) do
    "ghcr.io/puppet-stagehand/console@sha256:#{'a' * 64}"
  end

  let(:required_params) do
    {
      'image_ref' => valid_image_ref,
      'db_password' => sensitive('s3cr3t-db-password'),
      'ingest_token' => sensitive('s3cr3t-ingest-token'),
      'dataservice_token' => sensitive('s3cr3t-dataservice-token'),
    }
  end

  # Task 2: proves puppetlabs/docker's undeclared RedHat-family/Ubuntu
  # 24.04/Debian 12 support gap (999.1-RESEARCH.md Standard Stack /
  # Assumption A4) does not break catalog compilation in practice --
  # compiled against every one of stagehand's own declared supported OS
  # releases (on_supported_os), not a single representative fact set.
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context "with ensure => 'present' (default)" do
        let(:params) { required_params }

        it { is_expected.to compile.with_all_deps }

        it { is_expected.to contain_class('stagehand::console::docker') }

        it { is_expected.to contain_class('docker') }

        it {
          is_expected.to contain_docker__image('stagehand-console').with(
            image: 'ghcr.io/puppet-stagehand/console',
            image_digest: "sha256:#{'a' * 64}",
          )
        }

        it {
          is_expected.to contain_docker__run('stagehand-console').with(
            image: valid_image_ref,
            verify_digest: "sha256:#{'a' * 64}",
            ensure: 'present',
          ).that_requires('Docker::Image[stagehand-console]')
        }

        # Console must stay externally reachable -- published on all
        # interfaces, no host-IP prefix on the port mapping.
        it {
          is_expected.to contain_docker__run('stagehand-console').with(
            ports: ['8443:8443'],
          )
        }

        it {
          is_expected.to contain_docker__image('stagehand-postgres').with(
            image: 'postgres',
            image_tag: '16',
          )
        }

        # Postgres must NEVER bind to a wildcard interface (T-999.1-04).
        it {
          is_expected.to contain_docker__run('stagehand-postgres').with(
            ports: ['127.0.0.1:5432:5432'],
            ensure: 'present',
          ).that_requires('Docker::Image[stagehand-postgres]')
        }

        it {
          is_expected.to contain_docker_volume('stagehand-postgres-data').with_ensure('present')
        }

        it {
          is_expected.to contain_file('/var/backups/stagehand-console').with_ensure('directory')
        }

        it {
          is_expected.to contain_exec('stagehand::console::docker::pg_snapshot').that_comes_before('Docker::Run[stagehand-console]')
        }

        it 'passes Postgres credentials to the pg_snapshot Exec via environment, never argv' do
          resource = catalogue.resource('Exec', 'stagehand::console::docker::pg_snapshot')
          expect(resource[:environment]).to include('PGPASSWORD=s3cr3t-db-password')
          expect(resource[:command]).not_to include('s3cr3t-db-password')
          expect(resource[:onlyif]).not_to include('s3cr3t-db-password')
        end

        it 'guards the pg_snapshot Exec with a digest-comparison onlyif referencing $image_ref' do
          resource = catalogue.resource('Exec', 'stagehand::console::docker::pg_snapshot')
          expect(resource[:onlyif]).to include(valid_image_ref)
        end

        # OS-family pg_dump-client package resolution: 'postgresql-client'
        # on Debian, 'postgresql' on RedHat family (covers RedHat/Rocky/
        # AlmaLinux). Declared exactly once regardless of topology branch.
        it 'resolves the correct pg_dump-client package name for this OS family' do
          expected_package = (os_facts[:os]['family'] == 'RedHat') ? 'postgresql' : 'postgresql-client'
          is_expected.to contain_package(expected_package)
        end
      end
    end
  end

  context 'with a malformed image_ref (no digest suffix)' do
    let(:facts) { on_supported_os.first[1] }
    let(:params) { required_params.merge('image_ref' => 'ghcr.io/puppet-stagehand/console:latest') }

    it 'fails to compile' do
      expect { catalogue }.to raise_error(Puppet::Error, %r{image_ref})
    end
  end

  context 'with a malformed image_ref (non-hex digest)' do
    let(:facts) { on_supported_os.first[1] }
    let(:params) { required_params.merge('image_ref' => "ghcr.io/puppet-stagehand/console@sha256:#{'z' * 64}") }

    it 'fails to compile' do
      expect { catalogue }.to raise_error(Puppet::Error, %r{image_ref})
    end
  end

  context 'with a malformed image_ref (short digest)' do
    let(:facts) { on_supported_os.first[1] }
    let(:params) { required_params.merge('image_ref' => "ghcr.io/puppet-stagehand/console@sha256:#{'a' * 10}") }

    it 'fails to compile' do
      expect { catalogue }.to raise_error(Puppet::Error, %r{image_ref})
    end
  end

  context "with ensure => 'absent'" do
    let(:facts) { on_supported_os.first[1] }
    let(:params) { required_params.merge('ensure' => 'absent') }

    it { is_expected.to compile.with_all_deps }

    # Removal path: this class stops declaring the console container
    # entirely (a disclosed limitation, see docker.pp's doc-comment) --
    # NOT the same as declaring it with ensure => absent.
    it { is_expected.not_to contain_docker__run('stagehand-console') }
    it { is_expected.not_to contain_docker__image('stagehand-console') }
    it { is_expected.not_to contain_docker__run('stagehand-postgres') }
    it { is_expected.not_to contain_exec('stagehand::console::docker::pg_snapshot') }

    it 'leaves the Postgres data volume present when purge_data is false (default)' do
      is_expected.to contain_docker_volume('stagehand-postgres-data').with_ensure('present')
    end
  end

  context "with ensure => 'absent', purge_data => true" do
    let(:facts) { on_supported_os.first[1] }
    let(:params) { required_params.merge('ensure' => 'absent', 'purge_data' => true) }

    it { is_expected.to compile.with_all_deps }

    it {
      is_expected.to contain_docker_volume('stagehand-postgres-data').with_ensure('absent')
    }
  end

  # docker::run itself references $docker::service_name (the main `docker`
  # class's own variable), so SOME declaration of `class { 'docker': }` must
  # be in scope regardless of $manage_docker_engine -- this class's own
  # unconditional `include docker` is what $manage_docker_engine gates, not
  # docker::run's hard dependency on the class being declared at all. A
  # `pre_condition` stands in for "the operator's own external
  # classification already includes docker" (mirrors stagehand::console's
  # own "Postgres server assumed already present" convention).
  context 'with manage_docker_engine => false (engine managed elsewhere)' do
    let(:facts) { on_supported_os.first[1] }
    let(:pre_condition) { 'include docker' }
    let(:params) { required_params.merge('manage_docker_engine' => false) }

    it { is_expected.to compile.with_all_deps }
  end
end
