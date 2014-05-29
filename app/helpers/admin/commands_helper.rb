module Admin::CommandsHelper
  def command_form_legend
    if @command.new_record?
      "New Command"
    else
      "Edit Command"
    end
  end
end
