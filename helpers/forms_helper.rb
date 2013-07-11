module FormsHelper
  def method_override
    '<input type="hidden" name="_method" value="PUT" />'
  end

  def form_url(model)
    model.id ? "/#{model.id}" : ""
  end
end
