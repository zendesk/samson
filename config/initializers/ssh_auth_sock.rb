if Rails.env.production?
  unless File.exist?(socket)
    Process.spawn(Rails.root.join("lib/ssh-agent.sh").to_s)

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
