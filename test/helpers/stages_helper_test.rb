require_relative '../test_helper'

describe StagesHelper do
  describe "#edit_command_link" do
    describe "as admin" do
      let(:current_user) { users(:admin) }

      it "links to global edit" do
        command = commands(:global)
        html = edit_command_link(command)
        html.must_equal "<a title=\"Edit global command\" class=\"edit-command glyphicon glyphicon-globe no-hover\" href=\"/admin/commands/#{command.id}/edit\"></a>"
      end

      it "links to local edit" do
        command = commands(:echo)
        html = edit_command_link(command)
        html.must_equal "<a title=\"Edit in admin UI\" class=\"edit-command glyphicon glyphicon-edit no-hover\" href=\"/admin/commands/#{command.id}/edit\"></a>"
      end
    end

    describe "as other user" do
      let(:current_user) { users(:deployer) }

      it "explains global commands" do
        html = edit_command_link(commands(:global))
        html.must_equal "<a title=\"Global command, can only be edited via Admin UI\" class=\"edit-command glyphicon glyphicon-globe no-hover\" href=\"#\"></a>"
      end

      it "does not show local edit" do
        edit_command_link(commands(:echo)).must_equal nil
      end
    end
  end
end
