require_relative 'test_helper'

describe "env hooks" do
  let(:deploy) { deploys(:succeeded_test) }
  let(:stage) { deploy.stage }
  let(:project) { stage.project }

  describe :after_deploy_setup do
    around { |test| Dir.mktmpdir { |dir| Dir.chdir(dir) { test.call } } }

    before do
      project.environment_variables.create!(name: "HELLO", value: "world")
      project.environment_variables.create!(name: "WORLD", value: "hello")
    end

    describe ".env" do
      describe "without groups" do
        before { stage.deploy_groups.delete_all }

        it "does not modify when no variables were specified" do
          EnvironmentVariable.delete_all
          File.exist?(".env").must_equal false
        end

        it "writes to .env" do
          Samson::Hooks.fire(:after_deploy_setup, Dir.pwd, stage)
          File.read(".env").must_equal "HELLO=\"world\"\nWORLD=\"hello\"\n"
        end

        it "overwrites .env by ignoring not required" do
          File.write(".env", "# a comment ...\nHELLO=foo")
          Samson::Hooks.fire(:after_deploy_setup, Dir.pwd, stage)
          File.read(".env").must_equal "HELLO=\"world\"\n"
        end

        it "fails when .env has an unsatisfied required key" do
          File.write(".env", "FOO=foo")
          assert_raises Samson::Hooks::UserError do
            Samson::Hooks.fire(:after_deploy_setup, Dir.pwd, stage)
          end
        end
      end

      describe "with deploy groups" do
        it "deletes the base file" do
          Samson::Hooks.fire(:after_deploy_setup, Dir.pwd, stage)
          File.read(".env.pod-100").must_equal "HELLO=\"world\"\nWORLD=\"hello\"\n"
          refute File.exist?(".env")
        end
      end
    end

    describe "with ENV.json" do
      before do
        File.write("ENV.json", JSON.dump("other" => true))
        File.write("manifest.json", JSON.dump(
          "settings" => {
            "HELLO" => {},
            "OTHER" => {},
            "MORE" => {"required" => true},
            "OPTIONAL" => {"required" => false}
          }
        ))
      end

      def fire
        Samson::Hooks.fire(:after_deploy_setup, Dir.pwd, stage)
      end

      it "does not modify when no variables were specified" do
        EnvironmentVariable.delete_all
        File.read("ENV.json").must_equal "{\"other\":true}"
      end

      it "fails when missing required keys" do
        assert_raises Samson::Hooks::UserError do
          fire
        end
      end

      it "writes deploy group specific env files" do
        stage.deploy_groups << deploy_groups(:pod1)

        env_group = EnvironmentVariableGroup.create!(
          environment_variables_attributes: {
            "0" => {name: "HELLO", value: "Y"}, # overwritten by stage setting
            "1" => {name: "OTHER", value: "A"},
            "2" => {name: "MORE", value: "A"}, # overwritten by specific setting
            "3" => {name: "MORE", value: "B", scope: deploy_groups(:pod100)},
            "4" => {name: "MORE", value: "C", scope: deploy_groups(:pod1)},
            "5" => {name: "OPTIONAL", value: "A"},
          },
          name: "G1"
        )
        project.environment_variable_groups << env_group

        fire

        refute File.exist?("ENV.json")

        File.read("ENV.pod-100.json").must_equal "{
  \"other\": true,
  \"env\": {
    \"HELLO\": \"world\",
    \"OTHER\": \"A\",
    \"MORE\": \"B\",
    \"OPTIONAL\": \"A\"
  }
}"
        File.read("ENV.pod1.json").must_equal "{
  \"other\": true,
  \"env\": {
    \"HELLO\": \"world\",
    \"OTHER\": \"A\",
    \"MORE\": \"C\",
    \"OPTIONAL\": \"A\"
  }
}"
      end
    end
  end
end
