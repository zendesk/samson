# frozen_string_literal: true
module MultiFormatRenderer
  def multi_format_render(
    successful: nil,
    on_success_html: nil,
    on_error_html: nil,
    on_success_json: nil,
    on_error_json: nil,
    on_success_js: nil,
    on_error_js: nil
  )
    respond_to do |format|
      format.html do
        (successful ? on_success_html : on_error_html).call
      end
      format.json do
        (successful ? on_success_json : on_error_json).call
      end
      format.js do
        (successful ? on_success_js : on_error_js).call
      end
    end
  end
end
