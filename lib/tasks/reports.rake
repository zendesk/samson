# frozen_string_literal: true

namespace :reports do
  desc "Average time initial deploys wait for their builds per week"
  task deploy_build_wait_time: :environment do
    result = []

    52.times do |i|
      start = 1.year.ago + i.weeks
      range = start..(start + 1.week)

      deploys = Deploy.where(created_at: range, kubernetes: true).succeeded.order(created_at: :asc).
        uniq { |d| d.job.commit }
      builds = Build.where(git_sha: deploys.map { |d| d.job.commit }).order(created_at: :asc).
        group(:project_id, :git_sha)
      wait_times = deploys.map do |deploy|
        build = builds.detect { |b| b.git_sha == deploy.job.commit } || next
        diff = build.updated_at - deploy.created_at
        diff > 1.hour ? next : [diff, 0].max
      end.compact

      next if wait_times.empty?
      average = (wait_times.sum / wait_times.count).round

      result << average

      puts "#{start.strftime('%b, Week %W %Y')}, " \
        "wait time: #{average}, number of builds: #{wait_times.count}, number of deploys: #{deploys.count}"
    end

    puts result
  end
end
