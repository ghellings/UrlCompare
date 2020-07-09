#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'optparse'
require 'optparse/uri'
require 'ostruct'
require 'differ'
require 'damerau-levenshtein'

options = {
  slow: 2,
  maxlev: 12
}

OptionParser.new do |opts|
  opts.banner = "Usage: urlcompare [OPTIONS]"
  opts.on("-1 FIRST_URL","--first_url=FIRST_URL",URI, "First URL to compare") do |first|
    options[:first] = first
  end
  opts.on("-2 SECOND_URL","--second_url=SECOND_URL",URI, "Second URL to compare") do |second|
    options[:second] = second
  end
  opts.on("-q TEXTFILE", "--queries=TEXTFILE",String, "Text file containing queries to compare") do |queries|
    options[:queries] = queries
  end
  opts.on("-p URI_PREFIX", "--prefix=URI_PREFIX",String, "Stuff you want inserted between the url and query") do |prefix|
    options[:prefix] = prefix
  end
  opts.on("-d", "--differ", "Print diff output") do |differ|
    options[:differ] = differ
  end
  opts.on("-s SLOWTIME","--slow SLOWTIME",Numeric, "A number in seconds to trigger 'slow time'" ) do |slow|
    options[:slow] = slow
  end
  opts.on("-m MAXLEV","--max-lev-dist=MAXLEV",Numeric, "Maxium levenshtein distance") do |maxlev|
    options[:maxlev] = maxlev
  end
  opts.on("-l", "--use-lev", "Use levenshtein distance") do |uselev|
    options[:uselev] = uselev
  end
end.parse!

def request_url(url,timeout)
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
    :open_timeout => timeout,
    :read_timeout => timeout
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
line_count = 0
lev = DamerauLevenshtein
while (line = file.gets)
  query = line.gsub(/\A"|"\Z/, '')
  line_count += 1
  begin
    fbody,ftime = request_url("http://#{options[:first]}/#{options[:prefix]}/?#{query}",options[:slow].to_f+0.5)
  rescue StandardError => e
    puts e.message
    next
  end
  begin
    sbody,stime = request_url("http://#{options[:second]}/#{options[:prefix]}/?#{query}",options[:slow].to_f+0.5)
  rescue StandardError => e
    puts e.message
    puts query
    next
  end
  if fbody.size == sbody.size
    time = ( ftime - stime ).abs
    if (time > options[:slow].to_f)
      puts "Slow time '#{time.to_s}' not counted in total: \n#{query}\n"
      next
    end 
  else 
    puts "Query results didn't match : #{query}\n"
    puts "Size difference #{fbody.size} - #{sbody.size}\n"
    if options[:uselev]
      score = lev.distance(fbody.to_s,sbody.to_s,0,options[:maxlev].to_i)
      puts "Levenshtein score: #{score}\n"
    end
    if options[:differ]
      Differ.format = :color
      puts Differ.diff_by_word(fbody,sbody).to_s
    end   
  end
  puts "#{line_count} #{ftime} - #{stime} \n"
  ftime_total = ftime_total + ftime
  stime_total = stime_total + stime
end

puts "Total #{ftime_total} - #{stime_total}\n"
