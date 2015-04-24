require 'logger'
require 'spec_helper'

class MatchedError < RuntimeError; end
class UnmatchedError < RuntimeError; end

shared_examples 'raises an error' do
  it 'raises an error and succeeds 0 times' do
    expect { Pester.retry_action(options) { action } }.to raise_error
    expect(failer.successes).to eq(0)
  end
end

shared_examples "doesn't raise an error" do
  it "doesn't raise an error" do
    expect { Pester.retry_action(options) { action } }.to_not raise_error
  end
end

shared_examples 'returns and succeeds' do
  it 'returns the intended result' do
    expect(Pester.retry_action(options) { action }).to eq(intended_result)
  end

  it 'succeeds exactly once' do
    Pester.retry_action(options) { action }
    expect(failer.successes).to eq(1)
  end
end

shared_examples 'has not run' do
  it 'returns the intended result' do
    expect(Pester.retry_action(options) { action }).to eq(nil)
  end

  it 'succeeds exactly once' do
    Pester.retry_action(options) { action }
    expect(failer.successes).to eq(0)
  end
end

shared_examples 'raises an error only in the correct cases with a retry class' do
  context 'when neither the class is in the retry list, nor is the message matched' do
    let(:actual_error_class) { non_matching_error_class }
    let(:actual_error_message) { non_matching_error_message }

    it_has_behavior 'raises an error'
  end

  context 'when the class is in the retry list, but the message is not matched' do
    let(:actual_error_class) { matching_error_class }
    let(:actual_error_message) { non_matching_error_message }

    it_has_behavior 'raises an error'
  end

  context 'when the class is not in the retry list, but the message is matched' do
    let(:actual_error_class) { non_matching_error_class }
    let(:actual_error_message) { matching_error_message }

    it_has_behavior 'raises an error'
  end

  context 'when the class is in the list, and the message is matched' do
    let(:actual_error_class) { matching_error_class }
    let(:actual_error_message) { matching_error_message }

    it_has_behavior "doesn't raise an error"
    it_has_behavior 'returns and succeeds'
  end
end

shared_examples 'raises an error only in the correct cases with a reraise class' do
  context 'when the class is not in the reraise list' do
    let(:actual_error_class) { non_matching_error_class }
    let(:actual_error_message) { non_matching_error_message }

    it_has_behavior "doesn't raise an error"
    it_has_behavior 'returns and succeeds'
  end

  context 'when the class is in the reraise list' do
    let(:actual_error_class) { matching_error_class }
    let(:actual_error_message) { matching_error_message }

    it_has_behavior 'raises an error'
  end
end

describe 'retry_action' do
  let(:intended_result) { 1000 }
  let(:action) { failer.fail(UnmatchedError, 'Dying') }
  let(:null_logger) { NullLogger.new }

  context 'for non-failing block' do
    let(:failer) { ScriptedFailer.new(0, intended_result) }
    let(:options) { { delay_interval: 0, logger: null_logger } }

    it_has_behavior "doesn't raise an error"
    it_has_behavior 'returns and succeeds'
  end

  context 'for block that fails less than threshold' do
    let(:failer) { ScriptedFailer.new(2, intended_result) }
    let(:options) { { max_attempts: 3, logger: null_logger } }

    it_has_behavior "doesn't raise an error"
    it_has_behavior 'returns and succeeds'
  end

  context 'for block that fails more than threshold' do
    let(:failer) { ScriptedFailer.new(6) }
    let(:max_attempts) { 1 }

    context 'without on_max_attempts_exceeded specified' do
      let(:options) { { max_attempts: max_attempts, logger: null_logger } }

      it_has_behavior 'raises an error'
    end

    context 'with on_max_attempts_exceeded proc specified' do
      let(:options) do
        {
          max_attempts: max_attempts,
          on_max_attempts_exceeded: proc_to_call,
          logger: null_logger
        }
      end

      context 'which does not do anything' do
        let(:proc_to_call) { proc {} }
        it_has_behavior "doesn't raise an error"
      end

      context 'which reraises' do
        let(:proc_to_call) { Behaviors::WarnAndReraise }
        it_has_behavior 'raises an error'
      end

      context 'which returns a value' do
        let(:return_value) { 'return_value' }
        let(:proc_to_call) { proc { return_value } }
        it_has_behavior "doesn't raise an error"

        it 'should return the result of the proc' do
          expect(Pester.retry_action(options) { action }).to eq(return_value)
        end
      end
    end
  end

  context 'for retry_action calls with provided retry classes and message strings' do
    let(:intended_result) { 1000 }
    let(:failer) { ScriptedFailer.new(2, intended_result) }
    let(:action) { failer.fail(actual_error_class, actual_error_message) }
    let(:matching_error_class) { MatchedError }
    let(:non_matching_error_class) { UnmatchedError }
    let(:matching_error_message) { 'Lost connection to MySQL server' }
    let(:non_matching_error_message) { 'You have an error in your SQL syntax' }

    context 'Using retry error classes' do
      let(:options) do
        {
          retry_error_classes: expected_error_classes,
          retry_error_messages: /^Lost connection to MySQL server/,
          max_attempts: 10,
          logger: null_logger
        }
      end

      context 'when error_classes is a single error class' do
        let(:expected_error_classes) { matching_error_class }

        it_has_behavior 'raises an error only in the correct cases with a retry class'
      end

      context 'when error_classes is a list of error classes' do
        let(:expected_error_classes) { [ArgumentError, matching_error_class] }

        it_has_behavior 'raises an error only in the correct cases with a retry class'
      end
    end

    context 'Using reraise error classes' do
      let(:options) do
        {
          reraise_error_classes: expected_error_classes,
          max_attempts: 10,
          logger: null_logger
        }
      end

      context 'when error_classes is a single error class' do
        let(:expected_error_classes) { matching_error_class }

        it_has_behavior 'raises an error only in the correct cases with a reraise class'
      end

      context 'when error_classes is a list of error classes' do
        let(:expected_error_classes) { [ArgumentError, matching_error_class] }

        it_has_behavior 'raises an error only in the correct cases with a reraise class'
      end
    end
  end

  context 'when max_attempts is set' do
    let(:intended_result) { 42 }
    let(:options) { { delay_interval: 0, logger: null_logger, max_attempts: max_attempts } }

    shared_examples "doesn't even run" do
      let(:action) { failer.fail(StandardError, 'Dying') }

      context 'for block does not fail' do
        let(:failer) { ScriptedFailer.new(0, intended_result) }

        it_has_behavior "doesn't raise an error"
        it_has_behavior 'has not run'
      end

      context 'for block fails' do
        let(:failer) { ScriptedFailer.new(1, intended_result) }

        it_has_behavior "doesn't raise an error"
        it_has_behavior 'has not run'
      end
    end

    context 'to one' do
      let(:max_attempts) { 1 }
      let(:action) { failer.fail(StandardError, 'Dying') }

      context 'for block does not fail' do
        let(:failer) { ScriptedFailer.new(0, intended_result) }

        it_has_behavior "doesn't raise an error"
        it_has_behavior 'returns and succeeds'
      end

      context 'for block fails' do
        let(:failer) { ScriptedFailer.new(1, intended_result) }

        it_has_behavior 'raises an error'
      end
    end

    context 'to zero' do
      let(:max_attempts) { 0 }

      it_has_behavior "doesn't even run"
    end

    context 'to less than zero' do
      let(:max_attempts) { -1 }

      it_has_behavior "doesn't even run"
    end
  end
end

describe 'environments' do
  context 'when a non-hash environment is configured' do
    it 'does not add it to the Pester environment list' do
      Pester.configure do |config|
        config.environments[:abc] = 1234
      end

      expect(Pester.environments.count).to eq(0)
    end
  end

  context 'when a non-hash environment is configured' do
    it 'does not add it to the Pester environment list' do
      Pester.configure do |config|
        config.environments[:abc] = { option: 1234 }
      end

      expect(Pester.environments.count).to eq(1)
    end
  end
end

describe 'logger' do
  context 'when not otherwise configured' do
    it 'defaults to the ruby logger' do
      Pester.configure do |config|
        config.logger = nil
      end
      expect(Pester::Config.logger).to_not be_nil
      expect(Pester::Config.logger).to be_kind_of(Logger)
    end
  end

  context 'when configured to use a particular class' do
    it 'users that class' do
      Pester.configure do |config|
        config.logger = NullLogger.new
      end
      expect(Pester::Config.logger).to_not be_nil
      expect(Pester::Config.logger).to be_kind_of(NullLogger)
    end
  end
end
