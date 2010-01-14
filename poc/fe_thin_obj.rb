require 'rubygems'
require 'memcached'
require 'thin'
require 'starling'
require 'ruby-debug'
require 'be_sqlite'

DEBUG = true

class InfamyFE
  def initialize(use_queue=false)
    super()
    @queue = nil
    @cache = Memcached.new("localhost:11211")
    @queue = Starling.new("localhost:22122") if use_queue
  end

  def add_to_audit(type, uid, value)
    @queue.set('audit', [type, uid, value]) if @queue
  end

  def get_score(uid)
    user = {:score => 0, :updated_at => Time.now, :stored_at => nil}
    begin
      user = @cache.get(uid)
    rescue Memcached::NotFound
      abuser = Abuser.first(uid)
      user[:score] = abuser[:score] if abuser
      puts "get_score: not found" if DEBUG
    end
    return user
  end

  def add_to_score(user, uid, ip, amount)
    score = user[:score] + amount.to_i
    set_score(uid, score)
    if ip
      ip_score = ip[:score] + amount.to_i
      set_score(ip_addr, ip_score)
    end
    begin
      add_to_audit(:add, uid, amount) if @queue
    rescue
      puts "add_to_score: error adding to queue"
    end
    score
  end

  def set_score(uid, score)
    user = {:score => score.to_i, :updated_at => Time.now, :stored_at => nil}
    begin
      @cache.set(uid, user)
    rescue
      puts "set_score: error setting score"
    end
    begin
      @queue.set('abusers', uid) if @queue
      add_to_audit(:set, uid, score) if @queue
    rescue
      puts "error adding to queue"
    end
    return user
  end

  def call(env)
    status = 200
    ip_addr = '0.0.0.0'

    nothing, command, uid, amount = env['PATH_INFO'].split('/')
    return [400, {'Content-Type' => 'text/plain'}, 'Error (command)'] unless command
    return [400, {'Content-Type' => 'text/plain'}, 'Error (uid)'] unless uid

    ip_addr = $1 if env['HTTP_X_ORIGINATING_IP'] =~ /([\d]+\.[\d]+\.[\d]+\.[\d]+)/ || nil

    user = get_score(uid)
    ip = get_score(ip_addr) if ip_addr
    case command
    when 'score'
      puts "got score request for #{uid}: #{user[:score]}" if DEBUG
      body = user[:score].to_s
    when 'add'
      puts "got add request for #{uid}: #{amount}" if DEBUG
      return [400, {'Content-Type' => 'text/plain'}, 'Error (invalid amount)'] unless amount
      body = add_to_score(user, uid, ip, amount).to_s
    when 'set'
      puts "got set request for #{uid}: #{amount}" if DEBUG
      return [400, {'Content-Type' => 'text/plain'}, 'Error (invalid amount)'] unless amount
      set_score(uid, amount.to_i)
      body = amount.to_s
    else
      puts "got #{command} request" if DEBUG
      status = 404
      body = "Undefined url"
    end

    [status, {'Content-Type' => 'text/plain'}, body]
  end
end

Thin::Server.start('127.0.0.1', 4444, InfamyFE.new(true))
