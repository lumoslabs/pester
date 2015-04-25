module Pester
  class Config
    class << self
      attr_reader :environments
      attr_writer :logger

      def configure
        yield self
      end

      def environments
        @environments ||= {}
      end

      def logger
        require 'logger' unless defined? Logger
        @logger ||= Logger.new(STDOUT)
      end
    end
  end
end
