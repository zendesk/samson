Thread.main[:repo_locks] = {}
if ActiveRecord::Base.connection.tables.include?('projects')
  Project.find_each do |p|
    p.make_mutex!
  end
end
