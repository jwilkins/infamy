require 'rubygems'
require 'dm-core'
require 'starling'
require 'memcache'

ROOT_DIR=File.dirname(__FILE__)
DataMapper.setup(:default, "sqlite3:#{ROOT_DIR}/abusers.sqlite3")

class Abuser
  include DataMapper::Resource
  property :id,         Serial
  property :uid,        String, :key => true
  property :score,      Integer
  property :created_at, DateTime
  property :updated_at, DateTime
end

Abuser.auto_migrate!


