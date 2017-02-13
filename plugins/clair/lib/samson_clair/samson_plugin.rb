# frozen_string_literal: true
# FIXME: check based on docker_repo_digest not tag
module SamsonClair
  class Engine < Rails::Engine
  end

  class << self
    def append_build_job_with_scan(build)
      return unless clair = ENV['CLAIR_ADDRESS']
      job = build.docker_build_job

      append_output job, "### Clair scan: started\n"

      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          sleep 0.1 if Rails.env.test? # in test we reuse the same connection, so we cannot use it at the same time
          success, output, time = scan(clair, build.docker_repo_digest)
          status = (success ? "success" : "errored or vulnerabilities found")
          output = "### Clair scan: #{status} in #{time}s\n#{output}"
          append_output job, output
        end
      end
    end

    private

    # external builds have no job ... so we cannot store output
    def append_output(job, output)
      if job
        job.reload
        job.update_column(:output, job.output + output)
      else
        Rails.logger.info(output)
      end
    end

    def parse_digest(docker_repo_digest)
      regexp = /^(?:([^\/]+)\/)?(?:(.+)\/)*([^@:\/]+)(?:[@:](.+))?/
      docker_repo_digest.scan(regexp).first
    end

    def extract_realm_service(bearer)
      regexp = /(?:(\w+)=([\w.:\/-]+))/
      Hash[*bearer.gsub('"','').scan(regexp).flatten]
    end

    def docker_login_pass
      registry = Docker.first
      return registry.username, registry.password
    end

    def docker_auth_manifest_request(www_auth, uri, login, password)
      realm_service = extract_realm_service(www_auth[1])
      # Basic authentication is default for us
      #url = realm_service["realm"] + "v2/"
      #if www_auth[0] == "Bearer"
      #  url = realm_service["realm"] + "?service=" + realm_service["service"]
      #end
      #if realm_service["scope"]
      #  url = url + "&scope=" + realm_service["scope"]
      #end
      begin
        http = Net::HTTP.new(uri.host, uri.port)
    #    http.set_debug_output($stdout)
        http.use_ssl = true
        http.start  do |http|
          request = Net::HTTP::Get.new(uri.request_uri)
          request['Accept'] = 'application/vnd.docker.distribution.manifest.v2+json'
          request.basic_auth login, password
          response = http.request request
          return response
        end
      rescue
        raise "Can't connect to docker registry"
      end
    end

    def create_manifest_uri(docker_repo_digest)
      repo, path, image, tag =  parse_digest(docker_repo_digest)
      URI('https://' + [repo, 'v2', path, image,'manifests',tag].join('/'))
    end

    def create_v2_uri(docker_repo_digest)
      repo, path, image, tag =  parse_digest(docker_repo_digest)
      URI('https://' + [repo, 'v2', path, image].join('/'))
    end

    #lURI := fmt.Sprintf("%v/layers/%v?vulnerabilities", uri, id)

    def retrieve_manifests(docker_repo_digest)
      uri = create_manifest_uri(docker_repo_digest)
      Net::HTTP.start(uri.host, uri.port,
                      :use_ssl => uri.scheme == 'https') do |http|
        request = Net::HTTP::Get.new uri.request_uri
        request['Accept'] = 'application/vnd.docker.distribution.manifest.v2+json'
        response = http.request request
        if response.code == "401"
          output = "### Request not authorized, analyzing auth method"
          www_auth = response['Www-Authenticate'].split(' ')
          if %w(Basic Bearer).include?(www_auth[0])
            login, password = docker_login_pass
            return docker_auth_manifest_request(www_auth, uri, login, password).body, output
          else
            output = "### Auth method not support\n#{output}"
            return false, output
          end
        elsif response.code == "200"
          return response.body, output
        else
          output = "### Clair scan: #{status} in #\n#{output}"
          return false, output
        end
      end
    end

    def parse_manifests(body)
      begin
        parsed = JSON.parse(body)
        if parsed['schemaVersion'] == 1
          layer_name='fsLayers'
          digest_name = 'blobSum'
        elsif parsed['schemaVersion'] == 2
          layer_name='layers'
          digest_name='digest'
        else
          output = "### Unknown schema verson"
        end
        parsed[layer_name].collect { |p| p[digest_name] }
      rescue JSON::ParserError
        output = "### Can't parse json body"
        return false, output
      end
    end

    def layer_path(layer, url)
      [url, 'blobs', layer].join('/')
    end

    def authorization_string
      login, pass = docker_login_pass
      "Basic " + Base64.strict_encode64("#{login}:#{pass}")
    end

    def create_payload(layer, url)
      payload = {
        'Layer'=> {
          'Name'       => layer,
          'Path'       => layer_path(layer, url),
          'Headers'    => {
            'Authorization' => authorization_string
          },
          'ParentName' => '',
          'Format'     => 'Docker'
        }
      }
      JSON.generate(payload)
    end

    # TODO clair address environment ?
    def push_single_layer(layer, clair_address, url, http)
      payload = create_payload(layer, url)
      uri = URI(clair_address)
      request = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
      request.body = payload
      response = http.request request
      return response
    end

    def push_layers(layers, clair_address, docker_repo_digest)
      url = create_v2_uri(docker_repo_digest)
      uri = URI(clair_address)
      http = Net::HTTP.new(uri.host, uri.port)
      #http.set_debug_output($stdout)
      http.use_ssl = false
      http.start  do |http|
        layers.each do |layer|
          response = push_single_layer(layer, clair_address, url, http)
          if response.code != "201"
            raise "Can't push data to clair"
          else
            puts "Pushed layer #{layer} to clair"
          end
        end
        layers.each do |layer|
          response, out = analyse_single_layer(layer, clair_address, http)
          output = "#{out}\n#{output}"
          if response.code == "200"
            parsed = JSON.parse(response.body)
            if parsed['Vulnerabilities']
              puts "Found problems with the image #{parsed['Vulnerabilities']['Name']}
                    #{parsed['Vulnerabilities']['Severity']}
                    #{parsed['Vulnerabilities']['Description']}\n #{parsed['Vulnerabilities']['Link']}"
            else
              puts "Layer #{layer} looks clean, going further.."
            end
          end
        end
      end
    end

    def analyse_single_layer(layer, clair_address, http)
      uri = URI(clair_address + '/' + layer + '?vulnerabilities')
      request = Net::HTTP::Get.new(uri.request_uri, 'Content-Type' => 'application/json')
      response = http.request request
      if response.code != "200"
        output = "### Can't analyse #{layer} - clair side error"
        return response, output
      else
        output = "Analysed #{layer}"
        return response, output
      end
    end

    def scan(clair, docker_repo_digest)
      registry = DockerRegistry.first
      # Don't know what to do here ¯\_(ツ)_/¯
      with_time do
        body = retrieve_manifests(docker_repo_digest)
        push_layers(parse_manifests(body), clair, docker_repo_digest)
      end
    end

    def with_time
      result = []
      time = Benchmark.realtime { result = yield }
      result << time
    end
  end
end

Samson::Hooks.callback :after_docker_build do |build|
  if build.docker_repo_digest
    SamsonHyperclair.append_build_job_with_scan(build)
  end
end
