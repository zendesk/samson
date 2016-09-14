module HandlesDockerOutput
  def handle_output_chunk(chunk, output)
    # TODO: add some sort of encoding magic to make sure we don't blow up
    # if the docker output isn't in UTF-8.
    parsed_chunk = JSON.parse(chunk)

    # Don't bother printing all the incremental output when pulling images
    unless parsed_chunk['progressDetail']
      values = parsed_chunk.map { |k, v| "#{k}: #{v}" if v.present? }.compact
      output.puts values.join(' | ')
    end

    parsed_chunk
  rescue JSON::ParserError
    # Sometimes the JSON line is too big to fit in one chunk, so we get
    # a chunk back that is an incomplete JSON object.
    output.puts chunk
    { 'message' => chunk }
  end
end
