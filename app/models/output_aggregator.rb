# Reads and aggregates a stream of terminal output events.
class OutputAggregator
  def initialize(output)
    @output = output
  end

  def to_s
    scanner = TerminalOutputScanner.new(@output)
    log = []

    scanner.each do |event, data|
      log.pop if event == :replace
      log.push(data)
    end

    log.join
  end
end
