require_relative '../test_helper'

describe SessionsController do
  describe "a GET to #new" do
    describe "when logged in" do
      setup do
        request.env['warden'].set_user(users(:admin))
        get :new
      end

      it "redirects to the root url" do
        assert_redirected_to root_path
      end
    end

    describe "when not logged in" do
      setup do
        get :new
      end

      it "redirects to the auth url" do
        warden.status.must_equal(302)
        warden.headers['Location'].must_equal('/login')
      end
    end
  end

  describe "a POST to #github" do
    let(:user) { users(:viewer) }
    let(:teams) {[]}
    let(:config) { Rails.application.config.pusher.github }

    let(:access_token) { OAuth2::AccessToken.new(nil, 123) }
    let(:auth_hash) do
      Hashie::Mash.new(
        info: Hashie::Mash.new(
          name: user.name,
          email: user.email
        )
      )
    end

    def stub_github_api(url, response = {}, status = 200)
      url = 'https://api.github.com/' + url + '?access_token=123'
      stub_request(:get, url).to_return(
        status: status,
        body: JSON.dump(response),
        headers: { 'Content-Type' => 'application/json' }
      )
    end

    setup do
      @controller.stubs(strategy: Hashie::Mash.new(access_token: access_token))
      @controller.stubs(auth_hash: auth_hash)
      @controller.stubs(github_login: 'test.user')

      stub_github_api("orgs/#{config.organization}/teams", teams)

      teams.each do |team|
        stub_github_api("teams/#{team[:id]}/members/test.user", {}, team[:member] ? 204 : 404)
      end

      post :github
    end

    describe 'with no teams' do
      it 'keeps the user a viewer' do
        user.reload.role_id.must_equal(Role::VIEWER.id)
      end
    end

    describe 'with an admin team' do
      let(:teams) {[
        { id: 1, slug: config.admin_team, member: member? }
      ]}

      describe 'as a team member' do
        let(:member?) { true }

        it 'updates the user to admin' do
          user.reload.role_id.must_equal(Role::ADMIN.id)
        end
      end

      describe 'not a team member' do
        let(:member?) { false }

        it 'does not update the user to admin' do
          user.reload.role_id.must_equal(Role::VIEWER.id)
        end
      end
    end

    describe 'with a deploy team' do
      let(:teams) {[
        { id: 2, slug: config.deploy_team, member: member? }
      ]}

      describe 'as a team member' do
        let(:member?) { true }

        it 'updates the user to admin' do
          user.reload.role_id.must_equal(Role::DEPLOYER.id)
        end
      end

      describe 'not a team member' do
        let(:member?) { false }
        it 'does not update the user to admin' do
          user.reload.role_id.must_equal(Role::VIEWER.id)
        end
      end
    end

    describe 'with both teams' do
      let(:teams) {[
        { id: 1, slug: config.admin_team, member: true },
        { id: 2, slug: config.deploy_team, member: true }
      ]}

      it 'updates the user to admin' do
        user.reload.role_id.must_equal(Role::ADMIN.id)
      end
    end
  end

  describe 'a POST to #zendesk' do
  end

  describe "a GET to #failure" do
    setup do
      get :failure
    end

    it "redirects to the root url" do
      assert_redirected_to root_path
    end

    it "sets a flash error" do
      request.flash[:error].wont_be_nil
    end
  end

  describe "a DELETE to #destroy" do
    setup do
      login_as(users(:admin))
      delete :destroy
    end

    it "removes the user_id" do
      session.to_hash.except("flash").must_be_empty
    end

    it "redirects to the root url" do
      assert_redirected_to root_path
    end

    it "sets a flash notice" do
      request.flash[:notice].wont_be_nil
    end
  end
end
