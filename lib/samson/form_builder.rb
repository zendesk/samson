# frozen_string_literal: true
module Samson
  class FormBuilder < ActionView::Helpers::FormBuilder
    def input(attribute, as: :text_field, help: false, label: false)
      content_tag :div, class: 'form-group' do
        content = label(attribute, label, class: "col-lg-2 control-label")
        content << content_tag(:div, class: 'col-lg-4') do
          public_send(as, attribute, class: "form-control")
        end
        content << @template.additional_info(help) if help
        content
      end
    end

    private

    def content_tag(*args, &block)
      @template.content_tag(*args, &block)
    end
  end
end
