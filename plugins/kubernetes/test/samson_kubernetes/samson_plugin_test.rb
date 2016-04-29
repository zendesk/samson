require_relative "../test_helper"

SingleCov.covered! uncovered: 2 unless defined?(Rake) # rake preloads all plugins

describe SamsonKubernetes do
  describe :stage_permitted_params do
    it "adds :kubernetes" do
      Samson::Hooks.fire(:stage_permitted_params).must_include :kubernetes
    end
  end
end
