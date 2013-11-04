config = YAML.load(File.read("config.yml"))
envs = config["buildinfo"]["envs"]

last_infos = []

SCHEDULER.every '60s', :first_in => 0 do |foo|
  infos = []

  envs.each do |env|
    servers = []
    env_ok = ''

    env['urls'].each do |url|
      begin
        parsedUrl = URI.parse(url['url'])

        http = Net::HTTP.new(parsedUrl.host, parsedUrl.port)
        http.use_ssl = true if url['url'] =~ /^https/

        req = Net::HTTP::Get.new(parsedUrl.path)
        res = http.request(req)

        raise 'response code not success' unless res.kind_of? Net::HTTPSuccess

        binfo = JSON.parse(res.body)

        # successful build info HTTP GET
        server = {
          title: url['title'],
          revision: binfo['gitRevision'],
          built: binfo['buildTime'],
          displayversion: env['displayversion'],
          version: binfo['version']
        }

        servers << server
      rescue Exception
        # unsuccessful build info HTTP GET
        env_ok = 'fail'

        server = {
          title: url['title'],
          revision: 'n/a',
          built: 'n/a',
          displayversion: env['displayversion'],
          version: 'n/a'
        }

        servers << server
      end
    end

    info = {
      title: env['title'],
      servers: servers,
      ok: env_ok
    }

    infos << info
  end

  if infos != last_infos
    last_infos = infos
    send_event('buildinfo', { items: infos })
    puts 'pushed new buildinfo event'
  end
end
