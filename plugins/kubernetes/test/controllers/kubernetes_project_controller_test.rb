require_relative '../test_helper'

describe KubernetesProjectController do
  let(:project) { projects(:test) }
  let(:environment) { environments(:production) }

  as_a_project_deployer do
    describe 'a GET to #show' do
      it_responds_successfully do
        get :show, id: project.permalink
        assert_template :show
      end
    end
  end
end
