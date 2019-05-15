# frozen_string_literal: true
# rubocop:disable Metrics/LineLength
require_relative '../test_helper'

SingleCov.covered!

describe ApplicationHelper do
  include LocksHelper
  include StatusHelper
  include ERB::Util

  describe "#render_log" do
    it "removes translates ascii escapes to html colors" do
      # false positive ansi codes
      render_log("a[Aa").must_equal "<span class=\"ansible_none\">a[Aa</span>"
      render_log("a[AAa").must_equal "<span class=\"ansible_none\">a[AAa</span>"
      render_log("a[1a").must_equal "<span class=\"ansible_none\">a[1a</span>"
      render_log("a[12a").must_equal "<span class=\"ansible_none\">a[12a</span>"
      render_log("a[12ma").must_equal "<span class=\"ansible_none\">a[12ma</span>"

      # real ansi codes
      render_log("\e[0;32mok").must_equal "<span class=\"ansible_none\"></span><span class=\"ansible_32\">ok</span>"
      render_log("\e[0;33mchanged").must_equal "<span class=\"ansible_none\"></span><span class=\"ansible_33\">changed</span>"
      render_log("\e[0;36mskipping").must_equal "<span class=\"ansible_none\"></span><span class=\"ansible_36\">skipping</span>"
    end

    it "escapes html" do
      result = render_log("<script>1</script>")
      result.must_equal "<span class=\"ansible_none\">&lt;script&gt;1&lt;/script&gt;</span>"
      assert result.html_safe?
    end

    it "converts urls to links" do
      result = render_log("foo http://bar.com bar https://sdf.dd/sdfs/2131/fdfdsf.json baz")
      result.must_equal "<span class=\"ansible_none\">foo " \
        "<a href=\"http://bar.com\">http://bar.com</a> bar " \
        "<a href=\"https://sdf.dd/sdfs/2131/fdfdsf.json\">https://sdf.dd/sdfs/2131/fdfdsf.json</a> baz</span>"
    end
  end

  describe "#github_user_avatar" do
    it "renders an avatar for a Github user" do
      user = stub(login: "willy_wonka", avatar_url: "http://wonka.com/me.gif")
      html = github_user_avatar(user)

      html.must_include %(title="willy_wonka")
    end
  end

  describe "#autolink" do
    it "converts urls with hash to links" do
      result = autolink("foo http://bar.com#123 baz")
      result.must_equal "foo <a href=\"http://bar.com#123\">http://bar.com#123</a> baz"
    end

    it "converts urls with ?/& to links" do
      result = autolink("foo http://bar.com?a=123&b=222 baz")
      result.must_equal "foo <a href=\"http://bar.com?a=123&b=222\">http://bar.com?a=123&b=222</a> baz"
    end

    it "converts gcloud vulnerability urls with @ to links" do
      result = autolink("foo http://bar.com?a=123&b=2@2 baz")
      result.must_equal "foo <a href=\"http://bar.com?a=123&b=2@2\">http://bar.com?a=123&b=2@2</a> baz"
    end
  end

  describe "#markdown" do
    it "converts markdown to html" do
      result = markdown("**hello**")
      result.must_equal "<p><strong>hello</strong></p>\n"
      assert result.html_safe?
    end

    it "does not allow XSS" do
      result = markdown("<script>alert(1)</script>")
      result.must_equal "alert(1)\n"
      assert result.html_safe?
    end
  end

  describe "#controller_action" do
    it "works" do
      stubs(action_name: "foo")
      controller_action.must_equal "test foo"
    end
  end

  describe "#deploy_link" do
    let(:project) { projects(:test) }
    let(:stage) { stages(:test_staging) }
    let(:link) { deploy_link(project, stage) }
    let(:current_user) { users(:admin) }

    it "starts a deploy" do
      assert_includes link, ">Deploy<"
      assert_includes link, %(href="/projects/#{project.to_param}/stages/#{stage.to_param}/deploys/new")
    end

    it "shows locked" do
      Lock.stubs(locked_for?: true)
      assert_includes link, ">Locked<"
    end

    it "shows running deploy" do
      deploy = stage.deploys.create!(
        reference: 'master',
        job: Job.create(user: current_user, command: '', project: project),
        project: project
      )
      stage.stubs(active_deploy: deploy)
      assert_includes link, ">Deploying master...<"
      assert_includes link, %(href="/projects/#{project.to_param}/deploys/#{deploy.id}")
    end

    describe "direct stage" do
      before { stage.stubs(direct?: true) }

      it "shows direct link when stage is direct" do
        link.must_include ">Deploy<"
        link.must_include "master"
        link.must_include "btn-warning"
      end

      it "shows direct link with default ref if set" do
        stage.update_column(:default_reference, 'foobar')
        link.must_include ">Deploy<"
        link.must_include "foobar"
        link.must_include "btn-warning"
      end
    end

    describe "when stage can run in parallel" do
      before { stage.stubs(:run_in_parallel).returns true }

      it "always starts a deploy" do
        deploy = stage.deploys.create!(
          reference: 'master',
          job: Job.create(user: current_user, command: '', project: project),
          project: project
        )
        stage.stubs(active_deploy: deploy)
        assert_includes link, ">Deploy<"
        assert_includes link, %(href="/projects/#{project.to_param}/stages/#{stage.to_param}/deploys/new")
      end
    end
  end

  describe "#sortable" do
    let(:url_options) { {controller: 'ping', action: 'show'} }

    it "builds a link" do
      sortable("foo").must_equal "<a href=\"/ping?direction=asc&amp;sort=foo\">Foo</a>"
    end

    it "builds a link with given title" do
      sortable("foo", "bar").must_equal "<a href=\"/ping?direction=asc&amp;sort=foo\">bar</a>"
    end

    it "builds a desc link when sorting asc" do
      params[:direction] = "asc"
      params[:sort] = "foo"
      sortable("foo").must_equal "<a href=\"/ping?direction=desc&amp;sort=foo\">Foo</a>"
    end

    it "buils a asc link when sorting asc by a different column" do
      params[:direction] = "asc"
      params[:sort] = "bar"
      sortable("foo").must_equal "<a href=\"/ping?direction=asc&amp;sort=foo\">Foo</a>"
    end
  end

  describe "#breadcrumb" do
    let(:stage) { stages(:test_staging) }
    let(:project) { projects(:test) }
    let(:environment) { Environment.find_by_param!('production') }
    let(:deploy_group) { deploy_groups(:pod1) }
    let(:build) { builds(:docker_build) }

    it "renders strings" do
      breadcrumb("Foobar").must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"active\">Foobar</li></ul>"
    end

    it "renders empty" do
      breadcrumb.must_equal "<ul class=\"breadcrumb\"><li class=\"active\">Home</li></ul>"
    end

    it "renders stage" do
      breadcrumb(stage).must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"active\">Staging</li></ul>"
    end

    it "renders locked stage" do
      stage.stubs(lock: Lock.new)
      breadcrumb(stage).must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"active\"><i class=\"glyphicon glyphicon-lock\"></i> Staging</li></ul>"
    end

    it "renders warning stage" do
      stage.stubs(lock: Lock.new(warning: true))
      breadcrumb(stage).must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"active\"><i class=\"glyphicon glyphicon-warning-sign\"></i> Staging</li></ul>"
    end

    it "renders project" do
      breadcrumb(project).must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"active\">Foo</li></ul>"
    end

    it "renders environment" do
      breadcrumb(environment).must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"active\">Production</li></ul>"
    end

    it "renders deploy_group" do
      breadcrumb(deploy_group).must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"active\">Pod1</li></ul>"
    end

    it "renders activerecord classes" do
      breadcrumb(DeployGroup).must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"active\">DeployGroups</li></ul>"
    end

    it "renders multiple breadcrumbs" do
      breadcrumb(project, stage, "stuff").must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"\"><a href=\"/projects/foo\">Foo</a></li><li class=\"\"><a href=\"/projects/foo/stages/staging\">Staging</a></li><li class=\"active\">stuff</li></ul>"
    end

    it "refuses to render unknown" do
      assert_raises(ArgumentError) { breadcrumb(111) }.message.must_equal "Unsupported breadcrumb for 111"
    end

    it "does not allow html injection" do
      stage.name = "<script>alert(1)</script>"
      breadcrumb(stage).must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"active\">&lt;script&gt;alert(1)&lt;/script&gt;</li></ul>"
    end

    it "renders array" do
      breadcrumb(['foo', 'bar'], ['baz', 'bar']).must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"\"><a href=\"bar\">foo</a></li><li class=\"active\">baz</li></ul>"
    end
  end

  describe "#flash_messages" do
    let(:flash) { {} }

    it "returns empty" do
      flash_messages.must_equal []
    end

    it "fails on unknown" do
      flash[:foo] = "bar"
      assert_raises(KeyError) { flash_messages }
    end

    it "translates bootstrap classes" do
      flash[:notice] = "N"
      flash_messages.must_equal [[:notice, :info, "N"]]
    end

    it "returns arrays of messages" do
      flash[:notice] = ["bar", "baz"]
      flash_messages.must_equal [[:notice, :info, "bar"], [:notice, :info, "baz"]]
    end
  end

  describe "#link_to_delete" do
    it "builds a link" do
      link_to_delete("/foo").must_include ">Delete</a>"
    end

    it "shows common message for paths" do
      link_to_delete("/foo").must_include "Really delete ?"
    end

    it "shows detailed message for resource given as array" do
      link = link_to_delete([projects(:test), stages(:test_staging)])
      link.must_include "Delete this Stage ?"
      link.must_include "/projects/foo/stages/staging"
    end

    it "can link directly to a resource" do
      link = link_to_delete(stages(:test_staging))
      link.must_include "Delete Stage Staging ?"
      link.must_include "/projects/foo/stages/staging"
    end

    it "builds a hint when disabled" do
      link_to_delete("/foo", disabled: "Foo").must_equal(
        "<span title=\"Foo\" class=\"mouseover\">Delete</span>"
      )
    end

    it "adds data/class attribute for remove_container" do
      html = link_to_delete("/foo", remove_container: "tr")
      html.must_include "data-remove-container=\"tr\""
      html.must_include "class=\"remove_container\""
      html.must_include "method"
    end

    it "can ask a question" do
      link_to_delete("/foo", question: "Foo?").must_equal(
        "<a data-method=\"delete\" data-confirm=\"Foo?\" href=\"/foo\">Delete</a>"
      )
    end

    it "can ask to type" do
      link_to_delete("/foo", type_to_delete: true).must_equal(
        "<a data-method=\"delete\" data-type-to-delete=\"Really delete ?\" href=\"/foo\">Delete</a>"
      )
    end
  end

  describe "#link_to_url" do
    it "builds a link" do
      link_to_url("b").must_equal "<a href=\"b\">b</a>"
    end
  end

  describe "#link_to_resource" do
    it "links to project" do
      link_to_resource(projects(:test)).must_equal "<a href=\"/projects/foo\">Foo</a>"
    end

    it "links to user" do
      link_to_resource(users(:admin)).must_equal "<a href=\"/users/#{users(:admin).id}\">Admin</a>"
    end

    it "links to stages" do
      link_to_resource(stages(:test_staging)).must_equal "<a href=\"/projects/foo/stages/staging\">Staging</a>"
    end

    it "links to deploys" do
      deploy = deploys(:succeeded_test)
      link_to_resource(deploy).must_equal "<a href=\"/projects/foo/deploys/#{deploy.id}\">Deploy ##{deploy.id}</a>"
    end

    it "links to environments" do
      link_to_resource(environments(:production)).must_equal "<a href=\"/environments/production\">Production</a>"
    end

    it "links to deploy_groups" do
      link_to_resource(deploy_groups(:pod1)).must_equal "<a href=\"/deploy_groups/pod1\">Pod1</a>"
    end

    it "links to grants" do
      grant = SecretSharingGrant.create!(project: projects(:test), key: 'foo')
      link_to_resource(grant).must_equal "<a href=\"/secret_sharing_grants/#{grant.id}\">foo</a>"
    end

    it "links to vault" do
      server = create_vault_server
      link_to_resource(server).must_equal "<a href=\"/vault_servers/#{server.id}\">pod1</a>"
    end

    it "fails on unknown" do
      assert_raises(ArgumentError) { link_to_resource(123) }.message.must_equal "Unsupported resource Integer"
    end

    # sanity check that we did not miss anything especially plugin models
    it "can render each versioned model" do
      SecretSharingGrant.create!(project: projects(:test), key: 'foo')

      audited_classes.map(&:constantize).each do |klass|
        model = klass.first || klass.new
        link_to_resource(model)
      end
    end

    it "does not try to build path for deleted resources since that would blow up" do
      projects(:test).soft_delete!(validate: false)
      stage = stages(:test_staging)
      link_to_resource(stage).must_equal "Staging"
    end
  end

  describe "#audited_classes" do
    before_and_after { ApplicationHelper.class_variable_set(:@@audited_classes, nil) }

    # we know this reaches inside because of coverage is 100%
    it "works when in test" do
      audited_classes
    end

    it "works when not in test" do
      Rails.env.stubs(:test?).returns(false)
      Rails.application.config.stubs(:eager_load).returns(true)
      audited_classes
    end
  end

  describe "#render_nested_errors" do
    # simulate what erb will do so we can see html_safe issues
    def render
      ERB::Util.html_escape(render_nested_errors(stage))
    end

    let(:stage) { stages(:test_staging) }

    it "renders nothing for valid" do
      render.must_equal ""
    end

    it "renders simple errors" do
      stage.errors.add(:base, "Kaboom")
      render.must_equal "<ul><li>Kaboom</li></ul>"
    end

    it "renders nested errors" do
      stage.errors.add(:deploy_groups, "Invalid") # happens on save normally .. not a helpful message for our users
      stage.errors.add(:base, "BASE") # other error to make sure nesting is correct
      stage.deploy_groups.to_a.first.errors.add(:base, "Kaboom")
      render.must_equal "<ul><li>Deploy groups Invalid<ul><li>Kaboom</li></ul></li><li>BASE</li></ul>"
    end

    it "does not loop" do
      stage.errors.add(:project, "Invalid")
      stage.project.stubs(stages: [stage])
      stage.project.errors.add(:stages, "Invalid")
      render.must_equal "<ul><li>Project Invalid<ul><li>Stages Invalid</li></ul></li></ul>"
    end

    it "cannot inject html" do
      stage.errors.add(:deploy_groups, "<foo>")
      stage.errors.add(:base, "<bar>")
      stage.deploy_groups.to_a.first.errors.add(:base, "<baz>")
      render.must_equal "<ul><li>Deploy groups &lt;foo&gt;<ul><li>&lt;baz&gt;</li></ul></li><li>&lt;bar&gt;</li></ul>"
    end
  end

  describe "#additional_info" do
    let(:always_attributes) { 'data-toggle="popover" data-placement="right" data-trigger="hover"' }

    it "builds a help text" do
      additional_info("foo").must_equal(
        %(<i class="glyphicon glyphicon-info-sign" data-content="foo" #{always_attributes}></i>)
      )
    end

    it "escapes html in the help text" do
      additional_info("<em>foo</em>").must_equal(
        %(<i class="glyphicon glyphicon-info-sign" data-content="&lt;em&gt;foo&lt;/em&gt;" #{always_attributes}></i>)
      )
    end

    it "escapes html html_safe strings and sets the 'data-html' attribute" do
      additional_info("<em>foo</em>".html_safe).must_equal(
        %(<i class="glyphicon glyphicon-info-sign" data-content="&lt;em&gt;foo&lt;/em&gt;" data-html="true" #{always_attributes}></i>)
      )
    end

    it "double escapes html_safe string with appened non-safe html and sets the 'data-html' attribute" do
      string = "".html_safe << "<em>foo</em>"

      additional_info(string).must_equal(
        %(<i class="glyphicon glyphicon-info-sign" data-content="&amp;lt;em&amp;gt;foo&amp;lt;/em&amp;gt;" data-html="true" #{always_attributes}></i>)
      )
    end

    it 'allows option overrides' do
      expected_html = %(<i class="glyphicon glyphicon-alert barfoo" data-content="foo" #{always_attributes}></i>)
      additional_info('foo', class: 'glyphicon glyphicon-alert barfoo').must_equal expected_html
    end
  end

  describe "#link_to_history" do
    let(:user) { users(:admin) }

    it "shows a link" do
      link_to_history(user).must_equal(
        "<a href=\"/audits?search%5Bauditable_id%5D=#{user.id}&amp;search%5Bauditable_type%5D=User\">History (0)</a>"
      )
    end

    it "shows nothing when new" do
      link_to_history(User.new).must_equal nil
    end

    it "shows number of entries" do
      user.update_attributes!(name: "Foo")
      user.update_attributes!(name: "Bar")
      link_to_history(user).must_include "History (2)"
    end

    it "can not show counter to avoid N+1 queries on large tables" do
      link_to_history(user, counter: false).must_include ">History<"
    end
  end

  describe "#page_title" do
    before { _prepare_context } # setup ActionView::Base

    it "renders content" do
      result = page_title 'xyz'
      result.must_equal "<h1>xyz</h1>"
      content_for(:page_title).must_equal "xyz"
    end

    it "renders html" do
      result = page_title '<img/>Heyhooo'.html_safe
      result.must_equal "<h1><img/>Heyhooo</h1>"
      content_for(:page_title).must_equal "Heyhooo"
    end

    it "adds project name if necessary" do
      @project = projects(:test)
      result = page_title "Hey"
      result.must_equal "<h1>Hey</h1>"
      content_for(:page_title).must_equal "Hey - Foo"
    end

    it "renders blocks" do
      result = page_title { "x" }
      result.must_equal "<h1>x</h1>"
      content_for(:page_title).must_equal "x"
    end

    it "renders inside of tabs where we already have a h1" do
      result = page_title "x", in_tab: true
      result.must_equal "<h2>x</h2>"
      content_for(:page_title).must_equal "x"
    end

    it "does not escape simple entities" do
      page_title "a & b ; c"
      content_for(:page_title).must_equal "a & b ; c"
    end
  end

  describe "#redirect_to_field" do
    let(:root_url) { 'http://foobar.com/' }

    before { stubs(request: stub(referrer: "#{root_url}referrer"), params: {redirect_to: '/params'}) }

    it "stores current parameter" do
      redirect_to_field.must_include "value=\"/params\""
    end

    it "does not store empty parameter" do
      params[:redirect_to] = ""
      redirect_to_field.must_include "value=\"/referrer\""
    end

    describe "without param" do
      before { params.delete(:redirect_to) }

      it "uses referrer when param is missing" do
        redirect_to_field.must_include "value=\"/referrer\""
      end

      it "does not use referrer from other page since redirect_back_or would not work" do
        assert request.stubs(:referrer, request.referrer.sub(root_url, 'http://hacky.com/'))
        redirect_to_field.must_be_nil
      end

      it "is empty when nothing is known" do
        request.stubs(:referrer).returns(nil)
        redirect_to_field.must_be_nil
      end
    end
  end

  describe "#delete_checkbox" do
    it "does not show anything if the object is new" do
      form_for Project.new do |form|
        delete_checkbox(form).must_be_nil
      end
    end

    it "shows a checkbox when the object is persisted" do
      form_for projects(:test) do |form|
        delete_checkbox(form).must_include ">Delete<"
      end
    end
  end

  describe "#search_form" do
    it "renders a form" do
      result = search_form { "Hello" }
      result.must_include "action=\"?\""
      result.must_include "method=\"get\""
      result.must_include "class=\"btn btn-default form-control\""
    end
  end

  describe "#search_select" do
    it "builds a select with options" do
      result = search_select :foo, ["a", "b", "c"], label: "Bar"
      result.must_include ">Bar</label>"
      result.must_include "name=\"search[foo]\""
      result.must_include "<option value=\"b\">b</option>"
      result.wont_include "selectpicker"
    end

    it "can create a live search" do
      result = search_select :foo_id, ["a", "b", "c"], live: true
      result.must_include ">Foo</label>"
      result.must_include "name=\"search[foo_id]\""
      result.must_include "selectpicker"
      result.must_include "data-live-search"
    end

    it "can change selected" do
      result = search_select :foo, ["a", "b", "c"], selected: "b"
      result.must_include "<option selected=\"selected\" value=\"b\">"
    end
  end

  describe "#live_select_tag" do
    it "builds a select" do
      live_select_tag(:foo, options_for_select(["bar"])).must_equal(
        "<select name=\"foo\" id=\"foo\" class=\"form-control selectpicker\" title=\"\" " \
        "data-live-search=\"true\"><option value=\"bar\">bar</option></select>"
      )
    end
  end

  describe "#paginate" do
    include Pagy::Frontend
    include Pagy::Backend

    let(:request) { stub(script_name: "script", path: "path", GET: {}) }

    before { stubs(url_for: "foo") }

    it "does not show nav for 1-page" do
      paginate(pagy(User.where("1=2"), page: 1, items: 1).first).must_equal ""
    end

    it "shows records for paginate" do
      paginate(pagy(User, page: 1, items: 1).first).must_include " #{User.count} records"
    end

    it "does not show records for single-page" do
      paginate(pagy(User, page: 1, items: 100).first).wont_include " records"
    end

    it "does not show records for 0-page" do
      paginate(pagy(User.where("1=2"), page: 1, items: 1).first).wont_include " records"
    end
  end

  describe '#list_with_show_more' do
    let(:items) { %w[foo bar baz] }

    it 'only shows `display_limit` records' do
      tag = unordered_list(items, display_limit: 2, show_more_tag: content_tag(:li, 'More')) do |item|
        item
      end

      tag.must_equal '<ul><li>foo</li><li>bar</li><li>More</li></ul>'
    end

    it 'shows all records if there is no display limit' do
      tag = unordered_list(items) do |item|
        item
      end

      tag.must_equal '<ul><li>foo</li><li>bar</li><li>baz</li></ul>'
    end

    it 'passes through any HTML options' do
      tag = unordered_list(
        items,
        display_limit: 2,
        show_more_tag: content_tag(:li, 'More'),
        ul_options: {class: 'show-more'},
        li_options: {class: 'sparkles'}
      ) do |item|
        item
      end

      expected_html = '<ul class="show-more"><li class="sparkles">foo</li><li class="sparkles">bar</li>' \
        '<li>More</li></ul>'
      tag.must_equal expected_html
    end
  end

  describe "#link_to_chart" do
    it "renders" do
      chart = link_to_chart("Hello world", [200, 3, 4, 100, 500])
      chart.must_include "https://chart.googleapis.com/chart"
    end

    it "renders all 0" do
      chart = link_to_chart("Hello world", [0, 0, 0, 0, 0])
      chart.must_include "https://chart.googleapis.com/chart"
    end

    it "does not render for useless data" do
      link_to_chart("Hello world", []).must_equal nil
      link_to_chart("Hello world", [1]).must_equal nil
      link_to_chart("Hello world", [1, 2]).must_equal nil
    end
  end

  describe "#icon_tag" do
    it "generates simple icons" do
      html = icon_tag("foo")
      html.must_equal "<i class=\"glyphicon glyphicon-foo\"></i>"
      assert html.html_safe?
    end

    it "generates icons with titles" do
      html = icon_tag("foo", title: "bar")
      html.must_equal "<i title=\"bar\" class=\"glyphicon glyphicon-foo\"></i>"
      assert html.html_safe?
    end

    it "allows passing in custom CSS classes" do
      html = icon_tag("foo", class: "yolo")
      html.must_equal "<i class=\"glyphicon glyphicon-foo yolo\"></i>"
    end
  end

  describe "#deployed_or_running_list" do
    let(:stage_list) { [stages(:test_staging)] }

    it "produces safe output" do
      html = deployed_or_running_list([], "foo")
      html.must_equal ""
      assert html.html_safe?
    end

    it "renders succeeded deploys" do
      html = deployed_or_running_list(stage_list, "staging")
      html.must_equal "<span class=\"label label-success release-stage\">Staging</span> "
    end

    it "ignores failed deploys" do
      deploys(:succeeded_test).job.update_column(:status, 'failed')
      html = deployed_or_running_list(stage_list, "staging")
      html.must_equal ""
    end

    it "ignores non-matching deploys" do
      deploys(:succeeded_test).update_column(:reference, 'nope')
      html = deployed_or_running_list(stage_list, "staging")
      html.must_equal ""
    end

    it "shows active deploys" do
      deploys(:succeeded_test).job.update_column(:status, 'running')
      html = deployed_or_running_list(stage_list, "staging")
      html.must_equal "<span class=\"label label-warning release-stage\">Staging</span> "
    end
  end

  describe "#check_box_section" do
    let(:project) { projects(:test) }
    it 'creates a section of checkboxes from a collection' do
      project.stages.each_with_index { |s, i| s.stubs(:id).returns(i) }

      expected_result = <<~HTML.gsub /^\s+|\n/, ""
        <fieldset>
          <legend>Project Stages</legend>
          <p class="col-lg-offset-2">Pick some of them stages!</p>
          <div class="col-lg-4 col-lg-offset-2">
            <input type="hidden" name="project[stages][]" value="" />
            <input type="checkbox" value="0" name="project[stages][]" id="project_stages_0" /> <label for="project_stages_0">Staging</label>
            <br />
            <input type="checkbox" value="1" name="project[stages][]" id="project_stages_1" /> <label for="project_stages_1">Production</label>
            <br />
            <input type="checkbox" value="2" name="project[stages][]" id="project_stages_2" /> <label for="project_stages_2">Production Pod</label>
            <br />
          </div>
        </fieldset>
      HTML

      result = check_box_section 'Project Stages', 'Pick some of them stages!', :project, :stages, project.stages
      result.must_equal expected_result
    end
  end
end
# rubocop:enable Metrics/LineLength
