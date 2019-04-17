# frozen_string_literal: true
# loaded by marco-polo gem, marking sandbox mode
if Rails.application.sandbox
  [:PROMPT_I, :PROMPT_N].each { |p| IRB.conf[:PROMPT][:RAILS_ENV][p].sub!("(", "(sandbox ") }
end
