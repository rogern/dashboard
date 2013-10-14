config = YAML.load(File.read("config.yml"))
jenkins_host = config["jenkins"]["host"]
port = config["jenkins"]["port"]
img_path = '/jenkins/static/foo/images/48x48/'

last_builds = {}

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
      
      #Cobertura result
      cobertura_score = "n/a"
      for health in job['healthReport'] do
        if health['description'].include? "Cobertura"
          cobertura_score = health['score'].to_s + "%"
        end
      end
      
      health_url = "http://#{jenkins_host}:#{port}#{img_path}#{icon_url}"
      desc = job['description']
      build = {
        name: name, status: status, health: health_url, color: color, cobertura: cobertura_score
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
