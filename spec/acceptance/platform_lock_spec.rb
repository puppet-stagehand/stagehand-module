# frozen_string_literal: true

require 'json'
require 'open3'
require 'tmpdir'

RSpec.describe 'platform lock live evidence' do
  let(:installer_root) do
    ENV.fetch('PUPPET_INSTALLER_ROOT', File.expand_path('../../../../puppet-installer', __dir__))
  end
  let(:runner) { File.join(installer_root, 'scripts/test-platform-lock-live.sh') }
  let(:intent) { File.join(installer_root, 'config/release-intent-v1.json') }
  let(:contract) { File.join(installer_root, 'internal/vendored/modules/stagehand/data/platform_contract_v1.json') }

  def run_runner(*args)
    Open3.capture3('bash', runner, *args)
  end

  def write_probe(dir, disposition_kind:, final_relock: true)
    platform_id = 'debian-noble-amd64-agent'
    probe = {
      'schema_version' => 1,
      'set_id' => 'puppet-core-9-v1',
      'platform_id' => platform_id,
      'repository_track' => 9,
      'package_identities' => [{ 'name' => 'puppet-agent', 'evr' => '9.0.0-1noble' }],
      'java' => {},
      'postgresql' => {},
      'catalog_report' => { 'catalog' => true, 'report' => true },
      'transaction' => {
        'ordinary_update_protected' => true,
        'controlled_upgrade_advanced' => true,
        'final_relock' => final_relock,
        'cancellation_recovered' => true,
      },
    }
    probe_path = File.join(dir, 'probe.json')
    File.write(probe_path, JSON.generate(probe))
    targets_path = File.join(dir, 'targets.json')
    File.write(targets_path, JSON.generate({
                                             'schema_version' => 1,
                                             'targets' => [{
                                               'platform_id' => platform_id,
                                               'evidence_kind' => disposition_kind,
                                               'command' => ['cat', probe_path],
                                             }],
                                           }))
    targets_path
  end

  it 'emits one fail-closed, identity-bound artifact for every intended role tuple' do
    Dir.mktmpdir('platform-lock-live') do |dir|
      _stdout, stderr, status = run_runner(
        '--all-intended', '--intent', intent, '--contract', contract, '--evidence-dir', dir
      )
      expect(status).to be_success, stderr

      artifacts = Dir.glob(File.join(dir, 'puppet-core-9-v1', '*.json')).reject { |path| path.end_with?('run-result.json') }
      expect(artifacts.length).to eq(8)
      artifacts.each do |path|
        evidence = JSON.parse(File.read(path))
        expect(evidence.fetch('schema_version')).to eq(1)
        expect(evidence.fetch('set_id')).to eq('puppet-core-9-v1')
        expect(evidence.fetch('platform_id')).to eq(File.basename(path, '.json'))
        expect(%w[supported unsupported unvalidated]).to include(evidence.fetch('disposition'))
        expect(evidence.fetch('checks').keys).to contain_exactly(
          'repository_track',
          'package_identities', 'ordinary_update', 'controlled_upgrade', 'final_relock',
          'service_java', 'postgresql_pg_trgm', 'catalog_report', 'cancellation_recovery'
        )
        expect(evidence.to_json).not_to match(%r{https?://[^\s/:]+:[^\s/@]+@})
      end
    end
  end

  it 'fails verification and restores a machine-readable unvalidated artifact when evidence is missing' do
    Dir.mktmpdir('platform-lock-live') do |dir|
      _stdout, stderr, status = run_runner(
        '--all-intended', '--intent', intent, '--contract', contract, '--evidence-dir', dir
      )
      expect(status).to be_success, stderr

      missing = Dir.glob(File.join(dir, 'puppet-core-9-v1', '*.json')).find { |path| !path.end_with?('run-result.json') }
      File.delete(missing)
      _stdout, _stderr, verify_status = run_runner(
        '--verify-only', '--intent', intent, '--contract', contract, '--evidence-dir', dir
      )
      expect(verify_status).not_to be_success
      restored = JSON.parse(File.read(missing))
      expect(restored.fetch('disposition')).to eq('unvalidated')
      expect(restored.fetch('reason_code')).to eq('missing_evidence')
    end
  end

  it 'rejects a wrong release set without turning it into a support claim' do
    Dir.mktmpdir('platform-lock-live') do |dir|
      wrong_contract = File.join(dir, 'contract.json')
      parsed = JSON.parse(File.read(contract))
      parsed.fetch('sets').first['set_id'] = 'wrong-set'
      File.write(wrong_contract, JSON.pretty_generate(parsed))

      _stdout, _stderr, status = run_runner(
        '--all-intended', '--intent', intent, '--contract', wrong_contract, '--evidence-dir', dir
      )
      expect(status).not_to be_success
      result = JSON.parse(File.read(File.join(dir, 'run-result.json')))
      expect(result.fetch('disposition')).to eq('unvalidated')
      expect(result.fetch('reason_code')).to eq('contract_set_mismatch')
    end
  end

  it 'never promotes complete fixture output into a live support claim' do
    Dir.mktmpdir('platform-lock-live') do |dir|
      targets = write_probe(dir, disposition_kind: 'fixture')
      _stdout, stderr, status = run_runner(
        '--all-intended', '--intent', intent, '--contract', contract,
        '--evidence-dir', dir, '--targets', targets
      )
      expect(status).to be_success, stderr
      evidence = JSON.parse(File.read(File.join(dir, 'puppet-core-9-v1', 'debian-noble-amd64-agent.json')))
      expect(evidence.fetch('disposition')).to eq('unvalidated')
      expect(evidence.fetch('reason_code')).to eq('fixture_evidence_not_live')
    end
  end

  it 'records a failed configured live probe as unsupported and exits nonzero' do
    Dir.mktmpdir('platform-lock-live') do |dir|
      targets = write_probe(dir, disposition_kind: 'live', final_relock: false)
      _stdout, _stderr, status = run_runner(
        '--all-intended', '--intent', intent, '--contract', contract,
        '--evidence-dir', dir, '--targets', targets
      )
      expect(status).not_to be_success
      evidence = JSON.parse(File.read(File.join(dir, 'puppet-core-9-v1', 'debian-noble-amd64-agent.json')))
      expect(evidence.fetch('disposition')).to eq('unsupported')
      expect(evidence.fetch('reason_code')).to eq('live_probe_failed_checks')
      expect(evidence.dig('checks', 'final_relock', 'status')).to eq('fail')
    end
  end
end
