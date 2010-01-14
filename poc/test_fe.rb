require 'rubygems'
require 'typhoeus'

100.times {
  response = Typhoeus::Request.get("http://127.0.0.1:4444/score/1:111", 
                                   :headers => {"X-Originating-IP" => "10.1.1.1"})
}

score = 0
Typhoeus::Request.get("http://127.0.0.1:4444/set/1:111/#{score}")
100.times {
  amount = rand(20) - 10
  Typhoeus::Request.get("http://127.0.0.1:4444/add/1:111/#{amount}")
  score += amount
}

puts "score should be: #{score}"
resp = Typhoeus::Request.get("http://127.0.0.1:4444/score/1:111")
puts "score is: #{resp.body}"

