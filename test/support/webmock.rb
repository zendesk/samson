# frozen_string_literal: true
ActiveSupport::TestCase.class_eval do
  # TODO: does not work when asserting the same method/path twice in the same test but different blocks
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

    assert_args = [request, assertion_options]

    if block_given?
      result = yield
      assert_requested(*assert_args)
      remove_request_stub(request)
      result
    else
      raise "use assert_requests in the describe block" unless @assert_requests
      @assert_requests << assert_args
    end
  end

  def request_with_json(json)
    ->(r) { JSON.parse(r.body, symbolize_names: true) == json }
  end

  # TODO: prevent this getting called twice in the same test ... leads to weird bugs
  def self.assert_requests
    before { @assert_requests = [] } # set here so we can check that users did not forget to set the block
    after { @assert_requests.each { |assert_args| assert_requested(*assert_args) } }
  end

  def stub_github_api(path, response = {}, status = 200)
    url = "https://api.github.com/#{path}"
    stub_request(:get, url).to_return(
      status: status,
      body: JSON.dump(response),
      headers: {'Content-Type' => 'application/json'}
    )
  end
end
