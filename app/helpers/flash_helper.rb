module FlashHelper
  # Flash type -> Bootstrap alert class
  def flash_mapping
    { notice: :info, error: :danger, authorization_error: :danger, success: :success }
  end
end
