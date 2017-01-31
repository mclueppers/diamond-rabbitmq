#!/usr/bin/env ruby
###############################################################################
#
#  AIO Script to get RabbitMQ metrics using API requests, v0.1.0
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
queues_metrics = %W[messages messages_unacknowledged messages_ready
    message_stats.ack_details.rate message_stats.deliver_details.rate
    message_stats.publish_details.rate]

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

# Get metric data 
def get_metric(data, metric)
    mtric = metric.split('.')
    if mtric.length == 1
        if !data.nil? and data.has_key?(metric)
            sprintf '%.4f', data[metric].to_f
        else
            0.0
        end
    else
        key = mtric.shift
        if data.has_key?(key)
            get_metric(data[key], mtric.join('.'))
        else
            0.0
        end
    end
end

# Main script
output = ""
if $0 == __FILE__
    if File.new(__FILE__).flock(File::LOCK_EX | File::LOCK_NB)
        %w[bindings exchanges queues].each do |target|
            benchmarks = { 'apicall': 0.0, 'mainscript': 0.0 }

            stime = Time.now
            stat = JSON.parse(fetch_url("http://#{RABBITMQ_SERVER}/api/#{target}", RABBITMQ_USER, RABBITMQ_PASS))
            benchmarks[:apicall] = ((Time.now - stime) * 1000.0)

            stime = Time.now
            case target
            when 'bindings'
                output << "rabbitmq.queues.bindings #{stat.length.to_s}\r\n"
            when 'exchanges'
                stat.each do |exchange|
                    exchanges_metrics.sort.each do |metric|
                        value = get_metric(exchange, metric)
                        exchange['name'] = '%2f' if exchange['name'] == ''
                        output << "rabbitmq.exchanges.#{exchange['name'].gsub(/[ \[\]\/:.]/, '-')}.#{metric} #{value}\r\n"
                    end
                end
            when 'queues'
                totals = {}
                stat.each do |queue|
                    queues_metrics.sort.each do |metric|
                        value = get_metric(queue, metric)
                        if ! totals.has_key?(metric)
                            totals[metric] = 0
                        end
                        totals[metric] += value.to_i
                        output << "rabbitmq.queues.#{queue['name'].gsub(/[ \[\]\/:.]/, '-')}.#{metric} #{value}\r\n"
                    end
                end
                totals.sort.each do |metric, value|
                    output << "rabbitmq.queues.#{metric} #{value}\r\n"
                end
            end
            puts output
            benchmarks[:mainscript] = ((Time.now - stime) * 1000.0)
            puts sprintf "rabbitmq.diamond_collector.%s.api_call %.4f", target, benchmarks[:apicall]
            puts sprintf "rabbitmq.diamond_collector.%s.main_script %.4f", target, benchmarks[:mainscript]
        end
    else
        raise "another instance of this program is running"
    end
end
