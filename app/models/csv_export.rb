class CsvExport < ActiveRecord::Base
  belongs_to :user

  def status?(state)
    'ready' == state.to_s ? ['downloaded', 'finished'].include?(status) : status == state.to_s
  end

  def email
    user.try :email
  end
  
  def filename
    "#{content}_#{formatted_create_at}.csv"
  end

  def full_filename
    "#{Rails.root}/export/#{id}"
  end

  def pending!
    status!("pending")
  end
  
  def started!
    status!("started")
  end
  
  def finished!
    status!("finished")
  end
  
  def failed!
    status!("failed")
  end
  
  def downloaded!
    status!("downloaded")
  end
  
  def deleted!
    status!("deleted")
  end

  def filters
    JSON.parse(super, symbolize_names: true)
  end
  
  private

  def formatted_create_at
    created_at.strftime "%Y%m%d_%H%M%S"
  end

  def status!(status)
    update_attribute(:status, status)
  end
end
