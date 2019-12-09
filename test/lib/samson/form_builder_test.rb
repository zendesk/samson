# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Samson::FormBuilder do
  def fake_erb_rendering
    builder.instance_variable_get(:@template).output_buffer << "XYZ"
  end

  let(:object) { User.new }
  let(:builder) { Samson::FormBuilder.new(:user, object, view_context, {}) }

  describe '#input' do
    it "adds a clickable label" do
      result = builder.input(:name)
      result.must_include 'for="user_name">Name</label>'
      result.must_include 'id="user_name"'
    end

    it "creates a text field by default" do
      builder.input(:name).must_include 'type="text"'
    end

    it "can override label" do
      builder.input(:name, label: "Ho Ho").must_include 'for="user_name">Ho Ho</label>'
    end

    it "can handle a blank label" do
      builder.input(:name, label: '').must_include '<div class="col-lg-2 control-label"></div>'
    end

    it "can change field type" do
      builder.input(:name, as: :text_area).must_include '<textarea '
    end

    it "auto-expands text areas to show full content" do
      builder.input(:name).wont_include 'rows="'
      builder.input(:name, as: :text_area).must_include 'rows="2"'
      builder.object.name = "a\nb\nc\nd\n"
      builder.input(:name, as: :text_area).must_include 'rows="6"'
    end

    it "can show help" do
      builder.input(:name, help: "Hello!").must_include "data-content=\"Hello!\""
      builder.input(:name, help: "Hello!").must_include "</i>"
    end

    it "can show help for check box" do
      builder.input(:name, as: :check_box, help: "Hello!").must_include "data-content=\"Hello!\""
      builder.input(:name, as: :check_box, help: "Hello!").must_include "</i>"
    end

    it "can show size" do
      builder.input(:name, input_html: {size: '1x4'}).must_include ' size="1x4"'
    end

    it "can override input class" do
      builder.input(:name, input_html: {class: 'foo'}).must_include ' class="foo"'
    end

    it "replaces input with block" do
      builder.input(:name) { fake_erb_rendering }.must_include "XYZ"
    end

    it "replaces input with block for check boxes" do
      builder.input(:name, as: :check_box) { fake_erb_rendering }.must_include "XYZ"
    end

    it "does not add a for attribute on check boxes so whatever is wrapped is clickable" do
      result = builder.input(:name, as: :check_box) { '<inout name="foo" type="checkbox">'.html_safe }
      result.must_include "<label><inout name=\"foo\" type=\"checkbox\"> Name</label>"
    end

    it "does not allow input_html and block" do
      assert_raises ArgumentError do
        builder.input(:name, input_html: {size: 'zxy'}) { "XYZ" }
      end
    end

    describe "pattern" do
      it "does not include empty pattern" do
        builder.input(:name, help: "Hello!").wont_include "pattern"
      end

      it "includes translated js pattern" do
        builder.input(:name, pattern: /\Aabc\z/).must_include 'pattern="^abc$"'
      end

      it "fails on pattern without start" do
        assert_raises ArgumentError do
          builder.input(:name, pattern: /abc\z/)
        end
      end

      it "fails on pattern without end" do
        assert_raises ArgumentError do
          builder.input(:name, pattern: /\Aabc/)
        end
      end
    end

    it "removes _id part for labels" do
      builder.input(:role_id).must_include '>Role</label>'
    end

    it "can mark fields as required" do
      result = builder.input(:name, required: true)
      result.must_include 'required="required"'
      result.must_include '* Name'
    end
  end

  describe '#actions' do
    let(:object) { users(:viewer) }

    it "renders" do
      result = builder.actions
      result.must_include "value=\"Save\""
      result.wont_include "Delete"
    end

    it "does not include delete link for new object" do
      builder.object.stubs(persisted?: false)
      builder.actions(delete: true).wont_include "Delete"
    end

    it "can include delete link" do
      view_context.expects(:url_for).with(builder.object).returns('/xxx')
      builder.actions(delete: true).must_include "Delete"
    end

    it "can include custom delete link" do
      view_context.expects(:url_for).with([:admin, commands(:echo)]).returns('/xxx')
      builder.actions(delete: [:admin, commands(:echo)]).must_include "Delete"
    end

    it "can add help text to delete" do
      view_context.expects(:url_for).with(builder.object).returns('/xxx')
      builder.actions(delete: true, delete_help: "Bar").must_include 'data-content="Bar"'
    end

    it "can include type_to_delete link" do
      view_context.expects(:url_for).with(builder.object).returns('/xxx')
      builder.actions(delete: :type).must_include "type-to-delete"
    end

    it "does not include history link for new object" do
      builder.object.stubs(persisted?: false)
      builder.actions(history: true).wont_include "History"
    end

    it "can include history link" do
      view_context.expects(:audits_path).returns('/xxx')
      builder.actions(history: true).must_include "> <a href=\"/xxx\">History"
    end

    it "can include visibly separated history and delete link" do
      view_context.expects(:url_for).times(2).returns('/xxx') # audits_url is passed into url_for
      view_context.expects(:audits_path).returns('/xxx')
      builder.actions(history: true, delete: true).must_include "> | <a href=\"/xxx\">History"
    end

    it "can add additional links with block" do
      builder.actions { fake_erb_rendering }.must_include "XYZ"
    end

    it "can override button text" do
      builder.actions(label: 'Execute!').must_include "value=\"Execute!\""
    end
  end

  # NOTE: ideally don't use a plugin model, but we need something with accepts_nested_attributes_for
  describe '#fields_for_many' do
    def render(*args)
      project.rollbar_dashboards_settings.build # TODO: this does not get rendered
      builder.fields_for_many(*args) do |p|
        p.text_field :base_url, placeholder: 'thing!'
      end
    end

    let(:setting) do
      RollbarDashboards::Setting.create!(
        project: projects(:test),
        base_url: 'https://bingbong.gov/api/1',
        account_and_project_name: "Foo/Bar",
        read_token: '12345'
      )
    end
    let(:project) { Project.new(rollbar_dashboards_settings: [setting]) }
    let(:builder) { Samson::FormBuilder.new(:project, project, view_context, {}) }

    it 'renders' do
      result = render(:rollbar_dashboards_settings)
      result.must_include 'form-group'
      result.must_include 'checkbox'
    end

    it 'can include add new row link' do
      result = render(:rollbar_dashboards_settings, add_rows_allowed: true)
      result.must_include 'Add row'
    end
  end
end
