# frozen_string_literal: true
module DateTimeHelper
  def datetime_to_js_ms(utc_string)
    utc_string.to_i * 1000
  end

  def relative_time(time)
    content_tag(:span, time.rfc822, data: {time: datetime_to_js_ms(time)}, class: "mouseover")
  end

  def render_time(time, format = params[:time_format])
    # grab the time format that the user has in their profile
    format ||= current_user.time_format
    case format
    when 'local'
      local_time = time.in_time_zone(cookies[:timezone] || 'UTC').to_s
      content_tag(:time, local_time, datetime: local_time)
    when 'utc'
      utc_time = time.in_time_zone('UTC')
      content_tag(:time, utc_time.to_s, datetime: utc_time)
    else
      relative_time(time)
    end
  end
end
