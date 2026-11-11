module PrRecordsHelper
  def pr_sentiment_tone(sentiment)
    { "positive" => "green", "negative" => "red" }.fetch(sentiment.to_s, "gray")
  end

  def pr_link_host(url)
    URI.parse(url.to_s).host
  rescue URI::InvalidURIError
    nil
  end
end
