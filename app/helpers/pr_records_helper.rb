module PrRecordsHelper
  def pr_sentiment_tone(sentiment)
    { "positive" => "green", "negative" => "red" }.fetch(sentiment.to_s, "gray")
  end

  def pr_link_host(url)
    URI.parse(url.to_s).host
  rescue URI::InvalidURIError
    nil
  end

  def pr_link_label(url, length: 42)
    uri = URI.parse(url.to_s)
    host = uri.host.to_s.delete_prefix("www.")
    path = uri.path.to_s.sub(%r{/\z}, "")
    label = "#{host}#{path}".presence || url.to_s
    truncate(label, length: length)
  rescue URI::InvalidURIError
    truncate(url.to_s, length: length)
  end

  def pr_index_entries(record, category)
    entries = record.entries.to_a
    entries = entries.select { |entry| entry.pr_category_id == category.id } if category
    entries.presence || record.entries.to_a
  end

  def pr_entry_urls(entry)
    urls = entry.links.sort_by(&:id).map(&:url).select(&:present?)
    urls = [ entry.url ] if urls.empty? && entry.url.present?
    urls.uniq
  end
end
