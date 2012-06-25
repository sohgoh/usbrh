# -*- coding: utf-8 -*-
=begin

- USB温度・湿度計モジュール(メーカー品番：USBRH-FG)
http://strawberry-linux.com/catalog/items?code=52002
windowsXP上でrubyおよびいくつかのモジュールを利用して温度・湿度・不快指数を計測してtweetするプログラムです.

=end

require 'rubygems'
gem 'twitter'
require 'twitter'
require 'time'
require 'dl/win32'

OAUTH_CONSUMER_KEY    = 'Your consumer key'
OAUTH_CONSUMER_SECRET = 'Your consumer secret'
OAUTH_ACCESS_TOKEN    = 'Your access token'
OAUTH_ACCESS_SECRET   = 'Your access secret'

PROXY_ADDR = nil

def request( client, getting_replies )
  if getting_replies then
    return client.mentions
  end
  return client.friends_timeline
end

def usbrh( dev )

  # device(port) number
  _GetVers          = Win32API.new("USBMeter", "_GetVers@4", ['P'], 'P')
  _GetTempHumid     = Win32API.new("USBMeter", "_GetTempHumid@12", ['P', 'P', 'P'], 'I')
  _ControlIO        = Win32API.new("USBMeter", "_ControlIO@12", ['P', 'I', 'I'], 'I')
  _SetHeater        = Win32API.new("USBMeter", "_SetHeater@8", ['P', 'I'], 'I')
  _GetTempHumidTrue = Win32API.new("USBMeter", "_GetTempHumidTrue@12", ['P', 'P', 'P'], 'I')

  ret = _ControlIO.call(dev, 0, 0)
  ret = _ControlIO.call(dev, 1, 0)
  ret = _SetHeater.call(dev, 0)

  # set double(in C) value(is dirty method..orz)
  temp = "10000000"
  rh   = "10000000"
  ret  = _GetTempHumidTrue.call(dev, temp, rh)

  dTemp = temp.unpack('E').shift
  dRh   = rh.unpack('E').shift

  # discomfort index
  di=0.81*dTemp+0.01*dRh*(0.99*dTemp-14.3)+46.3

  return Array.new([dTemp,dRh,di])
end

Twitter.configure do |config|
  config.consumer_key = OAUTH_CONSUMER_KEY
  config.consumer_secret = OAUTH_CONSUMER_SECRET
  config.oauth_token = OAUTH_ACCESS_TOKEN
  config.oauth_token_secret = OAUTH_ACCESS_SECRET
end

# Initialize your Twitter client
client = Twitter::Client.new

getting_replies = nil
if ARGV[ 0 ] == '-r' then
  getting_replies = true
  ARGV.shift
end

_FindUSB          = Win32API.new("USBMeter", "_FindUSB@4", ['P'], 'P')

while (dev = _FindUSB.call("0")) == ""
end
if dev == "" 
  print "Sensor not found\n"
  exit 1
end
ret = usbrh(dev)

#print "Temperature: "+ret[0].to_s+", Humidity: "+ret[1].to_s+", Discomfort Index: "+ret[2].to_s+" at #{Time.now.strftime( '%m/%d %H:%M' )}"
#exit 0

if ret.size > 0 then
  client.update( "Temperature: "+ret[0].to_s+", Humidity: "+ret[1].to_s+", Discomfort Index: "+ret[2].to_s+" at #{Time.now.strftime( '%m/%d %H:%M' )}" )
end

# display timeline
#request( client, getting_replies ).reverse.each do |s|
#  puts "#{s.user.screen_name} : #{s.text} [ #{Time.parse(s.created_at).strftime( '%Y/%m/%d %H:%M' )}]"
#end

