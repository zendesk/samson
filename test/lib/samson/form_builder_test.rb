# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Samson::FormBuilder do
  let(:template) do
    template = ActionView::Base.new
    template.extend ApplicationHelper
    template
  end
  let(:builder) { Samson::FormBuilder.new(:user, User.new, template, {}) }

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

    it "can change field type" do
      builder.input(:name, as: :text_area).must_include '<textarea class='
    end

    it "can show help" do
      builder.input(:name, help: "Hello!").must_include "title=\"Hello!\"></i>"
    end
  end
end
