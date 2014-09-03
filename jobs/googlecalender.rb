#!/usr/bin/env ruby
# encoding: utf-8

require 'net/http'
require 'net/https'
require 'rexml/document'
require 'date'
require 'erb'
require 'htmlentities'

config = YAML.load(File.read("config.yml"))
url_to_calendar = config["calendar"]["url"]
developers = config["calendar"]["developers"]

class Event
  attr_accessor :title, :start_time, :end_time

  def initialize(title, start_time, end_time)
    @start_time = DateTime.parse(start_time)
    @end_time = DateTime.parse(end_time)
    @title = title
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

SCHEDULER.every '5m', :first_in => 0 do |foo|
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

  doc.elements.each('feed/entry/title'){ |e| titles << HTMLEntities.new.decode(e.text) }
  doc.elements.each('feed/entry/content'){ |e| content << e.text }

  events = []

  titles.each_with_index do |title, idx|
    if content[idx] =~ /.*:\s\S+\s(\d+-\d+-\d+) till\s\S+\s(\d+-\d+-\d+)/
      events << Event.new(title, $1, $2)
    elsif content[idx] =~ /.*:\s\S+\s(\d+-\d+-\d+)\s(\d+:\d+)\still\s(\d+:\d+).*/
      event_start = $1 + "T" + $2 + ":00+02.00"
      event_end = $1 + "T" + $3 + ":00+02.00"
      events << Event.new(title, event_start, event_end)
    end
  end

  free = []
  other = []

  events.each do |event|
    if (event.start_time != event.end_time) && (event.end_time <= DateTime.now)
      next
    end

    if event.title =~ /(semester)/i || event.title =~ /(ledig)/i || event.title =~ /(klämdag)/i
      free << developers.select{ |name| event.title.include? name}
    else
      other << title
    end
  end

  todays_events = {
    free: free, other: other
  }

  if todays_events != last_events
    last_events = todays_events
    send_event('calendar', { items: todays_events })
    puts 'pushed new calendar event'
  end
end
