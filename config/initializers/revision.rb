file = Rails.root.join('REVISION')

Rails.application.config.samson.revision = if File.exists?(file)
  File.read(file).chomp
else
  `git rev-parse HEAD`.chomp.presence || raise("No #{file} found and not a git repository ... something is wrong")
end
