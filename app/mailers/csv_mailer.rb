class CsvMailer < ApplicationMailer
  def created_email(csv_export)
    address = csv_export.email
    subject = "Samson CSV Export Completed"
    url = csv_url( id: csv_export.id, format: 'csv')
    body = "Download your CSV file at #{url}"
    mail(to: address, subject: subject, body: body) unless (address.nil? or address.empty?)
  end
end
