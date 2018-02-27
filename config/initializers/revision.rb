# frozen_string_literal: true
file = Rails.root.join('REVISION')
result =
  ENV['TAG'] ||
  ENV['HEROKU_SLUG_COMMIT'] || # heroku labs:enable runtime-dyno-metadata
  (File.exist?(file) && File.read(file).chomp) || # local file
  `git describe --tags HEAD`.chomp.presence # local git

Rails.application.config.samson.revision = result.presence
