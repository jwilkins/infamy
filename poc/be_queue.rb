require 'rubygems'
require 'dm-core'
require 'starling'
require 'memcache'
require 'be_sqlite'

# pull from starling
starling = Starling.new('127.0.0.1:22122')
cache = MemCache.new("localhost:11211")

while true
  begin
    uid = starling.get('abusers')
  rescue
    sleep 10
    next
  end

  begin
    puts "storing #{uid}"
    user = cache.get(uid)
  rescue Memcached::NotFound
    puts "Error fetching user from memcache"
    next
  end

  begin
    next if user[:stored_at] && user[:stored_at] > user[:updated_at]
    abuser = Abuser.first(uid) || Abuser.new
    abuser.update(:uid => uid, :score => user[:score], :updated_at => Time.now)
    abuser.save
    user[:stored_at] = Time.now
    cache.set(uid, user)
  rescue => e
    puts "Error writing score to db: #{e}"
    retry
  end
end