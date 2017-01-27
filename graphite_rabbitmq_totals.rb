#!/usr/bin/env ruby
###############################################################################
#
#  Script to get RabbitMQ total rates metrics using API requests, v0.1.0
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

# Metrics to collect
metrics = %W[messages_ready messages_unacknowledged messages 
	message_stats.publish_details.rate message_stats.deliver_details.rate 
	message_stats.ack_details.rate]

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

def get_metric(data, metric)
	mtric = metric.split('.')
	if mtric.length == 1
		if !data.nil? and data.has_key?(metric)
			data[metric]
		else
			0
		end
	else
		key = mtric.shift
		if data.has_key?(key)
			get_metric(data[key], mtric.join('.'))
		else
			0
		end
	end
end

totals = {}
stat = JSON.parse(fetch_url("http://#{RABBITMQ_SERVER}/api/queues", RABBITMQ_USER, RABBITMQ_PASS))

stat.each do |queue|
	metrics.sort.each do |metric|
		value = get_metric(queue, metric)
		if ! totals.has_key?(metric)
			totals[metric] = 0
		end
		totals[metric] += value.to_i
	end
end

totals.sort.each do |metric, value|
	puts "rabbitmq.queues.#{metric} #{value}"
end
