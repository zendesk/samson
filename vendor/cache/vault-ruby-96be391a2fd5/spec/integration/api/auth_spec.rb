require "spec_helper"
require "aws-sigv4"

module Vault
  describe Auth do
    subject { vault_test_client }

    describe "#token" do
      before do
        subject.token = nil
      end

      it "verifies the token and saves it on the client" do
        token = RSpec::VaultServer.token
        subject.auth.token(token)
        expect(subject.token).to eq(token)
      end

      it "raises an error if the token is invalid" do
        expect {
          expect {
            subject.auth.token("nope-not-real")
          }.to raise_error(HTTPError)
        }.to_not change(subject, :token)
      end
    end

    describe "#app_id" do
      before(:context) do
        @app_id  = "aeece56e-3f9b-40c3-8f85-781d3e9a8f68"
        @user_id = "3b87be76-95cf-493a-a61b-7d5fc70870ad"

        vault_test_client.sys.enable_auth("app-id", "app-id", nil)
        vault_test_client.logical.write("auth/app-id/map/app-id/#{@app_id}", { value: "default" })
        vault_test_client.logical.write("auth/app-id/map/user-id/#{@user_id}", { value: @app_id })

        vault_test_client.sys.enable_auth("new-app-id", "app-id", nil)
        vault_test_client.logical.write("auth/new-app-id/map/app-id/#{@app_id}", { value: "default" })
        vault_test_client.logical.write("auth/new-app-id/map/user-id/#{@user_id}", { value: @app_id })
      end

      before do
        subject.token = nil
      end

      it "authenticates and saves the token on the client" do
        result = subject.auth.app_id(@app_id, @user_id)
        expect(subject.token).to eq(result.auth.client_token)
      end

      it "authenticates with custom options" do
        result = subject.auth.app_id(@app_id, @user_id, mount: "new-app-id")
        expect(subject.token).to eq(result.auth.client_token)
      end

      it "raises an error if the authentication is bad" do
        expect {
          expect {
            subject.auth.app_id("nope", "bad")
          }.to raise_error(HTTPError)
        }.to_not change(subject, :token)
      end
    end

    describe "#approle", vault: ">= 0.6.1" do
      before(:context) do
        @approle  = "sample-role-name"
        vault_test_client.sys.enable_auth("approle", "approle", nil)
      end

      after(:context) do
        vault_test_client.sys.disable_auth("approle")
      end

      before do
        subject.token = nil
      end

      context "when approle has default settings" do
        before(:context) do
          vault_test_client.approle.set_role(@approle)
          @role_id = vault_test_client.approle.role_id(@approle)
          @secret_id = vault_test_client.approle.create_secret_id(@approle).data[:secret_id]
        end

        after(:context) do
          vault_test_client.approle.delete_role(@approle)
        end

        it "authenticates and saves the token on the client" do
          result = subject.auth.approle(@role_id, @secret_id)
          expect(subject.token).to eq(result.auth.client_token)
        end

        it "raises an error if the authentication is bad" do
          expect {
            expect {
              subject.auth.approle("nope", "bad")
            }.to raise_error(HTTPError)
          }.to_not change(subject, :token)
        end
      end

      context "when approle has 'bind_secret_id' disabled" do
        before(:context) do
          opts = {
            bind_secret_id: false,
            bound_cidr_list: "127.0.0.1/32"
          }
          vault_test_client.approle.set_role(@approle, opts)
          @role_id = vault_test_client.approle.role_id(@approle)
        end

        after(:context) do
          vault_test_client.approle.delete_role(@approle)
        end

        it "authenticates w/o secret_id and saves the token on the client" do
          result = subject.auth.approle(@role_id)
          expect(subject.token).to eq(result.auth.client_token)
        end
      end
    end

    describe "#userpass" do
      before(:context) do
        @username = "sethvargo"
        @password = "s3kr3t"

        vault_test_client.sys.enable_auth("userpass", "userpass", nil)
        vault_test_client.logical.write("auth/userpass/users/#{@username}", { password: @password, policies: "default" })

        vault_test_client.sys.enable_auth("new-userpass", "userpass", nil)
        vault_test_client.logical.write("auth/new-userpass/users/#{@username}", { password: @password, policies: "default" })
      end

      before do
        subject.token = nil
      end

      it "authenticates and saves the token on the client" do
        result = subject.auth.userpass(@username, @password)
        expect(subject.token).to eq(result.auth.client_token)
      end

      it "authenticates with custom options" do
        result = subject.auth.userpass(@username, @password, mount: "new-userpass")
        expect(subject.token).to eq(result.auth.client_token)
      end

      it "raises an error if the authentication is bad" do
        expect {
          expect {
            subject.auth.userpass("nope", "bad")
          }.to raise_error(HTTPError)
        }.to_not change(subject, :token)
      end
    end

    describe "#tls" do
      before(:context) do
        vault_test_client.sys.enable_auth("cert", "cert", nil)
      end

      after(:context) do
        vault_test_client.sys.disable_auth("cert")
      end

      let!(:old_token) { subject.token }

      let(:certificate) do
        {
          display_name: "sample-cert",
          certificate:   RSpec::SampleCertificate.cert,
          policies:      "default",
          ttl:           3600,
        }
      end

      let(:auth_cert) { RSpec::SampleCertificate.cert << RSpec::SampleCertificate.key }

      after do
        subject.token = old_token
      end

      it "authenticates and saves the token on the client" do
        pending "dev server does not support tls"

        subject.auth_tls.set_certificate("kaelumania", certificate)

        result = subject.auth.tls(auth_cert)
        expect(subject.token).to eq(result.auth.client_token)
      end

      it "authenticates with default ssl_pem_file" do
        pending "dev server does not support tls"

        subject.auth_tls.set_certificate("kaelumania", certificate)
        subject.ssl_pem_file = auth_cert

        result = subject.auth.tls
        expect(subject.token).to eq(result.auth.client_token)
      end

      it "raises an error if the authentication is bad", vault: "> 0.6.1" do
        subject.sys.disable_auth("cert")

        expect {
          expect {
            subject.auth.tls(auth_cert)
          }.to raise_error(HTTPError)
        }.to_not change { subject.token }
      end
    end

    describe "#aws_iam", vault: "> 0.7.3" do
      before(:context) do
        vault_test_client.sys.enable_auth("aws", "aws", nil)
        vault_test_client.post("/v1/auth/aws/config/client", JSON.fast_generate("iam_server_id_header_value" => "iam_header_canary"))
      end

      after(:context) do
        vault_test_client.sys.disable_auth("aws")
      end

      let!(:old_token) { subject.token }
      let(:credentials_provider) do
        double(
          credentials:
            double(access_key_id: 'very', secret_access_key: 'secure', session_token: 'thing')
        )
      end
      let(:secret) { double(auth: double(client_token: 'a great token')) }

      after do
        subject.token = old_token
      end

      it "does not authenticate if iam_server_id_header_value does not match" do
        expect(::Aws::Sigv4::Signer).to(
          receive(:new).with(
            service: 'sts', region: 'cn-north-1', credentials_provider: credentials_provider
          ).and_call_original
        )
        expect do
          subject.auth.aws_iam('a_rolename', credentials_provider, 'mismatched_iam_header', 'https://sts.cn-north-1.amazonaws.com.cn') 
        end.to raise_error(Vault::HTTPClientError, /expected "?iam_header_canary"? but got "?mismatched_iam_header"?/)
      end

      it "authenticates and saves the token on the client" do
        expect(subject).to receive(:post).and_return 'huzzah!'
        expect(Secret).to receive(:decode).and_return secret
        expect(::Aws::Sigv4::Signer).to(
          receive(:new).with(
            service: 'sts', region: 'cn-north-1', credentials_provider: credentials_provider
          ).and_call_original
        )
        subject.auth.aws_iam('a_rolename', credentials_provider, 'iam_header_canary', 'https://sts.cn-north-1.amazonaws.com.cn')
      end
    end

    describe "#gcp", vault: ">= 0.8.1" do
      before(:context) do
        skip "gcp auth requires real resources and keys"

        vault_test_client.sys.enable_auth("gcp", "gcp", nil)
        vault_test_client.post("/v1/auth/gcp/config", JSON.fast_generate("service_account" => "rspec_service_account"))
        vault_test_client.post("/v1/auth/gcp/role/rspec_wrong_role", JSON.fast_generate("name" => "rspec_role", "project_id" => "wrong_project_id", "bound_service_accounts" => "\*", "type" => "iam"))
        vault_test_client.post("/v1/auth/gcp/role/rspec_role", JSON.fast_generate("name" => "rspec_role", "project_id" => "project_id", "bound_service_accounts" => "\*", "type" => "iam"))
      end

      after(:context) do
        vault_test_client.sys.disable_auth("gcp")
      end

      let!(:old_token) { subject.token }

      let(:jwt) do
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJwcm9qZWN0X2lkIjoicHJvamVjdF9pZCJ9.TmuiSHtbLMZuw_LOzKWQ2vnC7BUvu2b4CeBXdxCDCXQ"
      end

      after do
        subject.token = old_token
      end

      it "does not authenticate if project_id does not match" do
        pending "gcp auth requires real resources and keys"

        expect do
          subject.auth.gcp("rspec_wrong_role", jwt)
        end.to raise_error(Vault::HTTPClientError, /project_id doesn't match/)
      end

      it "authenticates and saves the token on the client" do
        pending "gcp auth requires real resources and keys"

        subject.auth.gcp("rspec_role", jwt)
      end
    end
  end
end
