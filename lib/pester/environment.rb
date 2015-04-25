module Pester
  class Environment
    attr_accessor :options

    def initialize(opts)
      @options = opts
    end

    def method_missing(name, *args, &block)
      if name.to_s.start_with?('retry') && args.empty?
        Pester.send(name, @options, &block)
      else
        super
      end
    end
  end
end
