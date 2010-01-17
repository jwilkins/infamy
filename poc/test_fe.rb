require 'rubygems'
require 'typhoeus'

#100.times {
#  response = Typhoeus::Request.get("http://127.0.0.1:4444/score/1:111") 
#}

uids = {}
(100..149).each { |uid|
  uids[uid] = 0
  Typhoeus::Request.get("http://127.0.0.1:4444/set/1:#{uid}/0")
}

1000.times {
  amount = rand(20) - 10
  uid = 100 + rand(49)
  Typhoeus::Request.get("http://127.0.0.1:4444/add/1:#{uid}/#{amount}",
                        :headers => {"X-Originating-IP" => "10.1.1.1"})
  uids[uid] += amount
}

wrong = 0
(100..149).each { |uid|
  resp = Typhoeus::Request.get("http://127.0.0.1:4444/score/1:#{uid}")
  unless uids[uid] == resp.body.to_i
    puts "uid #{uid} score should be #{uids[uid]} and is #{resp.body}" 
    wrong += 1
  end
}

puts "all correct" if wrong == 0
