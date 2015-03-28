require 'pester/behaviors'
require 'pester/behaviors/sleep'
require 'pester/version'

module Pester
  def self.retry(options = {}, &block)
    retry_action(options.merge(on_retry: ->(_, delay_interval) { sleep(delay_interval) }), &block)
  end

  def self.retry_with_backoff(options = {}, &block)
    retry_action(options.merge(on_retry: Behaviors::Sleep::Linear), &block)
  end

  def self.retry_with_exponential_backoff(options = {}, &block)
    retry_action({ delay_interval: 1 }.merge(options).merge(on_retry: Behaviors::Sleep::Exponential), &block)
  end

  # This function executes a block and retries the block depending on
  # which errors were thrown. Retries 4 times by default.
  #
  # Options:
  #   retry_error_classes       - A single or array of exceptions to retry on. Thrown exceptions not in this list
  #                               (including parent/sub-classes) will be reraised
  #   reraise_error_classes     - A single or array of exceptions to always re-raiseon. Thrown exceptions not in
  #                               this list (including parent/sub-classes) will be retried
  #   max_attempts              - Max number of attempts to retry
  #   delay_interval            - Second interval by which successive attempts will be incremented. A value of 2
  #                               passed to retry_with_backoff will retry first after 2 seconds, then 4, then 6, et al.
  #   on_retry                  - A Proc to be called on each successive failure, before the next retry
  #   on_max_attempts_exceeded  - A Proc to be called when attempt_num >= max_attempts - 1
  #   message                   - String or regex to look for in thrown exception messages. Matches will trigger retry
  #                               logic, non-matches will cause the exception to be reraised
  #
  # Usage:
  #   retry_action do
  #     puts 'trying to remove a directory'
  #     FileUtils.rm_r(directory)
  #   end
  #
  #  retryable(error_classes: Mysql2::Error, message: /^Lost connection to MySQL server/, max_attempts: 2) do
  #    ActiveRecord::Base.connection.execute("LONG MYSQL STATEMENT")
  #  end
  def self.retry_action(opts = {}, &block)
    merge_defaults(opts)
    if opts[:retry_error_classes] && opts[:reraise_error_classes]
      fail 'You can only have one of retry_error_classes or reraise_error_classes'
    end

    opts[:max_attempts].times do |attempt_num|
      begin
        result = yield block
        return result
      rescue => e
        class_reraise = opts[:retry_error_classes] && !opts[:retry_error_classes].include?(e.class)
        reraise_error = opts[:reraise_error_classes] && opts[:reraise_error_classes].include?(e.class)
        message_reraise = opts[:message] && !e.message[opts[:message]]

        if class_reraise || message_reraise || reraise_error
          match_type = class_reraise ? 'class' : 'message'
          opts[:logger].warn("Reraising exception from inside retry_action because provided #{match_type} was not matched.")
          raise
        end

        if opts[:max_attempts] - 1 > attempt_num
          attempts_left = opts[:max_attempts] - attempt_num - 1
          trace = e.backtrace
          opts[:logger].warn("Failure encountered: #{e}, backing off and trying again #{attempts_left} more times. Trace: #{trace}")
          opts[:on_retry].call(attempt_num, opts[:delay_interval])
        else
          return opts[:on_max_attempts_exceeded].call(opts[:logger], opts[:max_attempts], e)
        end
      end
    end
  end

  class << self
    attr_accessor :logger
  end

  private

  def self.logger
    @logger ||= begin
      if defined? Rails
        Rails.logger
      else
        require 'logger' unless defined? Logger
        @logger = Logger.new(STDOUT)
      end
    end
  end

  def self.merge_defaults(opts)
    opts[:retry_error_classes]      = opts[:retry_error_classes] ? Array(opts[:retry_error_classes]) : nil
    opts[:reraise_error_classes]    = opts[:reraise_error_classes] ? Array(opts[:reraise_error_classes]) : nil
    opts[:max_attempts]             ||= 4
    opts[:delay_interval]           ||= 30
    opts[:on_retry]                 ||= ->(_, _) {}
    opts[:on_max_attempts_exceeded] ||= Behaviors::WarnAndReraise
    opts[:logger]                   ||= logger
  end
end
