# frozen_string_literal: true
# loaded by marco-polo, cannot be in console.rb
if Rails.env.production?
  puts "Running in readonly mode. Use Samson::ReadonlyDb.disable to switch to writable."
  Samson::ReadonlyDb.enable
end
