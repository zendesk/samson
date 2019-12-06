# frozen_string_literal: true
# normalize schema after dumping to avoid diff
# tested via test/integration/tasks_test.rb
# TODO: make it not produce a diff without these hacks
task "db:schema:dump" do
  next unless ActiveRecord::Base.connection.adapter_name.match?(/mysql/i)
  file = "db/schema.rb"
  schema = File.read(file)
  schema.gsub!(/, options: .* do/, " do") || raise
  schema.gsub!('"resource_template", limit: 4294967295', '"resource_template", limit: 1073741823') || raise
  schema.gsub!('"object", limit: 4294967295', '"object", limit: 1073741823') || raise
  schema.gsub!('"output", limit: 4294967295', '"output", limit: 268435455') || raise
  schema.gsub!('"audited_changes", limit: 4294967295', '"audited_changes", limit: 1073741823') || raise
  File.write(file, schema)
end
