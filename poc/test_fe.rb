require 'rubygems'
require 'typhoeus'

100.times {
  response = Typhoeus::Request.get("http://127.0.0.1:4444/score/1:111")
}
