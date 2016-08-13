# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe CsvMailer do
  before { @csv_export = CsvExport.find(csv_exports(:pending).id) }

  it "mails to the correct valid user and includes download link" do
    CsvMailer.created(@csv_export).deliver_now
    mail_sent = ActionMailer::Base.deliveries.last
    refute ActionMailer::Base.deliveries.empty?
    assert mail_sent.to.must_equal [@csv_export.user.email]
    assert mail_sent.subject.include?('Export Completed')
    assert mail_sent.body.include?('Download')
    assert mail_sent.body.include?("/csv_exports/#{@csv_export.id}.csv")
  end
end
