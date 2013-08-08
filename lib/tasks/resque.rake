# load the Rails app all the time
namespace :resque do
  task :setup => :environment do
    ActiveRecord::Base.descendants.each { |klass|  klass.columns }
  end
end
