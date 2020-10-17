# frozen_string_literal: true
# rubocop:disable Layout/LineLength
require_relative '../test_helper'

SingleCov.covered!

describe StagesHelper do
  include ApplicationHelper

  describe "#edit_command_link" do
    let(:current_user) { users(:admin) }

    it "links to global edit" do
      command = commands(:global)
      html = edit_command_link(command)
      html.must_equal "<a title=\"Edit global command\" class=\"edit-command glyphicon glyphicon-globe no-hover\" href=\"/commands/#{command.id}\"></a>"
    end

    it "links to local edit" do
      command = commands(:echo)
      html = edit_command_link(command)
      html.must_equal "<a title=\"Edit\" class=\"edit-command glyphicon glyphicon-edit no-hover\" href=\"/commands/#{command.id}\"></a>"
    end
  end

  describe "#stage_template_icon" do
    it "renders icon" do
      stage_template_icon.must_include "glyphicon-duplicate"
    end
  end
end
# rubocop:enable Layout/LineLength
