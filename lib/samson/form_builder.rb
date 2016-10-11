# frozen_string_literal: true
module Samson
  class FormBuilder < ActionView::Helpers::FormBuilder
    def input(attribute, as: :text_field, help: false, label: false, input_html: nil, &block)
      raise ArgumentError if block && input_html

      block ||= -> do
        public_send(as, attribute, {class: "form-control"}.merge(input_html || {}))
      end

      content_tag :div, class: 'form-group' do
        content = label(attribute, label, class: "col-lg-2 control-label")
        content << content_tag(:div, class: 'col-lg-4', &block)
        content << @template.additional_info(help) if help
        content
      end
    end

    def actions
      content_tag :div, class: "form-group" do
        content_tag :div, class: "col-lg-offset-2 col-lg-10" do
          submit 'Save', class: "btn btn-primary"
        end
      end
    end

    private

    def content_tag(*args, &block)
      @template.content_tag(*args, &block)
    end
  end
end
