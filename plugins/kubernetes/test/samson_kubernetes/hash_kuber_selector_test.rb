require_relative "../test_helper"

SingleCov.covered! unless defined?(Rake) # rake preloads all plugins

describe 'hash decorator' do
  describe '#to_kuber_selector' do
    it 'works with equality' do
      { foo: 'bar' }.to_kuber_selector.must_equal 'foo=bar'
    end

    it 'works with sets' do
      { foo: %w[bar baz quux] }.to_kuber_selector.must_equal 'foo in (bar,baz,quux)'
    end

    it 'handles existence' do
      { foo: true }.to_kuber_selector.must_equal 'foo'
    end

    it 'handles negative values' do
      {
        not: { name: 'foobar', env: %w[staging production] }
      }.to_kuber_selector.must_equal 'name!=foobar,env notin (staging,production)'
    end

    it 'handles a combination' do
      {
        name: 'foobar',
        live: true,
        env: %w[staging production],
        not: {
          deploy: 'gamma'
        }
      }.to_kuber_selector.must_equal 'name=foobar,live,env in (staging,production),deploy!=gamma'
    end
  end
end
