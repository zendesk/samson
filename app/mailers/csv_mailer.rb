class CsvMailer < ApplicationMailer
  def created_email(csv_export)
    address = csv_export.email
    subject = "Samson CSV Export Completed"
    body = "Download your CSV file at #{url_for controller: 'csv', action: 'download', id: csv_export.id, only_path: false}"
    mail(to: address, subject: subject, body: body) unless (address.nil? or address.empty?)
  end
end
