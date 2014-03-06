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

def prepare_metrics_data(sources)
  infos = []
  sources.each do |source|
    response = fetch_metrics_detailed(source[:url])
    json = JSON.parse(response.body)['meters']
    info = {
        title: source[:name],
        logs: get_logs(json),
        access: get_access(json)
    }

    infos << info
  end
  infos
end

def get_logs(json)
  result = []
  json.each do |k,v|
    if k =~ /.*Appender\.(error)|(warn)/
        log = {
            name: k[k.rindex('.')+1..-1],
            count: v['count']
        }
      result << log
    end
  end
  result
end

def get_access(json)
  accesses = []
  json.each do |k,v|
    unless k =~ /.*Appender.*/
      access = {
          name: k,
          count: v['count']
      }
      accesses << access
    end
  end
  accesses
end

def prepare_hotness_data(envs)
  result = []

  envs.each do |env|
    response = fetch_metrics_detailed(env['url'])
    json = JSON.parse(response.body)['meters']

    logs = get_logs(json)
    logs.each do |log|
      data_id = "#{env['prefix']} #{log[:name]}"
      result << {
          key: data_id,
          value: log[:count],
          hotness: 'hotness'
      }
    end

    accesses = get_access(json)
    accesses.each do |access|
      data_id = "#{env['prefix']} #{access[:name]}"
      result << {
          key: data_id,
          value: access[:count],
          hotness: 'hotness'
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
    val = metric[:value].to_f

    avg = list.inject{ |sum, el| sum + el }.to_f / list.size

    diff = val > avg ? val / avg : avg / val
    diff = diff.nan? ? 0 : diff

    if diff <= 1.2
      metric[:hotness] += '0'
    elsif diff <= 1.4
      metric[:hotness] += '1'
    elsif diff <= 1.6
      metric[:hotness] += '2'
    elsif diff <= 1.8
      metric[:hotness] += '3'
    else
      metric[:hotness] += '4'
    end

    list << val
    if list.length > 4 * 48
      list.shift
    end
  end
end

SCHEDULER.every '15m', :first_in => 0 do
  metrics = prepare_hotness_data(envs)
  update_hotness(metrics, dataMap)
  send_event('metrics', {items: metrics})
  puts 'pushed new metrics event'
end
