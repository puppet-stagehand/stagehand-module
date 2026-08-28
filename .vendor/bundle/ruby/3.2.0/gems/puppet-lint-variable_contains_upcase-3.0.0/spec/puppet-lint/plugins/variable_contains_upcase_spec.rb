require 'spec_helper'

describe 'variable_contains_upcase' do
  let(:msg) { 'variable contains a capital letter' }

  context 'a variable containing a capital' do
    let(:code) { '$fOobar' }

    it 'onlies detect a single problem' do
      expect(problems).to have(1).problem
    end

    it 'creates a warning' do
      expect(problems).to contain_warning(msg).on_line(1).in_column(1)
    end
  end

  context 'variable containing a capital' do
    let(:code) { '" $fOobar"' }

    it 'onlies detect a single problem' do
      expect(problems).to have(1).problem
    end

    it 'creates a warning' do
      expect(problems).to contain_warning(msg).on_line(1).in_column(3)
    end
  end

  context 'with fix enabled' do
    before do
      PuppetLint.configuration.fix = true
    end

    after do
      PuppetLint.configuration.fix = false
    end

    context 'fix variable containing a capital' do
      let(:code) { '" $fOobar"' }

      it 'onlies detect a single problem' do
        expect(problems).to have(1).problem
      end

      it 'fixes the manifest' do
        expect(problems).to contain_fixed(msg).on_line(1).in_column(3)
      end

      it 'downcases the variable name' do
        expect(manifest).to eq('" $foobar"')
      end
    end

    context 'a hash with an upcase key should not fail' do
      let(:code) { ' $myhash["Foo"]' }

      it 'does not detect a single problem' do
        expect(problems).to have(0).problem
      end
    end

    context 'a hash with an upcase key should not fail' do
      let(:code) { ' $myhash["Foo"]["bAr"]' }

      it 'does not detect a single problem' do
        expect(problems).to have(0).problem
      end
    end

    context 'a hash variable with an upcase key should fail' do
      let(:code) { ' $myHash["foo"]["bar"]' }

      it 'detects a single problem' do
        expect(problems).to have(1).problem
      end
    end
  end
end
