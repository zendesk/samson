Thread.main[:repo_locks] = {}
Project.find_each do |p|
  p.make_mutex!
end
