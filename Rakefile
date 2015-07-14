# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)

Samson::Application.load_tasks

Rake::Task["default"].clear

Rails::TestTask.new(:default) do |t|
  t.pattern = "{test,plugins/*/test}/**/*_test.rb"
end

namespace :plugins do
  Rails::TestTask.new(:test) do |t|
    t.pattern = "plugins/*/test/**/*_test.rb"
  end
end

namespace :test do
  task js: :environment do
    with_tmp_karma_config do |config|
      sh "./node_modules/karma/bin/karma start #{config} --single-run"
    end
  end

  private

  def with_tmp_karma_config
    Tempfile.open('karma.js') do |f|
      f.write ERB.new(File.read('test/karma.conf.js')).result(binding)
      f.flush
      yield f.path
    end
  end

  def resolve_asset(file)
    Rails.application.assets.find_asset(file).to_a.first.pathname.to_s
  end
end

class Benchmarker
  class << self
    def stackprof
      StackProf.start(:mode => :wall, :interval => 250, :raw => true)
      yield
      StackProf.stop
      results = StackProf.results
      file = "/tmp/zendesk/stackprof-#{results[:mode]}-mail_fetcher-#{Time.now.to_i}.dump"
      FileUtils.mkdir_p(File.dirname(file))
      File.open(file, 'wb') { |f| f.write Marshal.dump(results) }
      file
    end

    def print_instructions(dump)
      host = Socket.gethostname
      if host.include?(".pod") # on remote server
        puts "Go to a jump host like admin05.ord.zdsys.com then"
        puts "scp #{ENV["USER"]}@#{host}:#{dump} ."
        dump = File.basename(dump)
        puts "then download it to you local machine"
        puts "scp #{ENV["USER"]}@admin05.ord.zdsys.com:~/#{File.basename(dump)} ."
      end
      puts "FILE=#{dump} rake open_benchmark"
    end
  end
end

desc "benchmark fetching 1 mail, can be run via `HOSTS=xxx capsu shell`"
task :benchmark do
  job = Deploy.find(2361).job # deploying a public repo
  require "stackprof"
  dump = Benchmarker.stackprof do
    JobExecution.new('master', job).send(:run!) # blocking run without any threading
  end
  Benchmarker.print_instructions(dump)
end
