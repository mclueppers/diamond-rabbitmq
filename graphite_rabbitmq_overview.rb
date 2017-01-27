#!/usr/bin/env ruby
###############################################################################
#
#  Script to get RabbitMQ metrics using API requests, v0.1.0
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
nodes_metrics = %W[mem_used mem_limit disk_free disk_free_limit proc_used 
	proc_total fd_used fd_total run_queue]

vhosts_metrics = %W[message_stats.publish message_stats.publish_details.rate 
	messages messages_details.rate messages_ready messages_ready_details.rate 
	messages_unacknowledged messages_unacknowledged_details.rate recv_oct 
	recv_oct_details.rate send_oct send_oct_details.rate]

overview_metrics = %W[queue_totals.messages_unacknowledged_details.rate 
	queue_totals.messages_ready_details.rate queue_totals.messages_details.rate 
	queue_totals.messages queue_totals.messages_unacknowledged queue_totals.messages_ready 
	object_totals.exchanges object_totals.connections object_totals.channels 
	object_totals.queues object_totals.consumers statistics_db_event_queue]

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

%w[vhosts nodes overview].each do |target|
	stat = JSON.parse(fetch_url("http://#{RABBITMQ_SERVER}/api/#{target}", RABBITMQ_USER, RABBITMQ_PASS))
	case target
	when 'nodes'
		nodes_metrics.sort.each do |metric|
			value = get_metric(stat[0], metric)
			puts "rabbitmq.overview.#{metric} #{value}"
		end
	when 'vhosts'
		vhosts_metrics.sort.each do |metric|
			value = get_metric(stat[0], metric)
			puts "rabbitmq.overview.#{metric} #{value}"
		end
	when 'overview'
		overview_metrics.sort.each do |metric|
			value = get_metric(stat, metric)
			puts "rabbitmq.overview.#{metric} #{value}"
		end
	end
end
