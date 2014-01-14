file = Rails.root.join('REVISION')

Rails.application.config.pusher.revision = if File.exists?(file)
  File.read(file).chomp
else
  `git rev-parse HEAD`.chomp rescue nil
end
