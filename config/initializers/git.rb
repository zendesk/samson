# frozen_string_literal: true
min = "2.5.0"
raise "Git not found" unless version = `git --version`[/\d+\.\d+\.\d+/]
raise "Need git v#{min}+" if Gem::Version.new(version) < Gem::Version.new(min)
