# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.not_covered!

# kitchen sink for 1-off tests
describe "cleanliness" do
  def all_models
    roots = (Samson::Hooks.plugins.map(&:folder).map { |f| "#{f}/" } + [""])
    models = Dir["{#{roots.join(",")}}app/models/**/*.rb"].grep_v(/\/concerns\//)
    models.size.must_be :>, 20
    models.map! { |f| f.sub(/.*\/plugins\/[^\/]+\//, "").sub("app/models/", "") }
    models.each { |f| require f }
    ActiveRecord::Base.descendants
  end

  def assert_content(files)
    files -= [File.expand_path(__FILE__).sub("#{Bundler.root}/", '')]
    bad = files.map do |f|
      error = yield File.read(f)
      "#{f}: #{error}" if error
    end.compact
    assert bad.empty?, bad.join("\n")
  end

  let(:all_tests) { Dir["{,plugins/*/}test/**/*_test.rb"] }
  let(:controllers) do
    controllers = Dir["{,plugins/*/}app/controllers/**/*.rb"].grep_v(/\/concerns\//)
    controllers.size.must_be :>, 50
    controllers
  end
  let(:all_code) do
    code = Dir["{,plugins/*/}{app,lib}/**/*.rb"]
    code.size.must_be :>, 50
    code
  end

  it "does not include rails-assets-bootstrap" do
    # make sure rails-assets-bootstrap did not get included by accident (dependency of some other bootstrap thing)
    # if it is not avoidable see http://stackoverflow.com/questions/7163264
    File.read('Gemfile.lock').wont_include 'rails-assets-bootstrap '
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
      if content.match?(/^\s+(setup|teardown)[\s{]/)
        "uses setup or teardown, but should use before or after"
      end
    end
  end

  # rails does not run validations on :destroy, so we should not run them on soft-delete (which is an update)
  it 'discourages use of soft_delete without validate: false' do
    assert_content all_code do |content|
      if content.match?(/[. ]soft_delete!?$/)
        'prefer soft_delete(validate: false)'
      end
    end
  end

  it 'checks for usages of Dir.chdir' do
    assert_content all_code do |content|
      if content.match?(/Dir\.chdir/)
        'Avoid using Dir.chdir as it causes warnings and potentially some threading issues'
      end
    end
  end

  it "uses active test case wording" do
    assert_content all_tests do |content|
      if content.match?(/\s+it ['"]should /)
        "uses `it should` working, please use active working `it should activate` -> `it activates`"
      end
    end
  end

  it "does not have trailing whitespace" do
    assert_content Dir["{app,lib,plugins,test}/**/*.rb"] do |content|
      "has trailing whitespace" if content.match?(/ $/)
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
      files: all_code,
      tests: all_tests
    )
  end

  it "has same version in .ruby-version and lock to make heroku not crash" do
    File.read('Gemfile.lock').must_include File.read('.ruby-version').strip
  end

  it "has same version in .ruby-version and Dockerfile to make builds work" do
    File.read('Dockerfile').must_include File.read('.ruby-version').strip
  end

  it "has page title for all views" do
    views = Dir['{,plugins/*/}app/views/**/*.html.erb'].
      reject { |v| File.basename(v).start_with?('_') }.
      reject { |v| v.include?('_mailer/') }.
      reject { |v| v.include?('/layouts/') }
    assert_content views do |content|
      if !content.include?(' page_title') && !content.include?(' render template: ')
        "declare a page title for nicer navigation"
      end
    end
  end

  it "does not modify the ENV without resetting state" do
    assert_content all_tests do |content|
      if content.match?(/ENV\[.*=/)
        "use with_env to setup ENV variables during test"
      end
    end
  end

  # tests multi_thread_db_detector.rb
  it "blows up when using database from a different thread" do
    e = assert_raises RuntimeError do
      silence_thread_exceptions do
        Thread.new { User.first }.join
      end
    end
    e.message.must_include "Using AR outside the main thread"
  end

  it "has a Readme for each plugin" do
    Dir["plugins/*"].size.must_equal Dir["plugins/*/*"].grep(/\/README\.md\z/).size
  end

  it "links every plugin in docs" do
    readme_path = 'docs/plugins.md'
    readme = File.read(readme_path)
    plugins = Dir['plugins/*'].map { |f| File.basename(f) } - ENV['PRIVATE_PLUGINS'].to_s.split(',')
    plugins.each do |plugin_name|
      assert(
        readme.include?("https://github.com/zendesk/samson/tree/master/plugins/#{plugin_name}"),
        "#{readme_path} must include link to #{plugin_name}"
      )
    end
  end

  it "uses whitelists for authorization so new actions ar restricted by default" do
    assert_content controllers do |content|
      if content.match?(/before_action\s+:authorize_.*only:/)
        "do not use authorization filters with :only, use :except"
      end
    end
  end

  # If a controller only tests `as_a :admin { get :index }` then we don't know if authentification
  # logic properly works, so all actions have to be tested as unauthenticated or as public/viewer level
  # for example: as_a :deployer { unauthenticated :get, :index } + as_a :admin { get :index } is good.
  it "checks authentication levels for all actions" do
    controller_tests = Dir["{,plugins/*/}test/controllers/**/*_test.rb"] - [
      'test/controllers/application_controller_test.rb',
      'test/controllers/doorkeeper_base_controller_test.rb',
      'test/controllers/unauthorized_controller_test.rb',
      'test/controllers/resource_controller_test.rb',
    ]
    controller_tests.reject! { |c| c =~ %r{/(integrations|concerns)/} }

    controller_tests.size.must_be :>, 40 # make sure splat works correctly

    bad = controller_tests.map do |f|
      # find all actions in the controller
      controller = f.sub('test/', 'app/').sub('_test.rb', '.rb')
      public_section = File.read(controller).split(/  (protected|private)$/).first
      controller_actions = public_section.scan(/def ([\w_]+)/).flatten - ['self']
      raise "No actions in #{f} !?" if controller_actions.empty? && !public_section.include?("< ResourceController")

      # find all actions tested to be unauthorized, viewer accessible, or public accessible
      test = File.read(f)
      action_pattern = /\s(?:get|post|put|patch|delete)\s+:([\w_]+)/

      unauthorized_actions = test.scan(/^\s+unauthorized\s+(?:\S+),\s+:([\w_]+)/).flatten

      viewer_block = test[/^  as_a :viewer.*?^  end/m].to_s
      viewer_actions = viewer_block.scan(action_pattern).flatten

      public_actions = test.scan(/^  describe.*?^  end/m).map { |section| section.scan(action_pattern) }.flatten

      # check if all actions were tested
      missing = controller_actions - unauthorized_actions - viewer_actions - public_actions
      if missing.any?
        "#{f} is missing unauthorized, viewer accessible, or public accessible test for #{missing.join(', ')}\n" \
        "actions (if these are helpers and not actions, make them private)"
      end
    end.compact

    assert bad.empty?, bad.join("\n")
  end

  it "prevents the users from printing outputs when migrations are silenced" do
    assert_content Dir["{,plugins/*/}db/migrate/*.rb"] do |content|
      if content.match?(/^\s*puts\b/)
        "use `write` instead of `puts` to avoid printing outputs when migrations are silenced"
      end
    end
  end

  it "does not use like since that is different on different dbs" do
    assert_content all_code do |content|
      if content.match?(/\slike\s+\?/i)
        "use Arel#matches instead of like since like behaves differently on different dbs"
      end
    end
  end

  it "uses/recommends consistent PERIODICAL" do
    values = [
      File.read('.env.bootstrap')[/PERIODICAL=(.*)/, 1],
      JSON.parse(File.read('app.json')).dig("env", "PERIODICAL", "value"),
      File.read('.env.example')[/PERIODICAL=(.*)/, 1],
    ]
    values.uniq.size.must_equal 1, "Expected all places to use consistent PERIODICAL value, but found #{values.inspect}"
  end

  it "has gitignore and dockerignore in sync" do
    File.read(".dockerignore").must_include File.read(".gitignore")
  end

  it "explicity defines what should happen to dependencies" do
    bad = all_models.flat_map do |model|
      model.reflect_on_all_associations.map do |association|
        next if association.is_a?(ActiveRecord::Reflection::BelongsToReflection) # cleans itself up
        next if association.name == :audits # should never be destroyed
        next if association.options.key?(:through) # already cleaned up via through relation
        next if association.options.key?(:dependent) # already defined
        "#{model.name} #{association.name}"
      end
    end.compact
    assert(
      bad.empty?,
      "These associations need a :dependent defined (most likely :destroy or nil)\n#{bad.join("\n")}"
    )
  end

  it "links all dependencies both ways so dependencies get deleted reliably" do
    bad = (all_models - [Audited::Audit]).flat_map do |model|
      model.reflect_on_all_associations.map do |association|
        next if association.name == :audits # should not be cleaned up and added by external helper
        next if association.options[:polymorphic] # TODO: should verify all possible types have a cleanup association
        next if association.options[:inverse_of] == false # disabled on purpose
        next if association.inverse_of
        "#{model.name} #{association.name}"
      end
    end.compact
    assert(
      bad.empty?,
      <<~TEXT
        These associations need an inverse association.
        For example project has stages and stage has project.
        If automatic connection does not work, use `:inverse_of` option on the association.
        If inverse association is missing AND the inverse should not destroyed when dependency is destroyed, use `inverse_of: false`.
        #{bad.join("\n")}
      TEXT
    )
  end

  it "does not override default routes from plugins" do
    core = File.read("config/routes.rb").scan(/^  resources :([^\s,]+)/).flatten
    core.size.must_be :>, 10

    routes = Dir["{#{Samson::Hooks.plugins.map(&:folder).join(",")}}/config/routes.rb"]
    bad = routes.flat_map do |route|
      redeclared = File.read(route).scan(/^  resources :(\S+) do/).flatten & core
      redeclared.map { |b| "#{route} do not re-declare core object routes #{b}, use `only: []`" }
    end
    assert bad.empty?, bad.join("\n")
  end
end
