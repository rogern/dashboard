require 'openssl'
require 'base64'
require 'net/http'
require 'date'
require 'rufus/scheduler'
require 'json'

config = YAML.load(File.read("config.yml"))
envs = config["metrics"]["envs"]
dataMap = {}

def fetch_metrics_detailed(url)
  key = OpenSSL::PKey::RSA.new(File.read("private_key.pem"))
  data = DateTime.now.strftime('%Q')
  key_sign = key.sign(OpenSSL::Digest::SHA256.new, data)
  signature = Base64.encode64(key_sign).tr("\n", '')

  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = (uri.scheme == 'https')
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  response = http.get2(uri.path, 'X-RSA-signature' => signature, 'X-signed-timestamp' => data)

  response
end

def get_meters(json)
  result = []
  json.each do |k,v|
    if k =~ /.*Appender\.(error)|(warn)/ or k !~ /.*Appender.*/
      log = {
          name: k.include?('.') ? k[k.rindex('.')+1..-1] : k,
          count: v['count'],
          m1rate: v['m1_rate']
      }
      result << log
    end
  end
  result
end

def get_counters(json)
  result = []
  json.each do |k,v|
    if k =~ /.*Appender\.(error)|(warn)/ or k !~ /.*Appender.*/
      log = {
          name: k.include?('.') ? k[k.rindex('.')+1..-1] : k,
          count: v['count']
      }
      result << log
    end
  end
  result
end

def prepare_hotness_data(envs)
  result = []

  envs.each do |env|
    response = fetch_metrics_detailed(env['url'])
    json = JSON.parse(response.body)

    meters = get_meters(json['meters'])
    meters.each do |meter|
      data_id = "#{env['prefix']} #{meter[:name]}"
      result << {
          key: data_id,
          value: meter[:m1rate].to_f.round(2),
          hotness: 'hotness',
          suffix: '/min'
      }
    end

    counters = get_counters(json['counters'])
    counters.each do |counter|
      data_id = "#{env['prefix']} #{counter[:name]}"
      result << {
          key: data_id,
          value: counter[:count].to_f.round(2),
          hotness: 'hotness',
          suffix: ''
      }
    end
  end

  result
end

def update_hotness(metrics, dataMap)
  metrics.each do |metric|
    if !dataMap.has_key?(metric[:key])
      dataMap[metric[:key]] = []
    end

    list = dataMap[metric[:key]]
    val = metric[:value]

    avg = list.inject{ |sum, el| sum + el }.to_f / list.size

    diff = val > avg ? val / avg : avg / val
    diff = diff.nan? ? 0 : diff

    if diff <= 2
      metric[:hotness] += '0'
    elsif diff <= 4
      metric[:hotness] += '1'
    elsif diff <= 8
      metric[:hotness] += '2'
    elsif diff <= 16
      metric[:hotness] += '3'
    else
      metric[:hotness] += '4'
    end

    list << val
    if list.length > 60 * 48
      list.shift
    end
  end
end

SCHEDULER.every '1m', :first_in => 0 do
  metrics = prepare_hotness_data(envs)
  update_hotness(metrics, dataMap)
  send_event('metrics', {items: metrics})
  puts 'pushed new metrics event'
end
