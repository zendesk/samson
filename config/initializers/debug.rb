trap 'QUIT' do
  time = Time.now.strftime("%Y%m%dT%H%M%S")
  Thread.list.each do |thread|
    File.open("/tmp/samson-#{time}-#{Process.pid}", "a+") do |f|
      f.puts "Thread-#{thread.object_id.to_s}"
      f.puts thread.backtrace.join("\n    \\_ ")
    end
  end
end
