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

      it "renders" do
        assert_template :new
      end
    end
  end

  describe "a POST to #github" do
    let(:env) {{}}
    let(:user) { users(:github_viewer) }
    let(:strategy) { stub(name: 'github') }
    let(:auth_hash) do
      Hashie::Mash.new(
        uid: '3',
        info: Hashie::Mash.new(
          name: user.name,
          email: user.email
        )
      )
    end

    setup do
      @controller.stubs(github_authorization: stub(role_id: Role::VIEWER.id))
      @controller.stubs(:restricted_email_domain).returns(nil) 

      @request.env.merge!(env)
      @request.env.merge!('omniauth.auth' => auth_hash)
      @request.env.merge!('omniauth.strategy' => strategy)

      post :github
    end

    it 'logs the user in' do
      @controller.current_user.must_equal(user)
    end

    it 'redirects to the root path' do
      assert_redirected_to root_path
    end

    describe 'with an origin' do
      let(:env) {{ 'omniauth.origin' => '/hello' }}

      it 'redirects to /hello' do
        assert_redirected_to '/hello'
      end
    end
  end

  describe "a POST to #github with email restriction" do
    let(:env) {{}}
    let(:user) { users(:github_viewer) }
    let(:strategy) { stub(name: 'github') }
    let(:auth_hash) do
      Hashie::Mash.new(
        uid: '3',
        info: Hashie::Mash.new(
          name: user.name,
          email: user.email
        )
      )
    end

    setup do
      @controller.stubs(github_authorization: stub(role_id: Role::VIEWER.id))
      @controller.stubs(:restricted_email_domain).returns("@uniqlo.com") 

      @request.env.merge!(env)
      @request.env.merge!('omniauth.auth' => auth_hash)
      @request.env.merge!('omniauth.strategy' => strategy)

      post :github
    end

    it 'does not log the user in' do
      @controller.current_user.must_be_nil
    end

    it "renders" do
      assert_template :new
    end

    it "sets a flash error" do
      request.flash[:error].wont_be_nil
    end

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
