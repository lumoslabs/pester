module Pester
  module Behaviors
    WarnAndReraise = lambda do |logger, max_attempts, e|
      logger.warn("Max # of retriable exceptions (#{max_attempts}) exceeded, re-raising. Context: #{e}. Trace: #{e.backtrace}")
      raise
    end
  end
end
