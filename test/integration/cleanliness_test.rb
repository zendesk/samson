require_relative '../test_helper'

SingleCov.not_covered!

# kitchen sink for 1-off tests
describe "cleanliness" do
  def check_content(files)
    files -= [__FILE__.sub("#{Rails.root}/", '')]
    bad = files.map do |f|
      error = yield File.read(f)
      "#{f}: #{error}" if error
    end.compact
    assert bad.empty?, bad.join("\n")
  end

  let(:all_tests) { Dir["{,plugins/*/}test/**/*_test.rb"] }

  it "does not have boolean limit 1 in schema since this breaks mysql" do
    File.read("db/schema.rb").wont_match /\st\.boolean.*limit: 1/
  end

  it "does not include rails-assets-bootstrap" do
    # make sure rails-assets-bootstrap did not get included by accident (dependency of some other bootstrap thing)
    # if it is not avoidable see http://stackoverflow.com/questions/7163264
    File.read('Gemfile.lock').wont_include 'rails-assets-bootstrap '
  end

  if ENV['USE_UTF8MB4'] && ActiveRecord::Base.connection.adapter_name == "Mysql2"
    it "uses the right row format in mysql" do
      status = ActiveRecord::Base.connection.execute('show table status').to_a
      refute_empty status
      status.each do |table|
        table[3].must_equal "Dynamic"
      end
    end
  end

  it "does not use let(:user) inside of a as_xyz block" do
    check_content all_tests do |content|
      if content.include?("  as_") && content.include?("let(:user)")
        "uses as_xyz and let(:user) these do not mix!"
      end
    end
  end

  it "does not have actions on base controller" do
    found = ApplicationController.action_methods.to_a
    found.reject { |a| a =~ /^(_conditional_callback_around_|_callback_before_)/ } - ["flash"]
    found.must_equal []
  end

  it "has coverage" do
    SingleCov.assert_used files: all_tests
  end

  it "does not use setup/teardown" do
    check_content all_tests do |content|
      if content =~ /^\s+(setup|teardown)[\s\{]/
        "uses setup or teardown, but should use before or after"
      end
    end
  end

  it "uses active test case wording" do
    check_content all_tests do |content|
      if content =~ /\s+it ['"]should /
        "uses `it should` working, please use active working `it should activate` -> `it activates`"
      end
    end
  end

  it "does not have trailing whitespace" do
    check_content Dir["{app,lib,plugins,test}/**/*.rb"] do |content|
      "has trailing whitespace" if content =~ / $/
    end
  end

  it "tests all files" do
    known_missing = [
      "test/controllers/application_controller_test.rb",
      "test/controllers/concerns/authorization_test.rb",
      "test/controllers/concerns/current_project_test.rb",
      "test/controllers/concerns/current_user_test.rb",
      "test/controllers/concerns/stage_permitted_params_test.rb",
      "test/helpers/builds_helper_test.rb",
      "test/helpers/date_time_helper_test.rb",
      "test/helpers/deploys_helper_test.rb",
      "test/helpers/flash_helper_test.rb",
      "test/helpers/jobs_helper_test.rb",
      "test/helpers/sessions_helper_test.rb",
      "test/helpers/webhooks_helper_test.rb",
      "test/mailers/application_mailer_test.rb",
      "test/models/changeset/code_push_test.rb",
      "test/models/changeset/issue_comment_test.rb",
      "test/models/changeset/jira_issue_test.rb",
      "test/models/concerns/has_commands_test.rb",
      "test/models/concerns/has_role_test.rb",
      "test/models/concerns/searchable_test.rb",
      "test/models/datadog_notification_test.rb",
      "test/models/deploy_groups_stage_test.rb",
      "test/models/job_service_test.rb",
      "test/models/job_viewers_test.rb",
      "test/models/macro_command_test.rb",
      "test/models/new_relic_test.rb",
      "test/models/new_relic_application_test.rb",
      "test/models/null_user_test.rb",
      "test/models/restart_signal_handler_test.rb",
      "test/models/role_test.rb",
      "test/models/stage_command_test.rb",
      "test/models/star_test.rb",
      "test/serializers/build_serializer_test.rb",
      "test/serializers/deploy_serializer_test.rb",
      "test/serializers/project_serializer_test.rb",
      "test/serializers/stage_serializer_test.rb",
      "test/serializers/user_serializer_test.rb",
      "test/lib/generators/plugin/plugin_generator_test.rb",
      "test/lib/generators/plugin/templates/test_helper_test.rb",
      "test/lib/samson/integration_test.rb",
      "test/lib/warden/strategies/basic_strategy_test.rb",
      "test/lib/warden/strategies/session_strategy_test.rb"
    ]

    expected_tests = (
      Dir['app/**/*.rb'].map { |f| [f, f.sub('app/', 'test/').sub('.rb', '_test.rb')] } +
      Dir['lib/**/*.rb'].map { |f| [f, f.sub('lib/', 'test/lib/').sub('.rb', '_test.rb')] }
    )
    missing = expected_tests.reject { |_, t| all_tests.include?(t) }

    if fixed = (known_missing - missing.map(&:last)).presence
      raise "Remove #{fixed.inspect} from known_missing!"
    else
      missing.reject! { |_, t| known_missing.include?(t) }
      assert missing.empty?, missing.map { |f, t| "missing test for #{f} at #{t}" }.join("\n")
    end
  end
end
