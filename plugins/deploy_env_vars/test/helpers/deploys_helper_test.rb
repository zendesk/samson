require_relative "../test_helper"

SingleCov.covered!

describe DeploysHelper do

  let(:deploy) { deploys(:succeeded_test) }

  # Standard redeploy button tests
  describe "#redeploy_button" do
    let(:redeploy_warning) { "Why? This deploy succeeded." }

    before do
      @deploy = deploy
      @project = projects(:test)
    end

    # Copy and paste default tests to ensure we are not modifying any functionlity
    # when there is no deploy env vars
    context "with no deploy environment vars" do
      it "generates a link" do
        link = redeploy_button
        link.must_include redeploy_warning # warns about redeploying
        link.must_include "?deploy%5Bkubernetes_reuse_build%5D=false" \
          "&amp;deploy%5Bkubernetes_rollback%5D=true&amp;deploy%5Breference%5D=staging\"" # copies params
        link.must_include "Redeploy"
      end

      it 'does not generate a link when deploy is active' do
        deploy.job.stubs(active?: true)
        redeploy_button.must_be_nil
      end

      it "generates a red link when deply failed" do
        deploy.stubs(succeeded?: false)
        redeploy_button.must_include "btn-danger"
        redeploy_button.wont_include redeploy_warning
      end
    end

    context "with deploy environment vars" do
      before do
        deploy.environment_variables << EnvironmentVariable.create(
          name: "DEPLOY_VARIABLE",
          value: "AN_EXAMPLE_VALUE"
        )
      end

      let(:href)   { /href=\"([^"]*)\"/.match(redeploy_button)[1] }
      let(:uri)    { URI.parse(URI.decode(href)) }
      let(:params) { CGI.parse(uri.query).to_a }

      it "generates a link with the environment variables and the rest of params" do
        params.must_include(
          ["deploy[environment_variables_attributes][][name]", ["DEPLOY_VARIABLE"]]
        )
        params.must_include(
          ["deploy[environment_variables_attributes][][value]", ["AN_EXAMPLE_VALUE"]]
        )
        params.must_include(
          ["deploy[environment_variables_attributes][][scope_type_and_id]", [""]]
        )
        params.must_include(
          ["deploy[kubernetes_reuse_build]", ["false"]]
        )
        params.must_include(
          ["deploy[kubernetes_rollback]", ["true"]]
        )
        params.must_include(
          ["deploy[reference]", ["staging"]]
        )
      end
    end

    context "invalid deploy params" do
      before do
        Samson::Hooks.callback :deploy_permitted_params do
          [['invalid_array_params'], {'invalid_hash' => 'one'}]
        end
      end

      it "generates a link and the invalid params are ignored" do
        link = redeploy_button
        link.must_include "?deploy%5Bkubernetes_reuse_build%5D=false" \
          "&amp;deploy%5Bkubernetes_rollback%5D=true&amp;deploy%5Breference%5D=staging\""
      end
    end
  end
end
