#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'optparse'
require 'ostruct'
require 'differ'

options = OpenStruct.new()

OptionParser.new do |opts|
  opts.banner = "Usage: urlcompare [OPTIONS]"
  opts.on("-1 FIRST_URL","--first_url=FIRST_URL", "First URL to compare") do |first|
    options[:first] = first
  end
  opts.on("-2 SECOND_URL","--second_url=SECOND_URL", "Second URL to compare") do |second|
    options[:second] = second
  end
  opts.on("-q TEXTFILE", "--queries=TEXTFILE", "Text file containing queries to compare") do |queries|
    options[:queries] = queries
  end
  opts.on("-p URI_PREFIX", "--prefix=URI_PREFIX", "Stuff you want inserted between the url and query") do |prefix|
    options[:prefix] = prefix
  end
  opts.on("-d", "--differ", "Print diff output") do |differ|
    options[:differ] = differ
  end
end.parse!

def request_url(url)
  begin
    uri = URI.parse(url)
  rescue => e
    $stderr.puts "Unable to parse URI (  #{url}  ) : #{e}"
    return false
  end
  body = String.new
  start_time = Time.now
  Net::HTTP.start(
    uri.host, 
    uri.port, 
    {"User-Agent" => "UrlCompare"}
  ) do | http |
    request = Net::HTTP::Get.new uri
    response = http.request request
    body = response.body
  end 
  request_time = Time.now - start_time
  return body, request_time
end


begin
  file = File.new(options[:queries], "r")
rescue => e
  raise "unable to read file #{options[:queries]} : #{e}"
end


ftime_total = 0.0
stime_total = 0.0
while (line = file.gets)
  query = line.gsub(/\A"|"\Z/, '')
  fbody,ftime = request_url("http://#{options[:first]}/#{options[:prefix]}/?#{query}")
  sbody,stime = request_url("http://#{options[:second]}/#{options[:prefix]}/?#{query}")
  if fbody.size == sbody.size
    if ( ftime - stime ).abs > 0.5
      puts "Slow: \n#{query}\n"
      next
    end 
    puts "#{ftime} - #{stime} \n"
  else 
    puts "Query results didn't match : #{query}\n"
    puts "Size difference #{fbody.size} - #{sbody.size}\n"
    if options[:differ]
      Differ.format = :color
      puts Differ.diff_by_word(fbody,sbody).to_s
    end
    next
  end
  ftime_total = ftime_total + ftime
  stime_total = stime_total + stime
end

puts "#{ftime_total} - #{stime_total}\n"
