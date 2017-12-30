# frozen_string_literal: true
ActiveSupport::TestCase.class_eval do
  def assert_request(method, path, options = {})
    if options[:to_return].is_a?(Array) && !options[:times]
      options = options.merge(times: options[:to_return].size)
    end
    request = stub_request(method, path)
    assertion_options = options.slice!(:to_timeout, :to_return, :with, :to_raise)

    request = options.each_with_object(request) do |(k, v), r|
      case v
      when Array then r.public_send(k, *v)
      when Proc then r.public_send(k, &v)
      else r.public_send(k, v)
      end
    end

    yield

    assert_requested request, assertion_options
  end

  def stub_github_api(url, response = {}, status = 200)
    url = 'https://api.github.com/' + url
    stub_request(:get, url).to_return(
      status: status,
      body: JSON.dump(response),
      headers: { 'Content-Type' => 'application/json' }
    )
  end
end
