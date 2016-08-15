# frozen_string_literal: true
class CsvMailer < ApplicationMailer
  def created(csv_export)
    address = csv_export.email
    subject = "Samson Deploys CSV Export Completed"
    url = csv_export_url(csv_export, format: 'csv')
    body = "The csv export you requested on #{csv_export.created_at} has finished!  Download your CSV file at #{url}"
    mail(to: address, subject: subject, body: body)
  end
end
