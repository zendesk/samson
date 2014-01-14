module StagesHelper
  def command_check_boxes(form)
    form.collection_check_boxes(:command_ids, @stage.all_commands, :id, :command) do |b|
      content_tag(:div, data: { id: b.value }, class: 'checkbox') do
        b.label { b.check_box + content_tag(:pre, b.text.truncate(30)) }
      end
    end
  end
end
