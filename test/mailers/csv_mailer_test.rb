require_relative '../test_helper'

describe CsvMailer do
  setup do
    @csv_export = CsvExport.find(csv_exports(:pending).id)
    @csv_export.finished!
  end
  
  it "mails to the correct valid user and includes download link" do
    CsvMailer.created_email(@csv_export).deliver_now
    mail_sent = ActionMailer::Base.deliveries.last
    assert_not ActionMailer::Base.deliveries.empty?
    assert mail_sent.to.must_equal [@csv_export.user.email]
    assert mail_sent.subject.include?('Export Completed')
    assert mail_sent.body.include?('Download')
    assert mail_sent.body.include?("/csvs/#{@csv_export.id}.csv")
  end
  
  it "does not mail to invalid user" do
    @csv_export.update_attribute(:user_id, -99999)
    CsvMailer.created_email(@csv_export).deliver_now
    assert ActionMailer::Base.deliveries.empty?
  end
end
