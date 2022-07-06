# frozen_string_literal: true
# normalize schema after dumping to avoid diff
# tested via test/integration/tasks_test.rb
task "db:schema:dump" do
  next unless ActiveRecord::Base.connection.adapter_name.match?(/mysql/i)
  file = "db/schema.rb"
  schema = File.read(file)
  schema.gsub!(/, charset: "utf8mb4".* do/, " do")
  File.write(file, schema)
end
