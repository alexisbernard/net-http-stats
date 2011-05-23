require 'net/http' 
require 'tmpdir'

$LOAD_PATH << File.realpath(File.join(File.dirname(__FILE__), '../lib'))

require 'net/http/stats'

uri = URI.parse('http://ftp.ruby-lang.org/pub/ruby/1.8/ruby-1.8.6.tar.gz')

File.open(File.join(Dir.tmpdir, 'ruby-1.8.6.tar.gz'), 'w') do |file|
  response = Net::HTTP.get_response_with_stats(uri) do |resp, bytes|
    file.write(bytes)
    puts "#{resp.bytes_percent}% downloaded at #{(resp.bytes_rate / 1024).to_i} Ko/s, remaining #{resp.left_time.to_i} seconds"
  end
end

rules = {
  :max_time => 5 * 60,
  :max_left_time => 5 * 60,
  :max_size => 50 * 1024 * 1024,
  :min_time => 15
}

content = ''
uri = URI.parse('http://ftp.ruby-lang.org/pub/ruby/1.8/ruby-1.8.6.tar.gz')
response = Net::HTTP.get_response_with_rules(uri, rules) do |resp, bytes|
  content << bytes
end
