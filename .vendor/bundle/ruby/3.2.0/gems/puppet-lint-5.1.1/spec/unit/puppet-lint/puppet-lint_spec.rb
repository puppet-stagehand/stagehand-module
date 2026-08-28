# rubocop: disable Naming/FileName

require 'spec_helper'

describe PuppetLint do
  subject(:linter) { described_class.new }

  it 'accepts manifests as a string' do
    linter.code = 'class foo { }'
    expect(linter.code).not_to be_nil
  end

  it 'returns empty manifest when empty one given as the input' do
    linter.code = ''
    linter.run
    expect(linter.manifest).to eq('')
  end

  describe '#supports_fixes?' do
    context 'with a .pp file' do
      it 'returns true' do
        linter.instance_variable_set(:@path, 'test.pp')
        expect(linter.supports_fixes?).to be true
      end
    end

    context 'with a .yaml file' do
      it 'returns false' do
        linter.instance_variable_set(:@path, 'test.yaml')
        expect(linter.supports_fixes?).to be false
      end
    end

    context 'with no path set' do
      it 'returns false' do
        expect(linter.supports_fixes?).to be false
      end
    end
  end

  describe '#should_write_fixes?' do
    before(:each) do
      linter.instance_variable_set(:@path, 'test.pp')
      linter.instance_variable_set(:@manifest, 'class test { }')
    end

    context 'when file supports fixes and has no syntax errors' do
      it 'returns true' do
        expect(linter.should_write_fixes?).to be true
      end
    end

    context 'when file has syntax errors' do
      it 'returns false' do
        linter.instance_variable_set(:@problems, [{ check: :syntax }])
        expect(linter.should_write_fixes?).to be false
      end
    end

    context 'when file type does not support fixes' do
      it 'returns false' do
        linter.instance_variable_set(:@path, 'test.yaml')
        expect(linter.should_write_fixes?).to be false
      end
    end
  end
end
