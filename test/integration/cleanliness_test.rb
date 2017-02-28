# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.not_covered!

# kitchen sink for 1-off tests
describe "cleanliness" do
  def assert_content(files)
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

  it "does not have 3-state booleans (nil/false/true)" do
    bad = File.read("db/schema.rb").scan(/\st\.boolean.*/).reject { |l| l .include?(" null: false") }
    assert bad.empty?, "Boolean columns missing a default or null: false\n#{bad.join("\n")}"
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

  it "does not have public actions on base controller" do
    found = ApplicationController.action_methods.to_a
    found.reject! { |a| a =~ /^(_conditional_callback_around_|_callback_before_)/ }
    (found - ["flash"]).must_equal []
  end

  it "enforces coverage" do
    SingleCov.assert_used tests: all_tests
  end

  it "does not use setup/teardown" do
    assert_content all_tests do |content|
      if content =~ /^\s+(setup|teardown)[\s\{]/
        "uses setup or teardown, but should use before or after"
      end
    end
  end

  it "uses active test case wording" do
    assert_content all_tests do |content|
      if content =~ /\s+it ['"]should /
        "uses `it should` working, please use active working `it should activate` -> `it activates`"
      end
    end
  end

  it "does not have trailing whitespace" do
    assert_content Dir["{app,lib,plugins,test}/**/*.rb"] do |content|
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
    SingleCov.assert_tested(
      files: Dir['{,plugins/*/}{app,lib}/**/*.rb'],
      tests: all_tests
    )
  end

  it "has same version in .ruby-version and lock to make herku not crash" do
    File.read('Gemfile.lock').must_include File.read('.ruby-version').strip
  end

  it "has page title for all views" do
    views = Dir['{,plugins/*/}app/views/**/*.html.erb'].
      reject { |v| File.basename(v).start_with?('_') }.
      reject { |v| v.include?('_mailer/') }.
      reject { |v| v.include?('/layouts/') }
    assert_content views do |content|
      unless content.include?(' page_title')
        "declare a page title for nicer navigation"
      end
    end
  end

  it "does not modify the ENV without resetting state" do
    assert_content all_tests do |content|
      if content =~ /ENV\[.*=/
        "use with_env to setup ENV variables during test"
      end
    end
  end

  # tests multi_thread_db_detector.rb
  it "blows up when using database from a different thread" do
    e = assert_raises RuntimeError do
      Thread.new { User.first }.join
    end
    e.message.must_include "Using AR outside the main thread"
  end

  it "has a Readme for each plugin" do
    Dir["plugins/*"].size.must_equal Dir["plugins/*/*"].grep(/\/README\.md\z/).size
  end

  it "links every plugin in docs" do
    readme_path = 'docs/plugins.md'
    readme = File.read(readme_path)
    plugins = Dir['plugins/*'].map { |f| File.basename(f) } - ['samson_ledger', *ENV['PRIVATE_PLUGINS'].to_s.split(',')]
    plugins.each do |plugin_name|
      assert(
        readme.include?("https://github.com/zendesk/samson/tree/master/plugins/#{plugin_name}"),
        "#{readme_path} must include link to #{plugin_name}"
      )
    end
  end

  it "uses whitelists for authorization so new actions ar restricted by default" do
    controllers = Dir["{,plugins/*/}app/controllers/**/*.rb"]
    controllers.size.must_be :>, 50
    assert_content controllers do |content|
      if content =~ /before_action\s+:authorize_.*only:/
        "do not use authorization filters with :only, use :except"
      end
    end
  end

  # If a controller only tests `as_a_admin { get :index }` then we don't know if authentification
  # logic properly works, so all actions have to be tested as unauthenticated or as public/viewer level
  # for example: as_a_deployer { unauthenticated :get, :index } + as_a_admin { get :index } is good.
  it "checks authentication levels for all actions" do
    controller_tests = Dir["{,plugins/*/}test/controllers/**/*_test.rb"] - [
      'test/controllers/api/base_controller_test.rb',
      'test/controllers/application_controller_test.rb',
      'test/controllers/doorkeeper_base_controller_test.rb',
      'test/controllers/unauthorized_controller_test.rb',
    ]
    controller_tests.reject! { |c| c =~ %r{/(integrations|concerns)/} }

    controller_tests.size.must_be :>, 50 # make sure splat works correctly

    bad = controller_tests.map do |f|
      # find all actions in the controller
      controller = f.sub('test/', 'app/').sub('_test.rb', '.rb')
      public_section = File.read(controller).split(/  (protected|private)$/).first
      controller_actions = public_section.scan(/def ([\w_]+)/).flatten - ['self']
      raise "No actions in #{f} !?" if controller_actions.empty?

      # find all actions tested to be unauthorized, viewer accessible, or public accessible
      test = File.read(f)
      action_pattern = /\s(?:get|post|put|patch|delete)\s+:([\w_]+)/

      unauthorized_actions = test.scan(/^\s+unauthorized\s+(?:\S+),\s+:([\w_]+)/).flatten

      viewer_block = test[/^  as_a_viewer.*?^  end/m].to_s
      viewer_actions = viewer_block.scan(action_pattern).flatten

      public_actions = test.scan(/^  describe.*?^  end/m).map { |section| section.scan(action_pattern) }.flatten

      # check if all actions were tested
      missing = controller_actions - unauthorized_actions - viewer_actions - public_actions
      if missing.any?
        "#{f} is missing unauthorized, viewer accessible, or public accessible test for #{missing.join(', ')}"
      end
    end.compact

    assert bad.empty?, bad.join("\n")
  end
end
