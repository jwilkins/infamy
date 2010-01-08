require 'rubygems'
require 'memcached'
require 'thin'
require 'ruby-debug'

class InfamyFE
  def initialize(use_queue=false)
    super()
    @queue = nil
    @cache = Memcached.new("localhost:11211")
    begin
      @queue = Starling.new("localhost:22122") if use_queue
    rescue
    end
  end

  def get_score(id)
    score = 0
    begin
      score = @cache.get(id)
    rescue Memcached::NotFound
    end
    return score
  end

  def set_score(id, score)
    begin
      @cache.set(id, score)
      @queue.set('abusers', id) if @queue
    rescue
    end
    return score
  end

  def call(env)
    status = 200
    nothing, command, id, amount = env['PATH_INFO'].split('/')
    score = get_score(id)
    case command
    when 'score'
      body = score.to_s
      puts "got request for #{id}: #{score}"
    when 'add'
      score = score + amount.to_i
      set_score(id, score)
      body = score.to_s
    else
      status = 404
      body = "Undefined url"
    end

    [status, {'Content-Type' => 'text/plain'}, body]
  end
end

Thin::Server.start('127.0.0.1', 4444, InfamyFE.new(false))
