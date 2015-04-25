require 'spec_helper'

describe Pester::Environment do
  let(:options) { {} }
  let!(:environment) { Pester::Environment.new(options) }

  describe 'Delegation to Pester' do
    context 'for retry-prefixed methods' do
      context 'which are supported' do
        let(:pester) { class_double("Pester").as_stubbed_const }

        context 'without options' do
          it 'calls Pester#retry without options' do
            expect(pester).to receive(:send).with(:retry, {})
            environment.retry { }
          end
        end
        context 'with options' do
          let(:options) { { test_opt: 1234 } }

          it 'calls Pester#retry with the given options' do
            expect(pester).to receive(:send).with(:retry, options)
            environment.retry { }
          end
        end
      end

      context 'which do not exist' do
        let(:options) { { test_opt: 1234 } }

        it 'lets Pester raise NoMethodError' do
          expect { environment.retry_does_not_exist { } }.to raise_error(NoMethodError)
        end
      end
    end

    context 'for non-retry-prefixed methods' do
      let(:pester) { class_double("Pester").as_stubbed_const }

      it 'raises NoMethodError' do
        expect { environment.something_else { } }.to raise_error(NoMethodError)
      end
    end
  end
end
