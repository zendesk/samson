module Executor
  class Base
    attr_reader :callbacks

    def initialize
      @callbacks = {
        :stdout => [],
        :stderr => []
      }
    end

    def output(&block)
      @callbacks[:stdout] << block
    end

    def error_output(&block)
      @callbacks[:stderr] << block
    end

    def execute!(*commands)
      raise ArgumentError, 'must be implemented'
    end
  end
end
