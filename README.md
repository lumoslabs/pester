# Pester - Coordinated retry logic

## This gem is abandoned, but perfectly operable

As of November 2017, this gem is still in production in a few various legacy corners of Lumosity, but we haven't committed code for two and a half years. Everything works as advertised, and we'll gladly accept pull requests, but we've moved most new and existing code over to [retriable](https://github.com/kamui/retriable/). We originally wrote `pester` as a more-configurable, easier-to-read alternative, but after successfully getting the single most-unique feature, contexts, [merged into retriable](https://github.com/kamui/retriable/pull/43), there's not really a great reason to have two different retry gems.

[![Travis](https://travis-ci.org/lumoslabs/pester.svg?branch=master)](https://travis-ci.org/lumoslabs/pester)
[![Code Climate](https://codeclimate.com/github/lumoslabs/pester/badges/gpa.svg)](https://codeclimate.com/github/lumoslabs/pester)

In a lot of our backend code, we quite often found ourselves repeating some of the same patterns for retry logic. Relying on external services--including internal service endpoints and databases--means things fail intermittently. Many of these operations are idempotent and can be retried, but external services don't especially like being pestered without some pause, so you need to slow your roll.

## Usage

From the outset, the goal of Pester is to offer a simple interface. For example:

    irb(main):001:0> require 'pester'
    => true
    irb(main):002:0> Pester.retry_constant { fail 'derp' }
    W, [2015-04-04T10:37:46.413158 #87600]  WARN -- : Failure encountered: derp, backing off and trying again 3 more times. etc etc

will retry the block--which always fails--until Pester has exhausted its amount of retries. With no options provided, this will sleep for a constant number of seconds between attempts.

Pester's basic retry behaviors are defined by three options:

* `delay_interval`
* `max_attempts`
* `on_retry`

`delay_interval` is the unit, in seconds, that will be delayed between attempts. Normally, this is just the total number of seconds, but it can change with other `Behavior`s. `max_attempts` is the number of tries Pester will make, including the initial one. If this is set to 1, Pester will basically not retry; less than 1, it will not even bother executing the block:

    irb(main):001:0> Pester.retry_constant(max_attempts: 0) { puts 'Trying...'; fail 'derp' }
    => nil

`on_retry` defines the behavior between retries, which can either be a custom block of code, or one of the predefined `Behavior`s, specifically in `Pester::Behaviors::Sleep`. If passed an empty lambda/block, Pester will immediately retry. When writing a custom behavior, `on_retry` expects a block that can be called with two parameters, `attempt_num`, and `delay_interval`, the idea being that these will mostly be used to define a function that determines just how long to sleep between attempts.

Three behaviors are provided out-of-the box:

* `Constant` is the default, and will simply sleep for `delay_interval` seconds
* `Linear` simply multiplies `attempt_num` by `delay_interval` and sleeps for that many seconds
* `Exponential` sleeps for 2<sup>(`attempt_num` - 1)</sup> * `delay_interval` seconds

All three are available either by passing the behaviors to `on_retry`, or by calling the increasingly-verbosely-named `retry_constant` (constant), `retry_with_backoff` (linear), or `retry_with_exponential_backoff` (exponential). `retry` by itself *will not* actually retry anything, unless provided with an `on_retry` function, either per-call or in the relevant environment.

Pester does log retry attempts (see below), however custom retry behavior that wraps existing `Behavior`s may be appropriate for logging custom information, incrementing statsd counters, etc. Also of note, different loggers can be passed per-call via the `logger` option.

Finally, one last behavior is executed once the max number of retries has been exhausted, `on_max_attempts_exceeded`, which is also configurable per-call. By default, this will log an exhaustion message to `warn` and just reraise the called exception, preserving the original stacktrace.

### Choosing what to retry

Pester can be configured to be picky about what it chooses to retry and what it lets through. Three options control this behavior:

* retry_error_classes
* reraise_error_classes
* retry_error_messages

The first two are mutually-exclusive whitelist and blacklists, both taking either a single error class or an array. Raising an error not covered by `retry_error_classes` (whitelist) causes it to immediately fail:

    irb(main):002:0> Pester.retry_constant(retry_error_classes: NotImplementedError) do
      puts 'Trying...'
      fail 'derp'
    end
    Trying...
    RuntimeError: derp

Raising an error covered by `reraise_error_classes` (blacklist) causes it to immediately fail:

    irb(main):002:0> Pester.retry_constant(reraise_error_classes: NotImplementedError) do
      puts 'Trying...'
      raise NotImplementedError.new('derp')
    end
    Trying...
    NotImplementedError: derp

`retry_error_messages` also takes a single string or array, and calls `include?` on the error message. If it matches, the error's retried:

    irb(main):002:0> Pester.retry_constant(retry_error_messages: 'please') do
      puts 'Trying...'
      fail 'retry this, please'
    end
    Trying...
    Trying...

Because it calls `include?`, this also works for regexes:

    irb(main):002:0> Pester.retry_constant(retry_error_messages: /\d/) do
      puts 'Trying...'
      fail 'retry this 2'
    end
    Trying...
    Trying...

### Configuration

#### Environments

The easiest way to coordinate sets of Pester options across an app is via environments--these are basically option hashes configured in Pester by name:

    Pester.configure do |c|
      c.environments[:aws]      = { max_attempts: 3, delay_interval: 5, on_retry: Pester::Behaviors::Sleep::Constant }
      c.environments[:internal] = { max_attempts: 2, delay_interval: 0, on_retry: Pester::Behaviors::Sleep::Constant }
    end

This will create two environments, `aws` and `internal`, which allow you to employ different backoff strategies, depending on the usage context. These are employed simply by calling `Pester.environment_name.retry` (where `retry` can also be another helper method):

    def aws_action
      Pester.aws.retry do
        aws_call
      end
    end

    def action
      Pester.internal.retry do
        some_other_call
      end
    end

Environments can also be merged with retry helper methods:

    Pester.aws.retry_constant  # acts different from
    Pester.aws.retry_with_exponential_backoff

where the helper method's `Behavior` will take precedence.

#### Logging

Pester will write retry and exhaustion information into your logs, by default using a ruby `Logger` to standard out. This can be configured either per-call, or one time per application in your initializer via `Pester#configure`. The following will suppress all logs by using a class that simply does nothing with log data, as found in `spec/`:

    Pester.configure do |c|
      c.logger = NullLogger.new
    end

And thus:

    irb(main):002:0> Pester.retry_constant(delay_interval: 1) { puts 'Trying...'; fail 'derp' }
    Trying...
    Trying...
    Trying...
    Trying...
    RuntimeError: derp

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pester'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install pester

## Contributing

1. Fork it ( https://github.com/[my-github-username]/pester/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
