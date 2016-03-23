class CsvExport < ActiveRecord::Base
  belongs_to :user
  STATUS_VALUES = ['pending', 'started', 'finished', 'downloaded', 'failed', 'deleted']

  before_destroy :file_delete

  def status?(state)
    'ready' == state.to_s ? ['downloaded', 'finished'].include?(status) : status == state.to_s
  end

  def email
    user.try :email
  end
  
  def download_name
    "deploys_#{created_at.strftime "%Y%m%d_%H%M%S"}.csv"
  end

  def path_file
    "#{Rails.root}/export/#{id}"
  end

  def filters
    filter = JSON.parse(super)
    if filter.key?('deploys.created_at')
      dates = filter['deploys.created_at']
      filter['deploys.created_at'] = (Date.parse(dates[0])..Date.parse(dates[1]))
    end
    filter
  end
  
  def status!(status)
    STATUS_VALUES.include?(status.to_s) ? update_attribute(:status, status) : raise("Invalid Status")
  end

  def file_delete
    File.delete(path_file) if File.exist?(path_file)
  end
end
