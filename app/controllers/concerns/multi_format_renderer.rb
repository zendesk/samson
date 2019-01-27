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
        if successful
          on_success_html.call
        else
          on_error_html.call
        end
      end
      format.json do
        if successful
          on_success_json.call
        else
          on_error_json.call
        end
      end
      format.js do
        if successful
          on_success_js.call
        else
          on_error_js.call
        end
      end
    end
  end
end
