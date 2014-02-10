Project.find_each do |p|
  p.make_mutex!
end
