require_relative '../test_helper'

describe StagesHelper do
  describe "#edit_command_link" do
    describe "as admin" do
      let(:current_user) { users(:admin) }

      it "links to global edit" do
        html = edit_command_link(commands(:global_command))
        html.must_equal "<a class=\"edit-command glyphicon glyphicon-globe\" href=\"/admin/commands/625879608/edit\" title=\"Edit global command\"></a>"
      end

      it "links to local edit" do
        html = edit_command_link(commands(:echo))
        html.must_equal "<a class=\"edit-command glyphicon glyphicon-edit\" href=\"/admin/commands/386150450/edit\" title=\"Edit in admin UI\"></a>"
      end
    end

    describe "as other user" do
      let(:current_user) { users(:deployer) }

      it "explains global commands" do
        html = edit_command_link(commands(:global_command))
        html.must_equal "<a class=\"edit-command glyphicon glyphicon-globe\" href=\"#\" title=\"Global command, can only be edited via Admin UI\"></a>"
      end

      it "does not show local edit" do
        edit_command_link(commands(:echo)).must_equal nil
      end
    end
  end
end
