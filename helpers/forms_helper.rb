module FormsHelper
  def form_method(model)
    model.id ? "PUT" : "POST"
  end
end
