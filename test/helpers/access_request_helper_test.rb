# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe AccessRequestHelper do
  include AccessRequestTestSupport

  describe '#display_access_request_link?' do
    around { |t| enable_access_request &t }
    before { stubs(current_user: users(:viewer)) }

    it 'returns true for underpriviledged user' do
      assert display_access_request_link?
    end

    it 'returns false not logged in' do
      stubs(current_user: nil)
      refute display_access_request_link?
    end

    it 'returns false for users that cannot get more permissions' do
      stubs(current_user: users(:super_admin))
      refute display_access_request_link?
    end

    it 'returns false when disabled' do
      with_env REQUEST_ACCESS_FEATURE: nil do
        refute display_access_request_link?
      end
    end
  end

  describe '#link_to_request_access' do
    let(:current_user) { users(:viewer) }
    let(:matcher) { %r{<a href="/access_requests/new">.*</a>} }

    it 'shows a link if there is no request pending' do
      current_user.update!(access_request_pending: false)
      assert_match(matcher, link_to_request_access)
    end

    it 'does not show a link if a request is pending' do
      current_user.update!(access_request_pending: true)
      refute_match(matcher, link_to_request_access)
    end
  end

  describe '#access_request_alternative_instruction' do
    let(:instructions) { "contact an admin" }

    it 'returns text set in ENV["ACCESS_REQUEST_ALTERNATIVE_INSTRUCTION"]' do
      with_env ACCESS_REQUEST_ALTERNATIVE_INSTRUCTION: instructions do
        assert_match(instructions, access_request_alternative_instruction)
      end
    end
  end
end
