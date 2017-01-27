#!/usr/bin/env ruby
###############################################################################
#
#  Script to get RabbitMQ bindings metrics using API requests, v0.1.0
#  Copyright (C) 2017 Martin Dobrev
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as
#  published by the Free Software Foundation, either version 3 of the
#  License, or (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.
#
#  You should have received a copy of the GNU Affero General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
###############################################################################

require 'net/http'
require 'json'

# Configuration
RABBITMQ_SERVER='localhost:15672'
RABBITMQ_USER='guest'
RABBITMQ_PASS='guest'

# Fetches URL and returns the result
def fetch_url(target, username = nil, password = nil)
  url = URI.parse("#{target}")
  req = Net::HTTP::Get.new(url.to_s)
  req.basic_auth username, password if ! username.nil? and ! password.nil?
  res = Net::HTTP.start(url.host, url.port) {|http|
      http.request(req)
    }
    return res.body
end

stat = JSON.parse(fetch_url("http://#{RABBITMQ_SERVER}/api/bindings", RABBITMQ_USER, RABBITMQ_PASS))

puts "rabbitmq.queues.bindings #{stat.length.to_s}"