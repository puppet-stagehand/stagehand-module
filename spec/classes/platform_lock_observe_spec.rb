require 'spec_helper'
require 'base64'
require 'digest'
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
  let(:params) do
    {
      'release_set_id' => 'puppet-core-9-v1',
      'puppet_track' => 9,
      'target_id' => 'core.example.test',
      'evidence_sha256' => 'fe62fe9d17c8aac17f0e1863f679d7d6d329b26272596a4e0451d3de1271aa33',
      'roles' => [
        {
          'role' => 'puppet_server',
          'packages' => [
            { 'name' => 'puppet-agent', 'evr' => '9.0.0-1noble' },
            { 'name' => 'puppetdb-termini', 'evr' => '9.0.1-1noble' },
            { 'name' => 'puppetserver', 'evr' => '9.0.2-1noble' },
          ],
          'runtime' => { 'java_major' => 21, 'java_home' => '/usr/lib/jvm/java-21-openjdk-amd64' },
        },
        {
          'role' => 'puppetdb',
          'packages' => [
            { 'name' => 'puppet-agent', 'evr' => '9.0.0-1noble' },
            { 'name' => 'puppetdb', 'evr' => '9.0.1-1noble' },
          ],
          'runtime' => { 'java_major' => 17, 'java_home' => '/usr/lib/jvm/java-17-openjdk-amd64', 'postgresql_major' => 17 },
        },
        { 'role' => 'postgresql', 'packages' => [], 'runtime' => { 'postgresql_major' => 17 } },
      ],
    }
  end

  def helper_content
    catalogue.resource('File', '/usr/local/sbin/stagehand-platform-lock-observe')[:content]
  end

  def canonical(value)
    case value
    when Hash then value.keys.sort.to_h { |key| [key, canonical(value.fetch(key))] }
    when Array then value.map { |item| canonical(item) }
    else value
    end
  end

  def desired_document
    encoded = helper_content[/Base64\.strict_decode64\('([A-Za-z0-9+\/=]+)'\)/, 1]
    JSON.parse(Base64.strict_decode64(encoded))
  end

  def collector_for(desired, recompute: true)
    document = desired_document
    document['desired'] = Marshal.load(Marshal.dump(desired))
    projection = document.fetch('desired').reject { |key, _value| key == 'desired_generation_sha256' }
    document['desired']['desired_generation_sha256'] = Digest::SHA256.hexdigest(JSON.generate(canonical(projection))) if recompute
    encoded = Base64.strict_encode64(JSON.generate(document))
    helper_content.sub(/(?<=Base64\.strict_decode64\(')[A-Za-z0-9+\/=]+/, encoded)
  end

  def run_collector(root, fixture, content: helper_content, raw_fixture: nil)
    root = File.realpath(root)
    script = File.join(root, 'observe.rb')
    fixture_path = File.join(root, 'fixture.json')
    File.write(script, content)
    File.write(fixture_path, raw_fixture || JSON.generate(fixture)) if fixture || raw_fixture
    env = {
      'STAGEHAND_PLATFORM_LOCK_TESTING' => '1',
      'STAGEHAND_PLATFORM_LOCK_ROOT' => root,
    }
    env['STAGEHAND_PLATFORM_LOCK_FIXTURE'] = fixture_path if fixture || raw_fixture
    Open3.capture3(
      env,
      RbConfig.ruby,
      script,
    )
  end

  let(:complete_fixture) do
    {
      'healthy' => true,
      'repository_track' => 9,
      'packages' => {
        'puppet-agent' => '9.0.0-1noble',
        'puppetdb' => '9.0.1-1noble',
        'puppetdb-termini' => '9.0.1-1noble',
        'puppetserver' => '9.0.2-1noble',
      },
      'native_lock_output' => "puppet-agent\npuppetdb\npuppetdb-termini\npuppetserver\n",
      'java' => {
        'puppet_server' => { 'path' => '/usr/lib/jvm/java-21-openjdk-amd64', 'major' => 21 },
        'puppetdb' => { 'path' => '/usr/lib/jvm/java-17-openjdk-amd64', 'major' => 17 },
      },
      'postgresql' => {
        'packages' => {
          'postgresql-17' => '17.5-1',
          'postgresql-client-17' => '17.5-1',
          'postgresql-contrib-17' => '17.5-1',
        },
        'pg_trgm_extversion' => '1.6',
      },
    }
  end

  def rpm_agent_desired(package_name = 'puppetdb', evr = '0:9.0.1-1.el9.noarch')
    base = desired_document.fetch('desired')
    role = { 'role' => 'agent', 'packages' => [{ 'name' => package_name, 'evr' => evr }], 'runtime' => {} }
    base.merge('roles' => [role], 'os' => base.fetch('os').merge('family' => 'redhat', 'architecture' => 'x86_64'))
  end

  def rpm_fixture(package_name = 'puppetdb', evr = '0:9.0.1-1.el9.noarch', output:)
    {
      'healthy' => true,
      'repository_track' => 9,
      'packages' => { package_name => evr },
      'native_lock_output' => output,
    }
  end

  def sles_agent_desired(package_name = 'puppetdb', evr = '0:9.0.1-1.sles15.noarch')
    base = desired_document.fetch('desired')
    role = { 'role' => 'agent', 'packages' => [{ 'name' => package_name, 'evr' => evr }], 'runtime' => {} }
    base.merge('roles' => [role], 'os' => base.fetch('os').merge('family' => 'sles', 'architecture' => 'x86_64'))
  end

  it 'requires one exact complete DNF identity for each desired package' do
    desired = rpm_agent_desired
    exact = 'puppetdb-0:9.0.1-1.el9.noarch'
    failures = {
      'termini-only' => 'puppetdb-termini-0:9.0.1-1.el9.noarch',
      'prefix-only' => 'my-puppetdb-0:9.0.1-1.el9.noarch',
      'suffix-confused' => 'puppetdb-extra-0:9.0.1-1.el9.noarch',
      'header-only' => 'Loaded plugins: versionlock',
      'malformed relevant' => 'puppetdb-0:9.0.1-no-architecture',
      'duplicate exact' => "#{exact}\n#{exact}",
      'alternate EVR' => "#{exact}\npuppetdb-0:9.0.2-1.el9.noarch",
      'epoch mismatch' => 'puppetdb-1:9.0.1-1.el9.noarch',
      'architecture mismatch' => 'puppetdb-0:9.0.1-1.el9.x86_64',
    }
    failures.each do |label, output|
      Dir.mktmpdir("stagehand-dnf-#{label}") do |root|
        _out, _err, status = run_collector(root, rpm_fixture(output: output), content: collector_for(desired))
        expect(status).not_to be_success, label
        expect(File).not_to exist(File.join(root, 'observed.json'))
      end
    end

    valid_output = "Loaded plugins: versionlock\n\n#{exact}\npuppetdb-termini-0:9.0.1-1.el9.noarch\n"
    Dir.mktmpdir('stagehand-dnf-exact') do |root|
      _out, err, status = run_collector(root, rpm_fixture(output: valid_output), content: collector_for(desired))
      expect(status).to be_success, err
      lock = JSON.parse(File.read(File.join(root, 'observed.json'))).dig('observed', 'locks', 0)
      expect(lock).to include('package' => 'puppetdb', 'mechanism' => 'rpm', 'status' => 'locked')
    end
  end

  it 'accepts an exact nonzero DNF epoch only when the installed identity matches' do
    desired = rpm_agent_desired('puppetdb', '2:9.0.1-1.el9.noarch')
    fixture_data = rpm_fixture('puppetdb', '2:9.0.1-1.el9.noarch', output: 'puppetdb-2:9.0.1-1.el9.noarch')
    Dir.mktmpdir('stagehand-dnf-epoch') do |root|
      _out, err, status = run_collector(root, fixture_data, content: collector_for(desired))
      expect(status).to be_success, err
    end
  end

  it 'requires one exact package-kind solvable from machine-readable Zypper evidence' do
    desired = sles_agent_desired
    exact = '<solvable kind="package" name="puppetdb" edition="9.0.1-1.sles15" arch="noarch"/>'
    termini = '<solvable kind="package" name="puppetdb-termini" edition="0:9.0.1-1.sles15" arch="noarch"/>'
    wrap = ->(body) { "<?xml version=\"1.0\"?><stream><message type=\"info\"><text>locks</text></message><locks>#{body}</locks></stream>" }
    failures = {
      'termini-only' => wrap.call(termini),
      'duplicate exact' => wrap.call(exact + exact),
      'alternate edition' => wrap.call(exact + '<solvable kind="package" name="puppetdb" edition="0:9.0.2-1.sles15" arch="noarch"/>'),
      'epoch mismatch' => wrap.call('<solvable kind="package" name="puppetdb" edition="1:9.0.1-1.sles15" arch="noarch"/>'),
      'architecture mismatch' => wrap.call('<solvable kind="package" name="puppetdb" edition="0:9.0.1-1.sles15" arch="x86_64"/>'),
      'header-only' => wrap.call(''),
      'malformed relevant' => wrap.call('<solvable kind="package" name="puppetdb" edition="0:9.0.1-1.sles15"/>'),
      'similar name' => wrap.call('<solvable kind="package" name="puppetdb-extra" edition="0:9.0.1-1.sles15" arch="noarch"/>'),
      'malformed XML' => '<stream><locks>',
      'multiple roots' => wrap.call(exact) + '<stream/>',
    }
    failures.each do |label, output|
      Dir.mktmpdir("stagehand-zypper-#{label}") do |root|
        fixture_data = rpm_fixture('puppetdb', '0:9.0.1-1.sles15.noarch', output: output)
        _out, _err, status = run_collector(root, fixture_data, content: collector_for(desired))
        expect(status).not_to be_success, label
      end
    end

    Dir.mktmpdir('stagehand-zypper-exact') do |root|
      fixture_data = rpm_fixture('puppetdb', '0:9.0.1-1.sles15.noarch', output: wrap.call(termini + exact))
      _out, err, status = run_collector(root, fixture_data, content: collector_for(desired))
      expect(status).to be_success, err
    end
  end

  it 'publishes generation-bound verified evidence with a canonical digest' do
    Dir.mktmpdir('stagehand-observe') do |root|
      _stdout, stderr, status = run_collector(root, complete_fixture)
      expect(status).to be_success, stderr
      desired = JSON.parse(File.read(File.join(root, 'desired.json'))).fetch('desired')
      observed = JSON.parse(File.read(File.join(root, 'observed.json'))).fetch('observed')
      expect(observed).to include(
        'target_id' => 'core.example.test',
        'release_set_id' => 'puppet-core-9-v1',
        'evidence_sha256' => params.fetch('evidence_sha256'),
        'desired_generation_sha256' => desired.fetch('desired_generation_sha256'),
        'status' => 'verified',
        'repository_track' => 9,
      )
      expect(observed.fetch('java').map { |entry| entry.fetch('role') }).to eq(%w[puppet_server puppetdb])
      expect(observed.dig('postgresql', 'pg_trgm_extversion')).to eq('1.6')
      expect(observed.fetch('locks').length).to eq(4)
      payload = observed.reject { |key, _value| key == 'observation_sha256' }
      expect(observed.fetch('observation_sha256')).to eq(Digest::SHA256.hexdigest(JSON.generate(canonical(payload))))
    end
  end

  it 'binds the desired generation to the complete canonical projection' do
    embedded = helper_content[/Base64\.strict_decode64\('([A-Za-z0-9+\/=]+)'\)/, 1]
    desired = JSON.parse(Base64.strict_decode64(embedded)).fetch('desired')
    generation = desired.delete('desired_generation_sha256')
    expect(generation).to eq(Digest::SHA256.hexdigest(JSON.generate(canonical(desired))))
    changed = Marshal.load(Marshal.dump(desired))
    changed['repository_track'] = 8
    expect(generation).not_to eq(Digest::SHA256.hexdigest(JSON.generate(canonical(changed))))
  end

  it 'preserves prior observed bytes and emits a current failure on partial state' do
    Dir.mktmpdir('stagehand-observe') do |root|
      _stdout, stderr, status = run_collector(root, complete_fixture)
      expect(status).to be_success, stderr
      prior = File.binread(File.join(root, 'observed.json'))

      bad = complete_fixture.merge('packages' => { 'puppet-agent' => '9.0.0-tampered' })
      _stdout, _stderr, failed = run_collector(root, bad)
      expect(failed).not_to be_success
      expect(File.binread(File.join(root, 'observed.json'))).to eq(prior)
      failure = JSON.parse(File.read(File.join(root, 'collection-failure.json')))
      expect(failure.dig('failure', 'status')).to eq('failed')
      expect(failure.dig('failure', 'desired_generation_sha256')).to match(/\A[0-9a-f]{64}\z/)
    end
  end

  it 'contains fixed native probes and bounded atomic publication' do
    helper = helper_content
    expect(helper).to include("Open3.capture3(*argv)")
    expect(helper).to include("'/usr/bin/dpkg-query'")
    expect(helper).to include("'/usr/bin/apt-mark'")
    expect(helper).to include('Timeout.timeout(15)')
    expect(helper).to include('file.fsync')
    expect(helper).to include('File.rename')
    expect(helper).not_to match(/system\(|`|IO\.popen/)
  end


  it 'emits exactly the observations owned by each role set' do
    base = desired_document.fetch('desired')
    server = params.fetch('roles')[0]
    puppetdb = params.fetch('roles')[1]
    postgres = params.fetch('roles')[2]
    agent = { 'role' => 'agent', 'packages' => [{ 'name' => 'puppet-agent', 'evr' => '9.0.0-1noble' }], 'runtime' => {} }
    cases = [
      [[agent], complete_fixture.slice('healthy', 'repository_track').merge('packages' => { 'puppet-agent' => '9.0.0-1noble' }, 'native_lock_output' => "puppet-agent\n"), 1, 0, false],
      [[server], complete_fixture.merge('packages' => complete_fixture['packages'].slice('puppet-agent', 'puppetdb-termini', 'puppetserver'), 'native_lock_output' => "puppet-agent\npuppetdb-termini\npuppetserver\n", 'java' => complete_fixture['java'].slice('puppet_server')).except('postgresql'), 3, 1, false],
      [[puppetdb, postgres], complete_fixture.merge('packages' => complete_fixture['packages'].slice('puppet-agent', 'puppetdb'), 'native_lock_output' => "puppet-agent\npuppetdb\n", 'java' => complete_fixture['java'].slice('puppetdb')), 2, 1, true],
      [params.fetch('roles'), complete_fixture, 4, 2, true],
    ]
    cases.each do |roles, fixture_data, package_count, java_count, has_postgresql|
      desired = base.merge('roles' => roles)
      Dir.mktmpdir('stagehand-role-matrix') do |root|
        _out, err, status = run_collector(root, fixture_data, content: collector_for(desired))
        expect(status).to be_success, err
        observed = JSON.parse(File.read(File.join(root, 'observed.json'))).fetch('observed')
        expect(observed.fetch('packages').length).to eq(package_count)
        expect(observed.fetch('locks').length).to eq(package_count)
        expect(observed.fetch('java').length).to eq(java_count)
        expect(!observed.fetch('postgresql').empty?).to eq(has_postgresql)
      end
    end
  end

  it 'uses deterministic native lock adapters without changing existing module support metadata' do
    base = desired_document.fetch('desired')
    families = { 'debian' => 'apt', 'redhat' => 'rpm', 'sles' => 'zypper', 'windows' => 'windows' }
    agent = { 'role' => 'agent', 'packages' => [{ 'name' => 'puppet-agent', 'evr' => '9.0.0' }], 'runtime' => {} }
    families.each do |family, mechanism|
      desired = base.merge('roles' => [agent], 'os' => base.fetch('os').merge('family' => family))
      native_output = case family
                      when 'debian' then "puppet-agent\n"
                      when 'redhat' then "puppet-agent-0:9.0.0-1.noarch\n"
                      when 'sles' then '<?xml version="1.0"?><stream><locks><solvable kind="package" name="puppet-agent" edition="0:9.0.0-1" arch="noarch"/></locks></stream>'
                      else ''
                      end
      package_evr = %w[redhat sles].include?(family) ? '0:9.0.0-1.noarch' : '9.0.0'
      desired = base.merge('roles' => [{ 'role' => 'agent', 'packages' => [{ 'name' => 'puppet-agent', 'evr' => package_evr }], 'runtime' => {} }], 'os' => base.fetch('os').merge('family' => family))
      fixture_data = { 'healthy' => true, 'repository_track' => 9, 'packages' => { 'puppet-agent' => package_evr }, 'native_lock_output' => native_output }
      Dir.mktmpdir('stagehand-adapter-matrix') do |root|
        _out, err, status = run_collector(root, fixture_data, content: collector_for(desired))
        expect(status).to be_success, "#{family}: #{err}"
        lock = JSON.parse(File.read(File.join(root, 'observed.json'))).dig('observed', 'locks', 0)
        expect(lock.fetch('mechanism')).to eq(mechanism)
      end
    end
    expect(JSON.parse(File.read(File.expand_path('../../metadata.json', __dir__))).fetch('operatingsystem_support')).to eq([
      { 'operatingsystem' => 'Ubuntu', 'operatingsystemrelease' => ['20.04', '22.04', '24.04'] },
      { 'operatingsystem' => 'Debian', 'operatingsystemrelease' => ['11', '12'] },
      { 'operatingsystem' => 'RedHat', 'operatingsystemrelease' => ['8', '9'] },
      { 'operatingsystem' => 'Rocky', 'operatingsystemrelease' => ['8', '9'] },
      { 'operatingsystem' => 'AlmaLinux', 'operatingsystemrelease' => ['8', '9'] },
    ])
  end

  it 'fails closed for incomplete, extra, stale, unhealthy, or credential-shaped fixture evidence' do
    mutations = [
      complete_fixture.merge('packages' => complete_fixture['packages'].except('puppetserver')),
      complete_fixture.merge('packages' => complete_fixture['packages'].merge('extra' => '1')),
      complete_fixture.merge('native_lock_output' => "puppet-agent\npuppetdb\npuppetdb-termini\n"),
      complete_fixture.merge('healthy' => false),
      complete_fixture.merge('repository_track' => 8),
      complete_fixture.merge('api_token' => 'do-not-collect'),
      complete_fixture.merge('java' => complete_fixture['java'].except('puppetdb')),
      complete_fixture.merge('postgresql' => complete_fixture['postgresql'].merge('packages' => complete_fixture.dig('postgresql', 'packages').except('postgresql-contrib-17'))),
      complete_fixture.merge('postgresql' => complete_fixture['postgresql'].except('pg_trgm_extversion')),
    ]
    mutations.each do |fixture_data|
      Dir.mktmpdir('stagehand-fail-closed') do |root|
        _out, _err, status = run_collector(root, fixture_data)
        expect(status).not_to be_success
        expect(File).not_to exist(File.join(root, 'observed.json'))
        expect(JSON.parse(File.read(File.join(root, 'collection-failure.json'))).dig('failure', 'status')).to eq('failed')
      end
    end
  end

  it 'rejects stale desired generations and duplicate or oversized fixture JSON' do
    desired = desired_document.fetch('desired').merge('repository_track' => 8)
    duplicate = JSON.generate(complete_fixture).sub('"puppet-agent":"9.0.0-1noble"', '"puppet-agent":"bad","puppet-agent":"9.0.0-1noble"')
    cases = [
      [complete_fixture, collector_for(desired, recompute: false), nil],
      [nil, helper_content, duplicate],
      [complete_fixture.merge('padding' => 'x' * 1_048_576), helper_content, nil],
    ]
    cases.each do |fixture_data, content, raw|
      Dir.mktmpdir('stagehand-invalid-evidence') do |root|
        _out, _err, status = run_collector(root, fixture_data, content: content, raw_fixture: raw)
        expect(status).not_to be_success
        expect(File).not_to exist(File.join(root, 'observed.json'))
      end
    end
  end

  it 'does not follow symlink destinations or overwrite cached verified evidence after failure' do
    Dir.mktmpdir('stagehand-symlink') do |root|
      canonical_root = File.realpath(root)
      victim = File.join(canonical_root, 'victim')
      File.write(victim, 'untouched')
      File.symlink(victim, File.join(canonical_root, 'observed.json'))
      _out, _err, status = run_collector(canonical_root, complete_fixture)
      expect(status).not_to be_success
      expect(File.read(victim)).to eq('untouched')
    end
  end

  it 'marks a cached verified observation ineligible when the desired generation changes' do
    Dir.mktmpdir('stagehand-generation-cache') do |root|
      _out, err, status = run_collector(root, complete_fixture)
      expect(status).to be_success, err
      prior = File.binread(File.join(root, 'observed.json'))
      old_generation = JSON.parse(prior).dig('observed', 'desired_generation_sha256')

      desired = desired_document.fetch('desired').merge('repository_track' => 8)
      failed_fixture = complete_fixture.merge('repository_track' => 8, 'healthy' => false)
      _out, _err, failed = run_collector(root, failed_fixture, content: collector_for(desired))
      expect(failed).not_to be_success
      expect(File.binread(File.join(root, 'observed.json'))).to eq(prior)
      current_generation = JSON.parse(File.read(File.join(root, 'desired.json'))).dig('desired', 'desired_generation_sha256')
      failure_generation = JSON.parse(File.read(File.join(root, 'collection-failure.json'))).dig('failure', 'desired_generation_sha256')
      expect(current_generation).to eq(failure_generation)
      expect(current_generation).not_to eq(old_generation)
    end
  end

  it 'returns typed failures for missing, non-executable, and oversized native probes' do
    Dir.mktmpdir('stagehand-native-probes') do |root|
      canonical_root = File.realpath(root)
      oversized = File.join(canonical_root, 'oversized-probe')
      denied = File.join(canonical_root, 'denied-probe')
      File.write(oversized, "#!#{RbConfig.ruby}\nSTDOUT.write('x' * 70_000)\n")
      File.write(denied, "#!#{RbConfig.ruby}\n")
      File.chmod(0o700, oversized)
      File.chmod(0o000, denied)
      probe_paths = ['/definitely/missing/dpkg-query', denied, oversized]
      probe_paths.each_with_index do |probe, index|
        attempt = File.join(canonical_root, "attempt-#{index}")
        Dir.mkdir(attempt, 0o700)
        content = helper_content.gsub("'/usr/bin/dpkg-query'", probe.inspect)
        _out, _err, status = run_collector(attempt, nil, content: content)
        expect(status).not_to be_success
        failure = JSON.parse(File.read(File.join(attempt, 'collection-failure.json')))
        expect(failure.dig('failure', 'status')).to eq('failed')
        expect(File).not_to exist(File.join(attempt, 'observed.json'))
      end
    ensure
      File.chmod(0o600, denied) if denied && File.exist?(denied)
    end
  end
end
