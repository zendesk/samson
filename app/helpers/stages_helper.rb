module StagesHelper
  def command_check_boxes(form)
    form.collection_check_boxes(:command_ids, @stage.all_commands, :id, :command) do |b|
      "<div data-id=\"#{b.value}\" class=\"checkbox\">".html_safe +
        b.label { b.check_box + "<pre>#{b.text.truncate(30)}</pre>".html_safe } +
      '</div>'.html_safe
    end
  end
end
