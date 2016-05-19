module WebhooksHelper
  def webhook_sources(sources)
    [
      ['Any CI', 'any_ci'],
      ['Any code push', 'any_code'],
      ['Any Pull Request', 'any_pull_request'],
      ['Any', 'any']
    ] + sources.map { |source| [source.titleize, source] }.to_a
  end
end
