# frozen_string_literal: true
# sqlite on travis always thinks it needs to be migrated
if ENV['CI'] && ENV['DATABASE_URL'].to_s.include?('sqlite')
  class << ActiveRecord::Migration
    def check_pending!
    end
  end
end
