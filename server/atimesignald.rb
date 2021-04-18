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
require 'slack/incoming/webhooks'
require 'google/apis/fcm_v1'

require_relative './conf'

if TOKEN_LIST_FILE.nil?
  raise 'TOKEN_LIST_FILE not set.'
end

if FCM_SDK_JSON.nil?
  raise 'FCM_SDK_JSON not set.'
end

if FCM_PROJECT.nil?
  raise 'FCM_PROJECT not set'
end

FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging'

class Notifier
  def initialize
    @fcm = Google::Apis::FcmV1::FirebaseCloudMessagingService.new
    @fcm.authorization = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: File.open(FCM_SDK_JSON),
      scope: FCM_SCOPE,
    )
  end
  
  def notify()
    hhmm = Time.now.localtime.strftime('%H:%M')

    retry_ctr = 0
    begin
      tokens = File.read(TOKEN_LIST_FILE).split(/\r?\n/).map{|s| s.split[0]}
    rescue Exception => e
      sleep 1
      retry_ctr += 1
      raise e if retry_ctr >= 3
      retry
    end
    
    begin
      @fcm.authorization.fetch_access_token!

      tokens.each do |token|
        msg = ::Google::Apis::FcmV1::SendMessageRequest.new(
          message: {
            android: {
              notification: {
                title: '時報',
                body: hhmm,
                tag: 'timesignal',
                visibility: 'public',    # 意味なさげ?
              },
              priority: 'high',
              ttl: '300s',
            },
            token: token,
          }
        )
        r = @fcm.send_message("projects/#{FCM_PROJECT}", msg)
      end
    rescue => e
      $stderr.puts e.to_s
      $stderr.puts e.backtrace
      slack = Slack::Incoming::Webhooks.new(SLACK_WEBHOOK_URL,
					    channel: '#conoha',
					    username: 'ATimeSignal')
      slack.post "#{e.to_s}\n```#{e.backtrace.join("\n")}```"
    end
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
