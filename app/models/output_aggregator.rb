# Reads and aggregates a stream of terminal output events.
class OutputAggregator
  def initialize(output)
    @output = output
  end

  def each
    scanner = TerminalOutputScanner.new(@output)
    log = []

    scanner.each do |event, data|
      next unless [:replace, :append].include?(event)

      log.pop if event == :replace
      log.push(data)
      yield log.join
    end
  end
end
