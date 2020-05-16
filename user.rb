require './optparse.rb'
require './mastodon.rb'
require './weathertyping.rb'

DEBUG = false

opt = Option.new
mstdn = MastodonReader.new
max_id = opt.get[:max_id]

(1..opt.get[:num_of_page]).each do

  toot_list, max_id = mstdn.user_statuses(opt.get[:account_id], max_id)

  toot_list.each do |toot|
    if Toot.accept?(toot) || (opt.get[:accept_unlisted_toot] && Toot.accept?(toot, ["public", "unlisted"])) then
      status = Toot.format(toot)
      print "#{status}\n" if DEBUG
      print WeatherTyping.entry(status, "txt") if status.length > 0
    end
  end

end

puts "Next...: \nruby user.rb -i #{opt.get[:account_id]} -m #{max_id} -n #{opt.get[:num_of_page]}"