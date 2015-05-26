module Samson
  class JobInterpreters
    include Singleton

    attr_reader :interpreters

    def initialize
      @interpreters = []
      register Samson::JobShellScript
    end

    def register(interpreter_klass)
      raise 'Interpreter should implement the class method "display_name"' unless defined? interpreter_klass.display_name
      @interpreters << interpreter_klass unless @interpreters.include?(interpreter_klass)
    end

    def select_options
      @interpreters.map { |interpreter| [interpreter.display_name, interpreter] }
    end
  end
end
