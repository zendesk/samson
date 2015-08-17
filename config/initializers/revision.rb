file = Rails.root.join('REVISION')

Rails.application.config.samson.revision = if File.exists?(file)
  File.read(file).chomp
else
  `git rev-parse HEAD`.chomp.presence
end
