require 'rubygems'
require 'dm-core'
require 'starling'
require 'memcache'
require "#{File.dirname(__FILE__)}/../be_sqlite"

# pull from starling
starling = Starling.new('127.0.0.1:22122')
cache = MemCache.new("localhost:11211")

while true
  begin
    uid = starling.get('infamy')
  rescue
    sleep 10
    next
  end

  begin
    info = cache.get(uid)
  rescue Memcached::NotFound
    puts "Error fetching info from memcache"
    next
  end

  begin
    next if info[:stored_at] && info[:stored_at] > info[:updated_at]
    info_db = Infamy.first(uid) || Infamy.new
    info_db.update(:uid => uid, :score => info[:score], :updated_at => Time.now)
    info_db.save
    #info[:stored_at] = Time.now
    #cache.set(uid, info)
  rescue => e
    puts "Error writing score to db: #{e}"
    retry
  end
end
