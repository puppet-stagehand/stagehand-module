require 'json'
require 'digest'
require 'fileutils'
require 'open3'
require 'spec_helper'
require 'tmpdir'

RSpec.describe 'the approved platform contract' do
  subject(:contract) do
    JSON.parse(File.read(File.expand_path('../../data/platform_contract_v1.json', __dir__)))
  end

  let(:approved_digest) { 'fe62fe9d17c8aac17f0e1863f679d7d6d329b26272596a4e0451d3de1271aa33' }

  it 'is bound to the one human-approved candidate set and artifact digest' do
    expect(contract.fetch('approved')).to be(true)
    expect(contract.fetch('sets').map { |set| set.fetch('set_id') }).to eq(['puppet-core-9-v1'])
    expect(contract.dig('sets', 0, 'support_disposition')).to eq('unvalidated')

    artifact = contract.dig('sets', 0, 'evidence').find do |item|
      item.fetch('source') == 'release-candidates-v1.json'
    end
    expect(artifact).to include(
      'kind' => 'repository_metadata',
      'sha256' => approved_digest,
      'authenticated' => true,
    )
  end

  it 'keeps exact role ownership and distinct service runtime majors for every platform' do
    expected_packages = {
      'agent' => ['puppet-agent'],
      'postgresql' => [],
      'puppet_server' => ['puppet-agent', 'puppetdb-termini', 'puppetserver'],
      'puppetdb' => ['puppet-agent', 'puppetdb'],
    }

    contract.dig('sets', 0, 'tuples').group_by { |tuple| [tuple.fetch('os_family'), tuple.fetch('architecture')] }.each_value do |tuples|
      expect(tuples.map { |tuple| tuple.fetch('role') }.sort).to eq(expected_packages.keys.sort)
      tuples.each do |tuple|
        expect(tuple.fetch('packages').map { |package| package.fetch('name') }).to eq(expected_packages.fetch(tuple.fetch('role')))
        expect(tuple.fetch('packages')).to all(include('evr' => a_string_matching(/\A\S+\z/)))
      end
      expect(tuples.find { |tuple| tuple.fetch('role') == 'puppet_server' }.dig('runtime', 'java_major')).to eq(21)
      expect(tuples.find { |tuple| tuple.fetch('role') == 'puppetdb' }.dig('runtime', 'java_major')).to eq(17)
      expect(tuples.find { |tuple| tuple.fetch('role') == 'puppetdb' }.dig('runtime', 'postgresql_major')).to eq(17)
      expect(tuples.find { |tuple| tuple.fetch('role') == 'postgresql' }.dig('runtime', 'postgresql_major')).to eq(17)
    end
  end

  it 'is canonical JSON with deterministic tuple and package ordering' do
    source = File.read(File.expand_path('../../data/platform_contract_v1.json', __dir__))
    expect(source).to end_with("\n")
    expect(source).to start_with("{\n  \"schema_version\": 1,")

    tuples = contract.dig('sets', 0, 'tuples')
    keys = tuples.map { |tuple| [tuple.fetch('os_family'), tuple.fetch('architecture'), tuple.fetch('role')] }
    expect(keys).to eq(keys.sort)
    tuples.each do |tuple|
      names = tuple.fetch('packages').map { |package| package.fetch('name') }
      expect(names).to eq(names.sort)
    end
  end
end

RSpec.describe 'platform contract support evidence application' do
  let(:stagehand_root) { File.expand_path('../..', __dir__) }
  let(:installer_root) do
    ENV.fetch('PUPPET_INSTALLER_ROOT', File.expand_path('../../../../puppet-installer', __dir__))
  end
  let(:updater) { File.join(installer_root, 'scripts/apply-platform-support-evidence.sh') }
  let(:intent) { File.join(installer_root, 'config/release-intent-v1.json') }
  let(:evidence_root) { File.join(installer_root, '.artifacts/platform-lock') }
  let(:source_contract) { File.join(stagehand_root, 'data/platform_contract_v1.json') }
  let(:source_metadata) { File.join(stagehand_root, 'metadata.json') }

  def canonical_json(value)
    sorted = case value
             when Hash
               value.keys.sort.to_h { |key| [key, canonical_json(value.fetch(key))] }
             when Array
               value.map { |item| canonical_json(item) }
             else
               value
             end
    sorted
  end

  def write_canonical(path, value)
    File.chmod(0o600, path) if File.exist?(path)
    File.write(path, "#{JSON.generate(canonical_json(value))}\n")
    File.chmod(0o400, path)
  end

  def run_updater(contract:, metadata:, evidence:)
    Open3.capture3(
      'bash', updater,
      '--intent', intent,
      '--contract', contract,
      '--metadata', metadata,
      '--evidence-dir', evidence,
    )
  end

  def with_inputs
    Dir.mktmpdir('platform-support-application') do |dir|
      contract = File.join(dir, 'platform_contract_v1.json')
      metadata = File.join(dir, 'metadata.json')
      evidence = File.join(dir, 'evidence')
      FileUtils.cp(source_contract, contract)
      FileUtils.cp(source_metadata, metadata)
      FileUtils.cp_r(evidence_root, evidence)
      File.chmod(0o600, contract)
      File.chmod(0o600, metadata)
      Dir.glob(File.join(evidence, '**/*.json')).each { |path| File.chmod(0o400, path) }
      yield dir, contract, metadata, evidence
    end
  end

  it 'projects every named support evidence artifact without changing approved package identity' do
    with_inputs do |_dir, contract_path, metadata_path, evidence|
      before = JSON.parse(File.read(contract_path))
      stdout, stderr, status = run_updater(contract: contract_path, metadata: metadata_path, evidence: evidence)
      expect(status).to be_success, "#{stdout}\n#{stderr}"

      after = JSON.parse(File.read(contract_path))
      before_set = before.fetch('sets').first
      after_set = after.fetch('sets').first
      expect(after_set.fetch('set_id')).to eq(before_set.fetch('set_id'))
      expect(after_set.fetch('puppet_track')).to eq(before_set.fetch('puppet_track'))
      expect(after_set.fetch('tuples')).to eq(before_set.fetch('tuples'))
      approved = before_set.fetch('evidence').reject { |item| item.fetch('kind') == 'acceptance' }
      expect(after_set.fetch('evidence').first(approved.length)).to eq(approved)

      final_evidence = after_set.fetch('evidence').select { |item| item.fetch('kind') == 'acceptance' }
      expect(final_evidence.length).to eq(8)
      expect(final_evidence.map { |item| item.fetch('source') }).to eq(final_evidence.map { |item| item.fetch('source') }.sort)
      final_evidence.each do |item|
        relative, identity = item.fetch('source').split('#artifact_id=', 2)
        artifact_path = File.join(evidence, relative)
        artifact = JSON.parse(File.read(artifact_path))
        expect(identity).to eq(artifact.fetch('artifact_id'))
        expect(item.fetch('sha256')).to eq(Digest::SHA256.file(artifact_path).hexdigest)
      end
      expect(after_set.fetch('support_disposition')).to eq('unvalidated')
    end
  end

  it 'demotes stale support evidence and metadata claims when an intended artifact is missing' do
    with_inputs do |_dir, contract_path, metadata_path, evidence|
      contract = JSON.parse(File.read(contract_path))
      contract.fetch('sets').first['support_disposition'] = 'supported'
      File.write(contract_path, "#{JSON.pretty_generate(contract)}\n")
      metadata = JSON.parse(File.read(metadata_path))
      metadata['operatingsystem_support'] = [
        { 'operatingsystem' => 'Ubuntu', 'operatingsystemrelease' => ['24.04'] },
      ]
      File.write(metadata_path, "#{JSON.pretty_generate(metadata)}\n")
      File.delete(Dir.glob(File.join(evidence, 'puppet-core-9-v1/*.json')).sort.first)

      _stdout, _stderr, status = run_updater(contract: contract_path, metadata: metadata_path, evidence: evidence)
      expect(status).not_to be_success
      expect(JSON.parse(File.read(contract_path)).dig('sets', 0, 'support_disposition')).to eq('unvalidated')
      expect(JSON.parse(File.read(metadata_path)).fetch('operatingsystem_support')).to eq([])
    end
  end

  it 'requires every mandatory live assertion before support evidence can promote metadata claims' do
    with_inputs do |_dir, contract_path, metadata_path, evidence|
      Dir.glob(File.join(evidence, 'puppet-core-9-v1/*.json')).each do |path|
        artifact = JSON.parse(File.read(path))
        artifact['disposition'] = 'supported'
        artifact['reason_code'] = 'live_probe_passed'
        artifact['probe']['kind'] = 'live'
        artifact.fetch('checks').each_value do |check|
          check['status'] = check['status'] == 'not_applicable' ? 'not_applicable' : 'pass'
        end
        expected = artifact.fetch('expected')
        artifact['checks']['ordinary_update']['status'] = expected.fetch('packages').empty? ? 'not_applicable' : 'pass'
        artifact['checks']['controlled_upgrade']['status'] = expected.fetch('packages').empty? ? 'not_applicable' : 'pass'
        artifact['checks']['final_relock']['status'] = expected.fetch('packages').empty? ? 'not_applicable' : 'pass'
        artifact['checks']['service_java']['status'] = expected.fetch('runtime').key?('java_major') ? 'pass' : 'not_applicable'
        artifact['checks']['postgresql_pg_trgm']['status'] = expected.fetch('runtime').key?('postgresql_major') ? 'pass' : 'not_applicable'
        write_canonical(path, artifact)
      end
      result_path = File.join(evidence, 'run-result.json')
      result = JSON.parse(File.read(result_path))
      result['disposition'] = 'supported'
      write_canonical(result_path, result)

      stdout, stderr, status = run_updater(contract: contract_path, metadata: metadata_path, evidence: evidence)
      expect(status).to be_success, "#{stdout}\n#{stderr}"
      expect(JSON.parse(File.read(contract_path)).dig('sets', 0, 'support_disposition')).to eq('supported')
      expect(JSON.parse(File.read(metadata_path)).fetch('operatingsystem_support')).to eq([
        { 'operatingsystem' => 'Ubuntu', 'operatingsystemrelease' => ['24.04'] },
        { 'operatingsystem' => 'RedHat', 'operatingsystemrelease' => ['9'] },
      ])
    end
  end

  it 'leaves source unchanged when support evidence inputs cannot be trusted' do
    with_inputs do |dir, contract_path, metadata_path, evidence|
      invalid_intent = File.join(dir, 'invalid-intent.json')
      parsed = JSON.parse(File.read(intent))
      parsed['candidate_set_id'] = 'wrong-set'
      File.write(invalid_intent, JSON.pretty_generate(parsed))
      contract_before = File.binread(contract_path)
      metadata_before = File.binread(metadata_path)

      _stdout, _stderr, status = Open3.capture3(
        'bash', updater,
        '--intent', invalid_intent,
        '--contract', contract_path,
        '--metadata', metadata_path,
        '--evidence-dir', evidence,
      )
      expect(status).not_to be_success
      expect(File.binread(contract_path)).to eq(contract_before)
      expect(File.binread(metadata_path)).to eq(metadata_before)
    end
  end

  it 'keeps Stagehand specs runnable with explicit platform-lock facts without changing module support claims' do
    expect(JSON.parse(File.read(source_metadata)).fetch('operatingsystem_support')).to eq([
      { 'operatingsystem' => 'Ubuntu', 'operatingsystemrelease' => ['20.04', '22.04', '24.04'] },
      { 'operatingsystem' => 'Debian', 'operatingsystemrelease' => ['11', '12'] },
      { 'operatingsystem' => 'RedHat', 'operatingsystemrelease' => ['8', '9'] },
      { 'operatingsystem' => 'Rocky', 'operatingsystemrelease' => ['8', '9'] },
      { 'operatingsystem' => 'AlmaLinux', 'operatingsystemrelease' => ['8', '9'] },
    ])
    expect(on_supported_os).not_to be_empty
    expect(on_supported_os.keys).to include('ubuntu-24.04-x86_64', 'redhat-9-x86_64')
  end
end
