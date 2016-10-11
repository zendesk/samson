# frozen_string_literal: true
module Samson
  class FormBuilder < ActionView::Helpers::FormBuilder
    SPACER = " ".html_safe

    def input(attribute, as: :text_field, help: false, label: false, input_html: nil, pattern: nil, &block)
      raise ArgumentError if block && input_html

      input_html ||= {}
      input_html[:pattern] ||= translate_regex_to_js(pattern)

      label ||= attribute.to_s.humanize
      help = (help ? SPACER + @template.additional_info(help) : "".html_safe)
      block ||= -> { public_send(as, attribute, input_html) }

      content_tag :div, class: 'form-group' do
        if as == :check_box
          content_tag(:div, class: "col-lg-offset-2 col-lg-10 checkbox") do
            label(attribute) do
              block.call.dup << SPACER << label << help
            end
          end
        else
          input_html[:class] ||= "form-control"
          content = label(attribute, label, class: "col-lg-2 control-label")
          content << content_tag(:div, class: 'col-lg-4', &block)
          content << help
        end
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

    # html regexp input ... allows blank values, does not know case insensitive so use a-zA-Z, does not know \A\z
    # FYI: could also read from validations: _validators[attribute].first.options[:with]
    def translate_regex_to_js(pattern)
      pattern.source.sub('\\A', '^').sub('\\z', '$') if pattern
    end

    def content_tag(*args, &block)
      @template.content_tag(*args, &block)
    end
  end
end
