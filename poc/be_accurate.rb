require 'rubygems'
require 'dm-core'
require 'starling'
require 'memcache'
require "#{File.dirname(__FILE__)}/../be_sqlite"
require 'ruby-debug'

# pull from starling
starling = Starling.new('127.0.0.1:22122')
cache = MemCache.new("localhost:11211")

while true
  begin
    type, uid, value = starling.get('audit')
    #puts "got #{type}, #{uid}, #{value} from audit"
  rescue
    sleep 10
    next
  end

  begin
    now = Time.now
    info_db = Infamy.first(uid)
    if info_db
      score = info_db[:score] + value.to_i if type == :add
      score = value.to_i if type == :set
      info_db.update(:uid => uid, :score => score, :updated_at => now)
    else
      info_db = Infamy.new(:uid => uid, :score => value.to_i, 
                           :updated_at => now, :created_at => now)
      info_db.save
    end
    #info = cache.get(uid)
    #info[:stored_at] = Time.now
    #cache.set(uid, info)
  rescue => e
    puts "Error writing score to db: #{e}"
    retry
  end
end
