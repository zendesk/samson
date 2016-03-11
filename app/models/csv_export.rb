class CsvExport < ActiveRecord::Base
  include Searchable

  belongs_to :user

  def ready?
    finished? or downloaded?
  end

  def pending?
    status == 'pending'
  end

  def started?
    status == 'started'
  end

  def finished?
    status == 'finished'
  end

  def downloaded?
    status == 'downloaded'
  end

  def failed?
    status == 'failed'
  end

  def deleted?
    status == 'deleted'
  end

  def email
    if user.nil?
      nil
    else
      user.email
    end
  end
  
  def filename
    filename = "#{self.content}_#{formatted_create_at}.csv"
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
  
  private

  def formatted_create_at
    created_at.to_datetime.strftime "%Y%m%d_%H%M%S"
  end

  def status!(status)
    update_attribute(:status, status)
  end
end
