#!/usr/bin/env ruby
#
#  ATimeSignal - Time Signal for Android.
#  Copyright (C) 2019 Yuuki Harano
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'date'
require 'net/https'
require 'uri'
require 'json'
require 'webrick'
require 'rb-inotify'

require_relative './conf'

if TOKEN_LIST_FILE.nil?
  raise 'TOKEN_LIST_FILE not set.'
end
if SERVER_KEY.nil?
  raise 'SERVER_KEY not set.'
end

class Notifier
  
  END_POINT = 'https://fcm.googleapis.com/fcm/send'
  
  def notify()
    hhmm = Time.now.localtime.strftime('%H:%M')

    uri = URI.parse(END_POINT)
    
    header = {
      'Content-Type' => 'application/json',
      'Authorization' => 'key=' + SERVER_KEY,
    }
    
    retry_ctr = 0
    begin
      tokens = File.read(TOKEN_LIST_FILE).split(/\r?\n/).map{|s| s.split[0]}
    rescue Exception => e
      sleep 1
      retry_ctr += 1
      raise e if retry_ctr >= 3
      retry
    end
    
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    https.ca_path = '/etc/ca-certificates/extracted/cadir'
    https.verify_mode = OpenSSL::SSL::VERIFY_PEER
    https.start {
      tokens.each do |token|
        h = {
          to: token,
          priority: 'high',
          time_to_live: 300,
          notification: {
            title: '時報',
            body: hhmm,
            tag: 'timesignal',
          },
        }
        
        json = JSON.dump(h)
        
        res = https.post(uri.path, json, header)
        $stderr.puts res.class
        $stderr.puts res.body
      end
    }
  end
  
end

class Registerer

  def initialize
    @notifier = Notifier.new
    
    @srv = WEBrick::HTTPServer.new({ DocumentRoot: '/',
                                    BindAddress: '127.0.0.1',
                                    Port: 18081 })
    @srv.mount_proc('/atimesignal/register') do |req, res|
      serve req, res
    end
  end
  
  def run
    @srv.start
  end
  
  private
  
  def serve(req, res)
    json = req.body
    h = JSON.load(json)
    token = h['token']
    $stderr.puts token
    
    tokens = {}
    File.read(TOKEN_LIST_FILE).split(/\r?\n/).each do |line|
      k, v = line.split
      tokens[k] = v
    end
    tokens[token] = DateTime.now.new_offset(1.0 / 24 * 9).iso8601(6)
    File.open("#{TOKEN_LIST_FILE}.new", 'w') do |f|
      tokens.each_pair do |k, v|
        f.print "#{k}\t#{v}\n"
      end
    end
    
    begin
      File.unlink TOKEN_LIST_FILE
    rescue Exception
    end
    File.rename "#{TOKEN_LIST_FILE}.new", TOKEN_LIST_FILE
  end
  
end

fork do
  srv = Registerer.new
  srv.run
end

class Watcher
  SECS_PER_NOTIFICATION = 30 * 60
  # SECS_PER_NOTIFICATION = 30
  
  def initialize
    @notifier = Notifier.new
  end
  
  def run
    while true
      now = Time.now.localtime.to_i
      old_hhmm_ctr = now / SECS_PER_NOTIFICATION
      secs = SECS_PER_NOTIFICATION - now % SECS_PER_NOTIFICATION
      # $stderr.puts "sleep #{secs}"
      sleep secs

      # うるう秒対応のつもり
      # glibc がうるう秒をカウントしないことが前提
      # そして、長くなる方のみ対応。
      2.times do
        now = Time.now.localtime.to_i
        new_hhmm_ctr = now / SECS_PER_NOTIFICATION
        break if new_hhmm_ctr != old_hhmm_ctr
        # $stderr.puts "sleep 1"
        sleep 1
      end

      @notifier.notify
    end
  end

end

fork do
  w = Watcher.new
  w.run
end
