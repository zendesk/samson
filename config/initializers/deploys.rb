Thread.main[:deploys] = []

at_exit do
  Thread.main[:deploys].each do |thread|
    thread[:deploy].stop
    thread.join
  end
end
