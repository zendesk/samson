#!/usr/bin/env ruby

databases = ["mysql", "postgresql", "sqlite"]

raise unless databases.include?(ENV["DB"])

def sh(cmd)
  puts "» #{cmd}"
  system(cmd) || raise("Command failed")
end

sh "cp config/database.travis.yml config/database.yml"

case ENV["TASK"]
when "js"
  sh "npm install"
  sh "npm run-script jshint"
  sh "bundle exec rake test:js"
when "precompile"
  sh "SECRET_TOKEN=foo GITHUB_TOKEN=foo PRECOMPILE=1 RAILS_ENV=production bundle exec rake assets:precompile"
when "rake"
  sh "mysql -u root -e 'set GLOBAL innodb_large_prefix = true' || true"
  sh "mysql -u root -e 'set GLOBAL innodb_file_per_table = true' || true"
  sh "mysql -u root -e 'set GLOBAL innodb_file_format = \"barracuda\"' || true"
  sh "bundle exec rake db:create default"
else
  raise "Unknown task"
end
