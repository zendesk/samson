unless Rails.env.development? || Rails.env.test?
  socket = Rails.root.join("tmp/auth_sock")

  unless File.exist?(socket)
    Process.spawn({ "DEPLOY_KEY" => ENV['DEPLOY_KEY'].gsub(/\\n/, "\n") }, Rails.root.join("lib/ssh-agent.sh").to_s)

    time = Time.now

    until File.exist?(socket)
      if (Time.now - time) >= 5
        warn "Could not start SSH Agent"
        exit 1
      end
    end
  end

  ENV["SSH_AUTH_SOCK"] = File.readlink(socket)
end
