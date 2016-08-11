# frozen_string_literal: true
file = Rails.root.join('REVISION')

Rails.application.config.samson.revision =
  ENV['HEROKU_SLUG_COMMIT'] || # heroku labs:enable runtime-dyno-metadata
  (File.exist?(file) && File.read(file).chomp) || # local file
  `git rev-parse HEAD`.chomp.presence # local git
