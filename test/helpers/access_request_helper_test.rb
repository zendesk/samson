# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe AccessRequestHelper do
  include AccessRequestTestSupport

  describe '#display_access_request_link?' do
    around { |t| enable_access_request &t }

    describe 'feature enabled' do
      describe 'not authed' do
        let(:current_user) { nil }

        it 'returns false' do
          refute display_access_request_link?
        end
      end

      describe 'viewer user' do
        let(:current_user) { users(:viewer) }

        it 'returns true for authorization_error' do
          assert display_access_request_link?(:authorization_error)
        end

        it 'returns true for default params' do
          assert display_access_request_link?
        end

        it 'returns false for other flash types' do
          refute display_access_request_link?(:success)
        end
      end

      describe 'super_admin user' do
        let(:current_user) { users(:super_admin) }

        it 'returns false for super_admin' do
          refute display_access_request_link?
        end
      end
    end

    describe 'feature disabled' do
      with_env REQUEST_ACCESS_FEATURE: nil

      it 'returns false for all flash types' do
        refute display_access_request_link?(:authorization_error)
        refute display_access_request_link?(:success)
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
end
