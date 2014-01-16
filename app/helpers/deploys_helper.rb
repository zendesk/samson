module DeploysHelper
  def file_status_label(status)
    mapping = {
      "added"    => "success",
      "modified" => "info",
      "removed"  => "danger"
    }

    type = mapping[status]

    content_tag :span, status[0].upcase, class: "label label-#{type}"
  end

  def file_changes_label(count, type)
    content_tag :span, count.to_s, class: "label label-#{type}" unless count.zero?
  end

  def github_users(users)
    users.map {|user| github_user_avatar(user) }.join(" ").html_safe
  end

  def github_user_avatar(user)
    link_to user.url, title: user.login do
      image_tag user.avatar_url, width: 20, height: 20
    end
  end

  def deploy_status_panel(deploy)
    mapping = {
      "succeeded" => "success",
      "failed"    => "danger",
      "errored"   => "warning"
    }

    status = mapping.fetch(deploy.status, "info")

    if deploy.finished?
      content = "#{deploy.summary} #{time_ago_in_words(deploy.created_at)} ago"
    else
      content = deploy.summary
    end

    content_tag :div, content, class: "alert alert-#{status}"
  end

end
