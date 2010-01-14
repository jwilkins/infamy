require 'rubygems'
require 'dm-core'
require 'starling'
require 'memcache'
require 'be_sqlite'
require 'ruby-debug'

# pull from starling
starling = Starling.new('127.0.0.1:22122')
#cache = MemCache.new("localhost:11211")

while true
  begin
    type, uid, value = starling.get('audit')
    puts "got #{type}, #{uid}, #{value} from audit"
  rescue
    sleep 10
    next
  end

  begin
    now = Time.now
    abuser = Abuser.first(uid)
    if abuser
      score = abuser[:score] + value.to_i if type == :add
      score = value.to_i if type == :set
      abuser.update(:uid => uid, :score => score, :updated_at => now)
    else
      abuser = Abuser.new(:uid => uid, :score => value.to_i, :created_at => now)
    end
    abuser.save
    #user[:stored_at] = Time.now
    #cache.set(uid, user)
  rescue => e
    puts "Error writing score to db: #{e}"
    retry
  end
end
