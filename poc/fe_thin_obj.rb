require 'rubygems'
require 'memcached'
require 'thin'
require 'starling'
require 'ruby-debug'

DEBUG = true

class InfamyFE
  def initialize(use_queue=false)
    super()
    @queue = nil
    @cache = Memcached.new("localhost:11211")
    @queue = Starling.new("localhost:22122") if use_queue
  end

  def get_score(uid)
    user = {:score => 0, :updated_at => Time.now, :stored_at => nil}
    begin
      user = @cache.get(uid)
    rescue Memcached::NotFound
      puts "get_score: not found" if DEBUG
    end
    return user
  end

  def set_score(uid, score)
    user = {:score => score, :updated_at => Time.now, :stored_at => nil}
    begin
      @cache.set(uid, user)
    rescue
      puts "error setting score"
    end
    begin
      @queue.set('abusers', uid) if @queue
    rescue
      puts "error adding to queue"
    end
    return user
  end

  def call(env)
    status = 200
    nothing, command, uid, amount = env['PATH_INFO'].split('/')
    user = get_score(uid)
    case command
    when 'score'
      body = user[:score].to_s
      puts "got request for #{uid}: #{user[:score]}" if DEBUG
    when 'add'
      score = user[:score] + amount.to_i
      set_score(uid, score)
      body = score.to_s
    else
      status = 404
      body = "Undefined url"
    end

    [status, {'Content-Type' => 'text/plain'}, body]
  end
end

Thin::Server.start('127.0.0.1', 4444, InfamyFE.new(true))
