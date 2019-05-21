# frozen_string_literal: true
module JsonPagination
  private

  def add_json_pagination(json, pagy)
    # add custom headers to the response
    add_json_pagination_headers(pagy)

    links = add_json_pagination_links(pagy)
    if links.present?
      # Pagination links are appened at the first place in JSON results.
      # because it will be more hard to find links in large JSON.
      json.delete("links")
      json.replace({links: links}.merge(json))
    end
  end

  def json_pagination_pages(pagy)
    paging = {}
    paging[:first] = 1          unless pagy.page == 1
    paging[:last] = pagy.pages  unless pagy.page == pagy.pages

    paging[:prev] = pagy.prev   unless pagy.prev.nil?
    paging[:next] = pagy.next   unless pagy.next.nil?
    paging
  end

  def add_json_pagination_links(pagy)
    links = {}
    uri = request.env["PATH_INFO"]

    # Build pagination links
    json_pagination_pages(pagy).each do |key, value|
      query_params = request.query_parameters.merge(page: value)
      links[key] = "#{uri}?#{query_params.to_param}"
    end
    links
  end

  def add_json_pagination_headers(pagy)
    headers['X-PER-PAGE']      = pagy.offset
    headers["X-CURRENT-PAGE"]  = pagy.page
    headers["X-TOTAL-PAGES"]   = pagy.pages
    headers["X-TOTAL-RECORDS"] = pagy.count
  end
end
