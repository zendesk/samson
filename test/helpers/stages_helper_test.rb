require_relative '../test_helper'

describe StagesHelper do
  describe "#edit_command_link" do
    describe "as admin" do
      let(:current_user) { users(:admin) }

      it "links to global edit" do
        html = Nokogiri::HTML(edit_command_link(commands(:global_command)))
        assert_select html, 'a.edit-command.no-hover.glyphicon.glyphicon-globe'
        assert_select html, 'a[href="/admin/commands/625879608/edit"]'
        assert_select html, 'a[title="Edit global command"]'
      end

      it "links to local edit" do
        html = Nokogiri::HTML(edit_command_link(commands(:echo)))
        assert_select html, 'a.edit-command.no-hover.glyphicon.glyphicon-edit'
        assert_select html, 'a[href="/admin/commands/386150450/edit"]'
        assert_select html, 'a[title="Edit in admin UI"]'
      end
    end

    describe "as other user" do
      let(:current_user) { users(:deployer) }

      it "explains global commands" do
        html = Nokogiri::HTML(edit_command_link(commands(:global_command)))
        assert_select html, 'a.edit-command.no-hover.glyphicon.glyphicon-globe'
        assert_select html, 'a[href="#"]'
        assert_select html, 'a[title^="Global command"]'
      end

      it "does not show local edit" do
        edit_command_link(commands(:echo)).must_equal nil
      end
    end
  end
end
