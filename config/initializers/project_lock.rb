if ActiveRecord::Base.connection.tables.include?('projects')
  Project.find_each do |p|
    ProjectLock.init(p)
  end
end
