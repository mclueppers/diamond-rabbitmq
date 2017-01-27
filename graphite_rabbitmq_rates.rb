#!/usr/bin/env ruby
###############################################################################
#
#  Script to get RabbitMQ rates metrics using API requests, v0.1.0
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
queues_metrics = %W[messages messages_unacknowledged message_stats.ack_details.rate 
	message_stats.deliver_details.rate message_stats.publish_details.rate]

exchanges_metrics = %W[message_stats.publish_in_details.rate 
	message_stats.publish_out_details.rate]

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

%w[exchanges queues].each do |target|
	stat = JSON.parse(fetch_url("http://#{RABBITMQ_SERVER}/api/#{target}", RABBITMQ_USER, RABBITMQ_PASS))

	case target
	when 'exchanges'
		stat.each do |queue|
			exchanges_metrics.sort.each do |metric|
				value = get_metric(queue, metric)
				puts "rabbitmq.exchanges.#{queue['name'].gsub(/[ \[\]\/:.]/, '-')}.#{metric} #{value}"
			end
		end
	when 'queues'
		stat.each do |queue|
			queues_metrics.sort.each do |metric|
				value = get_metric(queue, metric)
				puts "rabbitmq.queues.#{queue['name'].gsub(/[ \[\]\/:.]/, '-')}.#{metric} #{value}"
			end
		end
	end
end
