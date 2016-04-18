module DateTimeHelper
  def datetime_to_js_ms(utc_string)
    utc_string.to_i * 1000
  end
end
