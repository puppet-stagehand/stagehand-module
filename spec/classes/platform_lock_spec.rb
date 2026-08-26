require 'spec_helper'
require 'base64'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'

RSpec.describe 'stagehand::platform_lock' do
  let(:facts) do
    {
      'os' => { 'family' => 'Debian', 'name' => 'Ubuntu', 'release' => { 'major' => '24.04', 'full' => '24.04' } },
      'architecture' => 'amd64',
      'networking' => { 'fqdn' => 'core.example.test' },
    }
  end

  let(:agent_role) do
    {
      'role' => 'agent',
      'packages' => [{ 'name' => 'puppet-agent', 'evr' => '9.0.0-1noble' }],
      'runtime' => {},
    }
  end

  let(:server_role) do
    {
      'role' => 'puppet_server',
      'packages' => [
        { 'name' => 'puppet-agent', 'evr' => '9.0.0-1noble' },
        { 'name' => 'puppetdb-termini', 'evr' => '9.0.1-1noble' },
        { 'name' => 'puppetserver', 'evr' => '9.0.2-1noble' },
      ],
      'runtime' => { 'java_major' => 21, 'java_home' => '/usr/lib/jvm/java-21-openjdk-amd64' },
    }
  end

  let(:puppetdb_role) do
    {
      'role' => 'puppetdb',
      'packages' => [
        { 'name' => 'puppet-agent', 'evr' => '9.0.0-1noble' },
        { 'name' => 'puppetdb', 'evr' => '9.0.1-1noble' },
      ],
      'runtime' => {
        'java_major' => 17,
        'java_home' => '/usr/lib/jvm/java-17-openjdk-amd64',
        'postgresql_major' => 17,
      },
    }
  end

  let(:postgresql_role) do
    {
      'role' => 'postgresql',
      'packages' => [],
      'runtime' => { 'postgresql_major' => 17 },
    }
  end

  let(:params) do
    {
      'release_set_id' => 'puppet-core-9-v1',
      'puppet_track' => 9,
      'target_id' => 'core.example.test',
      'evidence_sha256' => 'fe62fe9d17c8aac17f0e1863f679d7d6d329b26272596a4e0451d3de1271aa33',
      'roles' => [agent_role],
      'write_manifest' => false,
    }
  end

  context 'role ownership on the apt adapter' do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_class('stagehand::platform_lock::apt') }
    it { is_expected.to contain_package('stagehand-platform-lock-puppet-agent').with(name: 'puppet-agent', ensure: '9.0.0-1noble') }
    it { is_expected.not_to contain_package('stagehand-platform-lock-puppetserver') }
    it { is_expected.not_to contain_package('stagehand-platform-lock-puppetdb') }
    it { is_expected.not_to contain_package('stagehand-platform-lock-puppetdb-termini') }

    context 'with one server role' do
      let(:params) { super().merge('roles' => [server_role]) }

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to contain_package('stagehand-platform-lock-puppet-agent') }
      it { is_expected.to contain_package('stagehand-platform-lock-puppetserver') }
      it { is_expected.to contain_package('stagehand-platform-lock-puppetdb-termini') }
      it { is_expected.not_to contain_package('stagehand-platform-lock-puppetdb') }
    end

    context 'with multiple co-located roles in reverse order' do
      let(:params) { super().merge('roles' => [puppetdb_role, server_role]) }

      it { is_expected.to compile.with_all_deps }
      it 'unions shared packages into one deterministic resource' do
        puppet_package_titles = %w[
          stagehand-platform-lock-puppet-agent
          stagehand-platform-lock-puppetdb
          stagehand-platform-lock-puppetdb-termini
          stagehand-platform-lock-puppetserver
        ]
        expect(catalogue.resources.select { |resource| resource.type == 'Package' && puppet_package_titles.include?(resource.title) }.map(&:title)).to eq(
          %w[
            stagehand-platform-lock-puppet-agent
            stagehand-platform-lock-puppetdb
            stagehand-platform-lock-puppetdb-termini
            stagehand-platform-lock-puppetserver
          ],
        )
      end
    end
  end

  context 'native adapter dispatch' do
    context 'on RedHat' do
      let(:facts) { super().merge('os' => { 'family' => 'RedHat', 'name' => 'RedHat', 'release' => { 'major' => '9', 'full' => '9.6' } }) }
      let(:params) do
        super().merge('roles' => [{ 'role' => 'agent', 'packages' => [{ 'name' => 'puppet-agent', 'evr' => '0:9.0.0-1.el9.x86_64' }], 'runtime' => {} }])
      end

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to contain_class('stagehand::platform_lock::rpm') }
      it { is_expected.to contain_file('/etc/dnf/plugins/versionlock.list').with_content(%r{puppet-agent-0:9\.0\.0-1\.el9\.x86_64}) }
    end

    context 'on SLES with an explicitly supplied fixture' do
      let(:facts) { super().merge('os' => { 'family' => 'Suse', 'name' => 'SLES', 'release' => { 'major' => '15', 'full' => '15.6' } }) }
      let(:params) { super().merge('roles' => [{ 'role' => 'agent', 'packages' => [{ 'name' => 'puppet-agent', 'evr' => '9.0.0-1.sles15' }], 'runtime' => {} }]) }

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to contain_class('stagehand::platform_lock::zypper') }
      it { is_expected.to contain_exec('stagehand-platform-lock-zypper-puppet-agent').with_unless(%r{zypper.*locks}) }
    end

    context 'on Windows with an immutable MSI fixture' do
      let(:facts) { super().merge('os' => { 'family' => 'windows', 'name' => 'windows', 'release' => { 'major' => '2022', 'full' => '2022' } }, 'architecture' => 'x64') }
      let(:params) do
        super().merge('roles' => [{
          'role' => 'agent',
          'packages' => [{
            'name' => 'puppet-agent',
            'evr' => '9.0.0',
            'source' => 'https://downloads.example.test/puppet-agent-9.0.0-x64.msi',
            'source_sha256' => '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          }],
          'runtime' => {},
        }])
      end

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to contain_class('stagehand::platform_lock::windows') }
      it { is_expected.to contain_package('stagehand-platform-lock-puppet-agent').with(ensure: '9.0.0', source: 'https://downloads.example.test/puppet-agent-9.0.0-x64.msi') }
    end
  end

  context 'idempotent native lock resources' do
    it { is_expected.to contain_exec('stagehand-platform-lock-apt-puppet-agent').with_unless('/usr/bin/apt-mark showhold | /bin/grep -Fqx -- puppet-agent') }
    it { is_expected.to contain_file('/etc/apt/preferences.d/stagehand-platform-lock').with(mode: '0644') }
  end

  context 'invalid role selections fail closed' do
    context 'with no roles' do
      let(:params) { super().merge('roles' => []) }
      it { is_expected.to compile.and_raise_error(%r{at least one role}) }
    end

    context 'with duplicate roles' do
      let(:params) { super().merge('roles' => [agent_role, agent_role]) }
      it { is_expected.to compile.and_raise_error(%r{duplicate role}) }
    end

    context 'with a role package exclusion violation' do
      let(:params) do
        super().merge('roles' => [{ 'role' => 'agent', 'packages' => [{ 'name' => 'puppetserver', 'evr' => '9.0.2-1noble' }], 'runtime' => {} }])
      end
      it { is_expected.to compile.and_raise_error(%r{package ownership}) }
    end

    context 'with an unsafe package identity' do
      let(:params) do
        super().merge('roles' => [{ 'role' => 'agent', 'packages' => [{ 'name' => 'puppet-agent;id', 'evr' => '9.0.0' }], 'runtime' => {} }])
      end
      it { is_expected.to compile.and_raise_error(%r{invalid package identity}) }
    end

    context 'on an unsupported OS family' do
      let(:facts) { super().merge('os' => { 'family' => 'Solaris', 'name' => 'Solaris', 'release' => { 'major' => '11', 'full' => '11.4' } }) }
      it { is_expected.to compile.and_raise_error(%r{unsupported OS family}) }
    end

    context 'with a Windows package lacking immutable source evidence' do
      let(:facts) { super().merge('os' => { 'family' => 'windows', 'name' => 'windows', 'release' => { 'major' => '2022', 'full' => '2022' } }) }
      it { is_expected.to compile.and_raise_error(%r{immutable MSI source}) }
    end
  end

  context 'service-specific Java guards' do
    let(:params) { super().merge('roles' => [server_role, puppetdb_role]) }

    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_package('stagehand-platform-lock-java-21').with_ensure('installed') }
    it { is_expected.to contain_package('stagehand-platform-lock-java-17').with_ensure('installed') }
    it { is_expected.to contain_file('/etc/systemd/system/puppetserver.service.d/20-stagehand-java.conf').with_content(%r{JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64}) }
    it { is_expected.to contain_file('/etc/systemd/system/puppetdb.service.d/20-stagehand-java.conf').with_content(%r{JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64}) }
    it { is_expected.to contain_exec('stagehand-platform-lock-restart-puppetserver').with(command: '/bin/systemctl try-restart puppetserver', refreshonly: true) }
    it { is_expected.to contain_exec('stagehand-platform-lock-restart-puppetdb').with(command: '/bin/systemctl try-restart puppetdb', refreshonly: true) }

    context 'with an unsafe JAVA_HOME' do
      let(:params) do
        unsafe = server_role.merge('runtime' => server_role['runtime'].merge('java_home' => '/tmp/java-21'))
        super().merge('roles' => [unsafe])
      end
      it { is_expected.to compile.and_raise_error(%r{invalid JAVA_HOME}) }
    end
  end

  context 'PostgreSQL major-family and pg_trgm evidence' do
    let(:params) { super().merge('roles' => [postgresql_role]) }

    it { is_expected.to contain_package('stagehand-platform-lock-postgresql-server').with(name: 'postgresql-17', ensure: 'installed') }
    it { is_expected.to contain_package('stagehand-platform-lock-postgresql-client').with(name: 'postgresql-client-17', ensure: 'installed') }
    it { is_expected.not_to contain_package('stagehand-platform-lock-postgresql-contrib') }
    it do
      is_expected.to contain_exec('stagehand-platform-lock-observe-pg-trgm-extension').with(
        command: %r{/usr/sbin/runuser -u postgres -- /usr/bin/psql .*--dbname postgres},
      )
    end

    context 'with the adjacent supported major' do
      let(:params) do
        role = postgresql_role.merge('runtime' => { 'postgresql_major' => 16 })
        super().merge('roles' => [role])
      end
      it { is_expected.to contain_package('stagehand-platform-lock-postgresql-server').with(name: 'postgresql-16', ensure: 'installed') }
    end

    context 'with an invalid PostgreSQL major' do
      let(:params) do
        role = postgresql_role.merge('runtime' => { 'postgresql_major' => 18 })
        super().merge('roles' => [role])
      end
      it { is_expected.to compile.and_raise_error(%r{unsupported PostgreSQL major}) }
    end
  end

  context 'target-derived observation wiring' do
    let(:params) do
      super().merge(
        'write_manifest' => true,
        'target_id' => 'core.example.test',
        'evidence_sha256' => 'fe62fe9d17c8aac17f0e1863f679d7d6d329b26272596a4e0451d3de1271aa33',
      )
    end

    it { is_expected.to contain_class('stagehand::platform_lock::observe') }
    it { is_expected.to contain_file('/usr/local/sbin/stagehand-platform-lock-observe').with(owner: 'root', group: 'root', mode: '0700') }
    it { is_expected.to contain_file('/var/lib/stagehand/platform-lock').with(owner: 'root', group: 'root', mode: '0700') }
    it { is_expected.to contain_exec('stagehand-platform-lock-observe').with(command: '/usr/local/sbin/stagehand-platform-lock-observe') }

    it 'bakes immutable desired identity into the root-owned collector' do
      helper = catalogue.resource('File', '/usr/local/sbin/stagehand-platform-lock-observe')[:content]
      encoded = helper[/strict_decode64\('([^']+)'\)/, 1]
      desired = Base64.strict_decode64(encoded)
      expect(desired).to include('core.example.test')
      expect(desired).to include('fe62fe9d17c8aac17f0e1863f679d7d6d329b26272596a4e0451d3de1271aa33')
      expect(helper).to include('desired_generation_sha256')
      expect(helper).not_to include('ARGV')
    end

    context 'with a caller-supplied observation' do
      let(:params) { super().merge('observed' => { 'status' => 'verified' }) }

      it { is_expected.to compile.and_raise_error(%r{(?:expects no argument named|has no parameter named) 'observed'}) }
    end

    it 'orders collection after native package convergence' do
      relationship = catalogue.resource('Exec', 'stagehand-platform-lock-observe')[:require].map(&:to_s)
      expect(relationship).to include('Package[stagehand-platform-lock-puppet-agent]')
    end
  end
end
