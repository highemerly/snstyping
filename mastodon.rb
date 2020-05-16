require 'net/http'
require 'json'
require 'sanitize'
require 'uri'

MASTODON_SERVER = "handon.club"
MASTODON_USER_ID = 1 # highemerly: 1, seibe: 81

HASHTAG_SEPARATORS = "_\u00B7\u200c"
HASHTAG_NAME_RE    = "([[:word:]_][[:word:]#{HASHTAG_SEPARATORS}]*[[:alpha:]#{HASHTAG_SEPARATORS}][[:word:]#{HASHTAG_SEPARATORS}]*[[:word:]_])|([[:word:]_]*[[:alpha:]][[:word:]_]*)"
HASHTAG_RE         = /(?:^|[^\/\)\w])#(#{HASHTAG_NAME_RE})/i
CUSTOMEMOJI_RE     = /(?<=[^[:alnum:]:]|\n|^)
                     :([a-zA-Z0-9_]{2,}):
                      (?=[^[:alnum:]:]|$)/x
EMOJI_RE           = /\p{Emoji}/
KANJI_RE           = /[一-龠々]/

class MastodonReader
  def initialize
    uri = URI.parse("https://#{MASTODON_SERVER}/")
    @http = Net::HTTP.new(uri.host, uri.port)
    @http.use_ssl = true
    @headers = { "Authorization" => "Bearer #{ENV['MASTODON_ACCESS_TOKEN']}" }
  end

  def user_statuses(account_id, max_id=0)
    uri = URI.parse("https://#{MASTODON_SERVER}/api/v1/accounts/#{account_id}/statuses")
    uri.query = URI.encode_www_form({ max_id: max_id }) if max_id > 0
    json = JSON.parse(@http.get(uri,@headers).body)
    return json, get_min_id(json)
  end

  def bookmarks(max_id=0, limit=20)
    uri = URI.parse("https://#{MASTODON_SERVER}/api/v1/bookmarks")
    return self.get_json_with_pager_style(uri, max_id, limit)
  end

  def favourites(max_id=0, limit=20)
    uri = URI.parse("https://#{MASTODON_SERVER}/api/v1/favourites")
    return self.get_json_with_pager_style(uri, max_id, limit)
  end

  protected

  def get_json_with_pager_style(uri, max_id=0, limit=20)
    param = max_id == 0 ? { limit: limit } : { max_id: max_id, limit: limit }
    uri.query = URI.encode_www_form(param)
    res = @http.get(uri,@headers)
    return JSON.parse(res.body), res.get_fields('link')[0].match(/max_id=(\d*)>/)[1].to_i
  end

  def get_min_id(json)
    last_id = 300_000_000_000_000_000
    json.each do |toot|
      last_id = toot["id"].to_i if last_id > toot["id"].to_i
    end
    last_id
  end
end

class Toot
  def self.format(toot)
    str = Sanitize.clean(toot["content"])
                  .strip.chomp
                  .gsub(HASHTAG_RE, '')
                  .gsub(CUSTOMEMOJI_RE, '')
    URI.extract(str).uniq.each do |url|
      str.gsub!(url, '')
    end
    str
  end

  def self.accept?(toot, visibility=["public"], favourites_count=2)
    toot["mentions"].empty? && visibility.include?(toot["visibility"]) && toot["favourites_count"].to_i >= favourites_count
  end

  def self.authorized_user?(account_id=[1])
    account_id.include?(toot["account"]["id"].to_i)
  end
end