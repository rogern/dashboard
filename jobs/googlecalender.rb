#!/usr/bin/env ruby
# encoding: utf-8


require 'net/http'
require 'net/https'
require 'rexml/document'
require 'date'
require 'erb'

url_to_calendar = 'https://www.google.com/calendar/feeds'
developers=%w{Steve Bill Bob}

class Event 
  attr_accessor :title, :start_time, :end_time

    def initialize(title, start_time, end_time)
      @start_time=Date.parse(start_time)
      @end_time=Date.parse(end_time)
      @title=title
    end  
end

def fetch_feed url
  urltemp = URI.parse(url)
  https = Net::HTTP.new(urltemp.host, urltemp.port)
  https.use_ssl = (urltemp.scheme == 'https')
  https.verify_mode = OpenSSL::SSL::VERIFY_NONE
  request = Net::HTTP::Get.new(url)
  return https.request(request)
end

last_events = {}

SCHEDULER.every '6h', :first_in => 0 do |foo|
  url = url_to_calendar
  today = Date.today.to_s
  tomorrow = (Date.today + 1).to_s
  url = url + '?start-min=' + today
  url = url + '&start-max=' + tomorrow
  response = fetch_feed(url)

  xml_data = response.body
  doc = REXML::Document.new( xml_data )

  titles = []
  content = []

  doc.elements.each('feed/entry/title'){ |e| titles << e.text }
  doc.elements.each('feed/entry/content'){ |e| content << e.text }

  events= []

  titles.each_with_index do |title, idx|
    if content[idx] =~ /.*:\s\S+\s(\d+-\d+-\d+) till\s\S+\s(\d+-\d+-\d+)/
      new_event = Event.new(title, $1, $2)
    elsif content[idx] =~ /.*:\s\S+\s(\d+-\d+-\d+).*/
      new_event = Event.new(title, $1, $1)
    end
    events << new_event
  end


  free = false
  other = false

  events.each do |event|
    if event.title =~ /(semester)/i || event.title =~ /(ledig)/i || event.title =~ /(klämdag)/i
      if free == false
        free = []
      end
      free << developers.select{ |name| event.title.include? name}
    else
      if other == false
        other = []
      end
      other << event.title
    end
  end

  todays_events = {
      free: free, other: other
  }

  if todays_events != last_events
    last_events = todays_events
    send_event('calendar', { items: todays_events })
  end
end

