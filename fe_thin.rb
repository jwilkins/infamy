require 'rubygems'
require 'memcached'
require 'thin'
#require 'ebb'
#require 'unicorn'
require 'rack'
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
    #@be = :quick
    #@be = :accurate
    @be = nil
  end

  def get_info(uid)
    begin
      return @cache.get(uid)
    rescue Memcached::NotFound
    end

    info = {:score => 0, :updated_at => Time.now, :stored_at => nil}
    if @be
      info_db = Infamy.first(uid)
      info[:score] = info_db[:score] if info_db
      puts "get_info: #{uid} not found" if DEBUG
    end
    return info
  end

  def add_to_audit(type, uid, value)
    @queue.set('audit', [type, uid, value.to_i]) if @queue
  end

  def add_to_score(uid, info, ip, info_ip, amount)
    score = info[:score] + amount.to_i
    set_score(uid, info, score)
    if ip
      ip_score = info_ip[:score] + amount.to_i
      set_score(ip, info_ip, ip_score)
    end
    begin
      add_to_audit(:add, uid, amount) if @queue && @be == :accurate
    rescue
      puts "add_to_score: error adding to queue"
    end
    score
  end

  def set_score(uid, info, score)
    info[:score] = score.to_i
    info[:updated_at] = Time.now
    begin
      @cache.set(uid, info)
    rescue
      puts "set_score: error setting score"
    end
    begin
      @queue.set('infamy', uid) if @queue
      add_to_audit(:set, uid, score) if @queue && @be == :accurate
    rescue
      puts "error adding to queue"
    end
    return info
  end

  def call(env)
    status = 200
    ip_addr = nil

    command, uid, amount = env['PATH_INFO'][1..-1].split('/')
    return [400, {'Content-Type' => 'text/plain'}, 'Error (command)'] unless command
    return [400, {'Content-Type' => 'text/plain'}, 'Error (uid)'] unless uid

    ip = $1 if env['HTTP_X_ORIGINATING_IP'] =~ /([\d]+\.[\d]+\.[\d]+\.[\d]+)/

    info = get_info(uid)
    info_ip = get_info(ip) if ip

    case command
    when 'score'
      #puts "got score request for #{uid}: #{info[:score]}" if DEBUG
      body = info[:score].to_s
    when 'add'
      #puts "got add request for #{uid}: #{amount}" if DEBUG
      return [400, {'Content-Type' => 'text/plain'}, 'Error (invalid amount)'] unless amount
      body = add_to_score(uid, info, ip, info_ip, amount).to_s
    when 'set'
      #puts "got set request for #{uid}: #{amount}" if DEBUG
      return [400, {'Content-Type' => 'text/plain'}, 'Error (invalid amount)'] unless amount
      set_score(uid, info, amount.to_i)
      body = amount.to_s
    when 'did'
      return [400, {'Content-Type' => 'text/plain'}, 'did not implemented'] unless amount
    else
      puts "got #{command} request" if DEBUG
      status = 404
      body = "Undefined url"
    end

    [status, {'Content-Type' => 'text/plain'}, body]
  end
end

options = {}

optparse = OptionParser.new do |opts|
  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
  options[:be] = nil
  opts.on( '-b', '--be BACKEND', "Specify backend (quick or accurate)" ) do |be|
    if be == 'quick' || be == 'accurate'
    options[:be] = f.to_sym
  end
end
optparse.parse!

# NOTE: Thin 1433 r/s (ab -c 50 -n 10000 http://127.0.0.1:8080/score/1:111)
#Thin::Server.start('127.0.0.1', 4444, InfamyFE.new(false))

# NOTE: Thin 1260 r/s (ab -c 50 -n 10000 http://127.0.0.1:8080/score/1:111)
Rack::Handler::Thin.run InfamyFE.new(false), :Port => 4444, :Host => '127.0.0.1'

# XXX: Ebb doesn't complete 10k requests from ab
#Rack::Handler::Ebb.run InfamyFE.new(false), :Port => 4444, :Host => '127.0.0.1'

# NOTE: Unicorn 1230 r/s (ab -c 50 -n 10000 http://127.0.0.1:8080/score/1:111)
#Unicorn.run InfamyFE.new(false)
