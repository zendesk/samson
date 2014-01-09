module StagesHelper
  def command_check_boxes(form)
    form.collection_check_boxes(:command_ids, Command.all, :id, :name) do |b|
      '<div class="checkbox">'.html_safe +
        b.label { b.check_box + b.text } +
      '</div>'.html_safe
    end
  end
end
