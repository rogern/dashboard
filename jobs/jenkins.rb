config = YAML.load(File.read("config.yml"))
jenkins_host = config["jenkins"]["host"]
port = config["jenkins"]["port"]
img_path = '/jenkins/static/foo/images/48x48/'

last_builds = {}

def fetch_build_coverage (host, port, job, build)
  jacoco = "jacoco/api/json"
  cobertura = "cobertura/api/json?depth=2"
  plugin = (job.downcase.include? "javascript") ? cobertura : jacoco
  http = Net::HTTP.new(host, port)
  path = "/jenkins/job/#{job}/#{build}/#{plugin}"
  response = http.request(Net::HTTP::Get.new(path))
  
  begin
    body = JSON.parse(response.body)
  rescue Exception
    body = nil
  end
  
  if !body.nil? and job.downcase.include? "javascript"
    cobertura_to_hash(body["results"]["elements"])
  elsif !body.nil?
    body
  else
    {}
  end
end

def cobertura_to_hash(array)
  hash = {};
  array.inject(hash) {|hsh, val| hsh[val["name"]] = val; hsh}
  hash
end

def calc_mean_coverage(data)
  count = 0
  val = 0
  data.each do |key, value|
    if key.downcase.include? "method" or key.downcase.include? "line"
      count += 1
      val += (value["percentage"].nil?) ? value["ratio"] : value["percentage"]
    end
  end
  mean = (count == 0) ? nil : (val / count).to_i
end

def output_percentage(val)
  (val.nil?) ? "n/a" : "#{val}%"
end

SCHEDULER.every '10s', :first_in => 0 do |foo|
  builds = []

  begin
    http = Net::HTTP.new(jenkins_host, port)
    response = http.request(Net::HTTP::Get.new("/jenkins/view/Dashboard/api/json?depth=1"))

    jobs = JSON.parse(response.body)["jobs"]

    jobs.map! do |job|
      name = job['name']
      color = job['color'].sub('blue', 'green')
      status = case color
                 when 'green' then 'Success'
                 when 'yellow' then 'Unstable'
                 when 'disabled' then 'Disabled'
                 when 'gray' then 'Disabled'
                 when 'aborted' then 'Aborted'
                 when 'green_anime' then 'Building'
                 when 'red_anime' then 'Building'
                 when 'gray_anime' then 'Building'
                 when 'aborted_anime' then 'Building'
                 when 'yellow_anime' then 'Building'
                 else 'Failure'
               end
      icon_url = job['healthReport'][0]['iconUrl']
      
      #Coverage result
      coverage_data = fetch_build_coverage(jenkins_host, port, name, job["lastCompletedBuild"]["number"])
      coverage = calc_mean_coverage(coverage_data)
      
      health_url = "http://#{jenkins_host}:#{port}#{img_path}#{icon_url}"
      desc = job['description']
      build = {
        name: name, status: status, health: health_url, color: color, coverage: output_percentage(coverage)
      }
      desc.empty? || build['desc'] = desc
      builds << build
    end
  rescue Exception
    
  end

  if builds != last_builds
    last_builds = builds
    send_event('jenkins', { items: builds })
    puts 'pushed new jenkins event'
  end
end


