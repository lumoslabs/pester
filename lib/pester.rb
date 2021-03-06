require 'pester/behaviors'
require 'pester/behaviors/sleep'
require 'pester/environment'
require 'pester/config'
require 'pester/version'

module Pester
  extend self
  attr_accessor :environments

  def configure(&block)
    Config.configure(&block)

    return if Config.environments.nil?

    valid_environments = Config.environments.select { |_, e| e.is_a?(Hash) }
    @environments = Hash[valid_environments.map { |k, e| [k.to_sym, Environment.new(e)] }]
  end

  def retry_constant(options = {}, &block)
    retry_action(options.merge(on_retry: Behaviors::Sleep::Constant), &block)
  end

  def retry_with_backoff(options = {}, &block)
    retry_action(options.merge(on_retry: Behaviors::Sleep::Linear), &block)
  end

  def retry_with_exponential_backoff(options = {}, &block)
    retry_action({ delay_interval: 1 }.merge(options).merge(on_retry: Behaviors::Sleep::Exponential), &block)
  end

  # This function executes a block and retries the block depending on
  # which errors were thrown. Retries 4 times by default.
  #
  # Options:
  #   retry_error_classes       - A single or array of exceptions to retry on. Thrown exceptions not in this list
  #                               (including parent/sub-classes) will be reraised
  #   retry_error_messages      - A single or array of exception messages to retry on.  If only this options is passed,
  #                               any exception with a message containing one of these strings will be retried.  If this
  #                               option is passed along with retry_error_classes, retry will only happen when both the
  #                               class and the message match the exception.  Strings and regexes are both permitted.
  #   reraise_error_classes     - A single or array of exceptions to always re-raiseon. Thrown exceptions not in
  #                               this list (including parent/sub-classes) will be retried
  #   max_attempts              - Max number of attempts to retry
  #   delay_interval            - Second interval by which successive attempts will be incremented. A value of 2
  #                               passed to retry_with_backoff will retry first after 2 seconds, then 4, then 6, et al.
  #   on_retry                  - A Proc to be called on each successive failure, before the next retry
  #   on_max_attempts_exceeded  - A Proc to be called when attempt_num >= max_attempts - 1
  #   logger                    - Where to log the output
  #
  # Usage:
  #   retry_action(retry_error_classes: [Mysql2::Error]) do
  #     puts 'trying to remove a directory'
  #     FileUtils.rm_r(directory)
  #   end

  def retry_action(opts = {}, &block)
    merge_defaults(opts)
    if opts[:retry_error_classes] && opts[:reraise_error_classes]
      fail 'You can only have one of retry_error_classes or reraise_error_classes'
    end

    opts[:max_attempts].times do |attempt_num|
      begin
        return yield(block)
      rescue => e
        unless should_retry?(e, opts)
          opts[:logger].warn('Reraising exception from inside retry_action.')
          raise
        end

        if opts[:max_attempts] - 1 > attempt_num
          attempts_left = opts[:max_attempts] - attempt_num - 1
          trace = e.backtrace
          opts[:logger].warn("Failure encountered: #{e}, backing off and trying again #{attempts_left} more times. Trace: #{trace}")
          opts[:on_retry].call(attempt_num, opts[:delay_interval])
        else
          # Careful here because you will get back the return value of the on_max_attempts_exceeded proc!
          return opts[:on_max_attempts_exceeded].call(opts[:logger], opts[:max_attempts], e)
        end
      end
    end

    nil
  end

  def respond_to?(method_sym, options = {}, &block)
    super || Config.environments.key?(method_sym)
  end

  def method_missing(method_sym, options = {}, &block)
    if @environments.key?(method_sym)
      @environments[method_sym]
    else
      super
    end
  end

  private

  def should_retry?(e, opts = {})
    retry_error_classes   = opts[:retry_error_classes]
    retry_error_messages  = opts[:retry_error_messages]
    reraise_error_classes = opts[:reraise_error_classes]

    if retry_error_classes
      if retry_error_messages
        retry_error_classes.include?(e.class) && retry_error_messages.any? { |m| e.message[m] }
      else
        retry_error_classes.include?(e.class)
      end
    elsif retry_error_messages
      retry_error_messages.any? { |m| e.message[m] }
    elsif reraise_error_classes && reraise_error_classes.include?(e.class)
      false
    else
      true
    end
  end

  def merge_defaults(opts)
    opts[:retry_error_classes]      = opts[:retry_error_classes] ? Array(opts[:retry_error_classes]) : nil
    opts[:retry_error_messages]     = opts[:retry_error_messages] ? Array(opts[:retry_error_messages]) : nil
    opts[:reraise_error_classes]    = opts[:reraise_error_classes] ? Array(opts[:reraise_error_classes]) : nil
    opts[:max_attempts]             ||= 4
    opts[:delay_interval]           ||= 30
    opts[:on_retry]                 ||= ->(_, _) {}
    opts[:on_max_attempts_exceeded] ||= Behaviors::WarnAndReraise
    opts[:logger]                   ||= Config.logger
  end

  alias_method :retry, :retry_action
end
