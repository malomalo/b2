class B2
  class APIConnection
    
    attr_reader :account_id, :application_key, :download_url
    
    def initialize(account_id, application_key)
      @account_id = account_id
      @application_key = application_key
    end
    
    def connect!
      conn = Net::HTTP.new('api.backblazeb2.com', 443)
      conn.use_ssl = true
      
      req = Net::HTTP::Get.new('/b2api/v2/b2_authorize_account')
      req.basic_auth(account_id, application_key)

      key_expiration = Time.now.to_i + 86_400 #24hr expiry
      resp = conn.start { |http| http.request(req) }
      if resp.is_a?(Net::HTTPSuccess)
        resp = JSON.parse(resp.body)
      else
        raise "Error connecting to B2 API"
      end

      uri = URI.parse(resp['apiUrl'])
      @connection = Net::HTTP.new(uri.host, uri.port)
      @connection.use_ssl = uri.scheme == 'https'
      @connection.start

      @auth_token_expires_at = key_expiration
      @minimum_part_size = resp['absoluteMinimumPartSize']
      @recommended_part_size = resp['recommendedPartSize']
      @auth_token = resp['authorizationToken']
      @download_url = resp['downloadUrl']
      @buckets_cache = []
    end
    
    def disconnect!
      if @connection
        @connection.finish if @connection.active?
        @connection = nil
      end
    end
    
    def reconnect!
      disconnect!
      connect!
    end
    
    def authorization_token
      if @auth_token_expires_at.nil? || @auth_token_expires_at <= Time.now.to_i
        reconnect!
      end
      @auth_token
    end
    
    def active?
      !@connection.nil? && @connection.active?
    end
    
    def connection
      reconnect! if !active?
      @connection
    end

    def send_request(request, body=nil, &block)
      request['Authorization'] = authorization_token
      request.body = (body.is_a?(String) ? body : JSON.generate(body)) if body
      
      return_value = nil
      close_connection = false
      connection.request(request) do |response|
        close_connection = response['Connection'] == 'close'
        
        case response
        when Net::HTTPSuccess
          if block_given?
            return_value = yield(response)
          else
            return_value = JSON.parse(response.body)
          end
        else
          raise "Error connecting to B2 API #{response.body}"
        end
      end
      disconnect! if close_connection

      return_value
    end
    
  end
end