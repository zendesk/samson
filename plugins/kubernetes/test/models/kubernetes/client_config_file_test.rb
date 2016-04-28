require_relative "../../test_helper"

SingleCov.covered! uncovered: 39

describe Kubernetes::ClientConfigFile do
  describe "#initialize" do
    it "fails with missing file" do
      assert_raises ArgumentError do
        Kubernetes::ClientConfigFile.new('oops')
      end
    end

    it "reads a good file" do
      with_example_kube_config do |f|
        Kubernetes::ClientConfigFile.new(f)
      end
    end

    it "reads a file with home" do
      with_example_kube_config do |f|
        home = File.dirname(f)
        f = "~/#{File.basename(f)}"
        with_env HOME: home do
          Kubernetes::ClientConfigFile.new(f)
        end
      end
    end
  end
end

