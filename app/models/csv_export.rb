class CsvExport < ActiveRecord::Base
  belongs_to :user
  serialize :filters, JSON
  STATUS_VALUES = [nil, 'pending', 'started', 'finished', 'downloaded', 'failed', 'deleted']

  before_create :set_defaults
  before_destroy :delete_file

  validates :status, inclusion: { in: STATUS_VALUES }

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
    filter = super
    if filter.nil? || filter.class == "".class
      filter = {}
    elsif filter.fetch('deploys.created_at', nil).class == "".class
      dates = filter['deploys.created_at'].scan(/-?\d+-\d+-\d+/)
      filter['deploys.created_at'] = (Date.parse(dates[0])..Date.parse(dates[1]))
    end
    filter
  end

  def status!(status)
    update_attributes!(status: status)
  end

  def delete_file
    File.delete(path_file) if File.exist?(path_file)
  end

  private

  def set_defaults
    self.status ||= :pending
    self.filters ||= {}
  end
end
