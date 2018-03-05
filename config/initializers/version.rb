# frozen_string_literal: true
# sha or tag samson is currently running truncated to 7 characters in the UI, so need to be unique/exact
file = Rails.root.join('REVISION')
version =
  ENV['TAG'] ||
  ENV['HEROKU_SLUG_COMMIT'] || # heroku labs:enable runtime-dyno-metadata
  (File.exist?(file) && File.read(file).chomp) || # local file
  `git describe --tags --exact-match HEAD 2>/dev/null`.chomp.presence # local git

Rails.application.config.samson.version = version
