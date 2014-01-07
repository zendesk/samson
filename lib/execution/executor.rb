module Execution
  class Base
    def initialize
      @callbacks = {
        :stdout => [],
        :stderr => [],
        :process => []
      }
    end

    def output(&block)
      @callbacks[:stdout] << block
    end

    def error_output(&block)
      @callbacks[:stderr] << block
    end

    def process(&block)
      @callbacks[:process] << block
    end

    def execute!(*commands)
      raise ArgumentError, 'must be implemented'
    end
  end
end
