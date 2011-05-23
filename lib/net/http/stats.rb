# Add methods to have stats and rules when downloading.
class Net::HTTP
  # This methods has the same behavior than get_response. However the block takes
  # 2 arguments (response and a string of bytes). Bytes must not be retrieve
  # via response.bytes_read, because they have already been read to compute stats.
  #
  #  require 'net/http' 
  #  require 'net/http/stats' 
  #
  #  content = ''
  #  uri = URI.parse('http://ftp.ruby-lang.org/pub/ruby/1.8/ruby-1.8.6.tar.gz') 
  #  response = Net::HTTP.get_response_with_stats(uri) do |resp, bytes| 
  #    content << bytes 
  #    puts "#{resp.bytes_percent}% downloaded at #{(resp.bytes_rate / 1024).to_i} Ko/s, remaining #{resp.left_time.to_i} seconds" 
  #  end
  # This script will print something like:
  #  13% downloaded at 59 Ko/s, remaining 65 seconds
  # See Net::HTTP::Stats to know more about attributes.
  def self.get_response_with_stats(url, &block)
    response = Net::HTTP.get_response(url) do |resp|
      resp.extend(Net::HTTP::Stats)
      resp.initialize_stats
      resp.read_body do |bytes|
        resp.bytes_read += bytes.size
        block.call(resp, bytes) if block
      end
    end
    response
  end 

  # This method works exactly as Net::HTTP.get_response_with_stats, but it takes
  # a 2nd Hash argument which describes rules.
  # Raises Net::HTTP::Stats::MaxSizeExceed, Net::HTTP::Stats::MaxSpentTimeExceed
  # or Net::HTTP::Stats::MaxLeftTimeExceed if a rule isn't respected.
  #   
  #  require 'net/http'
  #  require 'net/http/stats'
  #  
  #  rules = {
  #    # Download is interrupted if spent time is greater (in sec).
  #    :max_time => 5 * 60,
  #    # Download is interrupted if estimated time is greater (in sec).
  #    :max_left_time => 5 * 60,
  #    # Download is interrupted if body is greater (in byte).
  #    :max_size => 50 * 1024 * 1024,
  #    # Wait some time before checking max_time and max_left_time (in sec).
  #    # something between 5 and 20 seconds should be good.
  #    :min_time => 15
  #  }
  #  
  #  content = ''
  #  uri = URI.parse('http://ftp.ruby-lang.org/pub/ruby/1.8/ruby-1.8.6.tar.gz')
  #  response = Net::HTTP.get_response_with_rules(uri, rules) do |resp, bytes|
  #    content << bytes
  #  end
  def self.get_response_with_rules(url, rules, &block)
    response = Net::HTTP.get_response_with_stats(url) do |resp, bytes|
      msg = ''
      if resp.bytes_count > rules[:max_size]
        raise Stats::MaxSizeExceed.new("Response size (#{resp.bytes_count}) exceed maximun content length allowed (#{rules[:max_size]}).", resp)
      elsif resp.spent_time > rules[:max_time]
        raise Stats::MaxSpentTimeExceed.new("Maximun time allowed (#{rules[:max_time]}) have been exceed", resp)
      elsif resp.spent_time > rules[:min_time] and resp.left_time > rules[:max_left_time]
        raise Stats::MaxLeftTimeExceed.new("Left time expected (#{resp.left_time.to_i}) exceed maximun left time allowed (#{rules[:max_left_time]})", resp)
      end
      block.call(resp, bytes) if block
    end
    response
  end
  
  module Stats
    # Body size
    attr_accessor :bytes_count
    
    # Bytes already downloaded
    attr_accessor :bytes_read
    
    # Rate (byte/sec)
    attr_accessor :bytes_rate
    
    # Percent of bytes downloaded
    attr_accessor :bytes_percent
    
    # Spent time (second)
    attr_accessor :spent_time
    
    # Remaining time (second)
    attr_accessor :left_time
    
    # When the download started (Time)
    attr_accessor :started_at
    
    # Called by Net::HTTP.get_response_with_stats.
    def initialize_stats #:nodoc:
      @bytes_count = self['content-length'].to_i
      @bytes_read = 0
      @bytes_rate = 0
      @bytes_percent = 0
      @spend_time = 0
      @left_time = 0
      @started_at = Time.now
    end
    
    # Updates stats.
    def bytes_read=(bytes_read) #:nodoc:
      @bytes_read = bytes_read
      @spent_time = Time.now - @started_at
      @bytes_rate = @bytes_read / @spent_time if @spent_time != 0
      @left_time = (@bytes_count - @bytes_read) / @bytes_rate if @bytes_rate != 0
      @bytes_percent = @bytes_read * 100 / @bytes_count if @bytes_count != 0
      @bytes_read
    end
    
    # Generic error class. Should not be instanced.
    class Error < Net::HTTPError
    end
    
    # Raised if downloaded file is too big.
    class MaxSizeExceed < Net::HTTP::Stats::Error
    end
    
    # Raised if spent time is to long.
    class MaxSpentTimeExceed < Net::HTTP::Stats::Error
    end
    
    # Raised if remaining time is too long.
    class MaxLeftTimeExceed < Net::HTTP::Stats::Error
    end
  end
end

