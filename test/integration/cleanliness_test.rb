require_relative '../test_helper'

SingleCov.not_covered!

# kitchen sink for 1-off tests
describe "cleanliness" do
  def check_content(files)
    files -= [File.expand_path(__FILE__).sub("#{Rails.root}/", '')]
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
    found.reject { |a| a =~ /^(_conditional_callback_around_|_callback_before_)/ }
    (found - ["flash"]).must_equal []
  end

  it "enforces coverage" do
    SingleCov.assert_used tests: all_tests
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

  it "does not have accidental .rb files" do
    helpers = Dir["{test,plugins/*/test}/**/*.rb"]
    helpers.reject! { |f| f.end_with?('_test.rb') }
    helpers.reject! { |f| f.include?('/support/') }
    helpers.reject! { |f| f.include?('_mailer_preview.rb') }
    helpers.map! { |f| File.basename(f) }
    helpers.uniq.must_equal ['test_helper.rb']
  end

  it "tests all files" do
    untested = [
      "app/controllers/application_controller.rb",
      "app/controllers/concerns/current_project.rb",
      "app/controllers/concerns/stage_permitted_params.rb",
      "app/mailers/application_mailer.rb",
      "app/models/changeset/code_push.rb",
      "app/models/changeset/issue_comment.rb",
      "app/models/changeset/jira_issue.rb",
      "app/models/concerns/has_commands.rb",
      "app/models/concerns/has_role.rb",
      "app/models/concerns/searchable.rb",
      "lib/generators/plugin/plugin_generator.rb",
      "lib/generators/plugin/templates/test_helper.rb",
      "lib/samson/integration.rb",
      "lib/warden/strategies/basic_strategy.rb",
      "lib/warden/strategies/session_strategy.rb",
      "plugins/env/app/models/concerns/accepts_environment_variables.rb",
      "plugins/env/app/models/environment_variable_group.rb",
      "plugins/env/app/models/project_environment_variable_group.rb",
      "plugins/kubernetes/app/decorators/admin/deploy_groups_controller_decorator.rb",
      "plugins/kubernetes/app/decorators/build_decorator.rb",
      "plugins/kubernetes/app/decorators/deploy_group_decorator.rb",
      "plugins/kubernetes/app/decorators/environment_decorator.rb",
      "plugins/kubernetes/app/models/concerns/kubernetes/api/deleted_pod.rb",
      "plugins/kubernetes/app/models/concerns/kubernetes/api/failed_pod.rb",
      "plugins/kubernetes/app/models/concerns/kubernetes/deploy_group_permitted_params.rb",
      "plugins/kubernetes/app/models/concerns/kubernetes/has_status.rb",
      "plugins/kubernetes/app/models/kuber_deploy_service.rb",
      "plugins/kubernetes/app/models/kubernetes/cluster_deploy_group.rb",
      "plugins/kubernetes/app/models/kubernetes/service.rb",
      "plugins/kubernetes/app/models/watchers/base_cluster_watcher.rb",
      "plugins/kubernetes/app/models/watchers/cluster_pod_error_watcher.rb",
      "plugins/kubernetes/app/models/watchers/events/cluster_event.rb",
      "plugins/kubernetes/app/models/watchers/events/kubernetes_event.rb",
      "plugins/kubernetes/app/models/watchers/events/pod_event.rb",
      "plugins/kubernetes/app/models/watchers/topic_subscription.rb",
      "plugins/kubernetes/app/serializers/kubernetes/release_doc_serializer.rb",
      "plugins/kubernetes/app/serializers/kubernetes/release_serializer.rb",
      "plugins/pipelines/app/models/concerns/samson_pipelines/stage_concern.rb"
    ]

    SingleCov.assert_tested(
      files: Dir['{,plugins/*/}{app,lib}/**/*.rb'],
      tests: all_tests,
      untested: untested
    )
  end
end
