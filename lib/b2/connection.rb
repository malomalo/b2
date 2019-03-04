require 'cgi'
require 'thread'

class B2
  class Connection
    
    def initialize(key_id, secret, pool: 5, timeout: 5)
      @mutex        = Mutex.new
      @availability = ConditionVariable.new
      @max          = pool
      @timeout      = timeout
      @free_pool    = []
      @used_pool    = []
      
      @key_id = key_id
      @key_secret = secret

      @buckets_cache = []
    end
    
    def account_id
      return @account_id if !@account_id.nil?
      
      @account_id = with_connection { |conn| conn.account_id }
    end

    def with_connection
      conn = @mutex.synchronize do
        cxn = if !@free_pool.empty?
          @free_pool.shift
        elsif @free_pool.size + @used_pool.size < @max
          B2::APIConnection.new(@key_id, @key_secret)
        else
          @availability.wait(@mutex, @timeout)
          @free_pool.shift || B2::APIConnection.new(@key_id, @key_secret)
        end
        
        @used_pool << cxn
        cxn
      end
      
      yield conn
    ensure
      @mutex.synchronize do
        @used_pool.delete(conn)
        @free_pool << conn if conn.active?
        @availability.signal()
      end
    end
    
    def authorization_token
      with_connection { |conn| conn.authorization_token }
    end
    
    def send_request(request, body=nil, &block)
      with_connection { |conn| conn.send_request(request, body, &block) }
    end
    
    def download_url
      with_connection { |conn| conn.download_url }
    end

    def buckets
      post('/b2api/v2/b2_list_buckets', {accountId: account_id})['buckets'].map do |b|
        B2::Bucket.new(b, self)
      end
    end

    def lookup_bucket_id(name)
      bucket = @buckets_cache.find{ |b| b.name == name }
      return bucket.id if bucket
      
      @buckets_cache = buckets
      @buckets_cache.find{ |b| b.name == name }&.id
    end

    def get_download_url(bucket, filename, expires_in: 3_600, disposition: nil)
      response = post("/b2api/v2/b2_get_download_authorization", {
        bucketId: lookup_bucket_id(bucket),
        fileNamePrefix: filename,
        validDurationInSeconds: expires_in,
        b2ContentDisposition: disposition
      })
      url =  download_url + '/file/' + bucket + '/' + filename + "?Authorization=" + response['authorizationToken']
      url += "&b2ContentDisposition=#{CGI.escape(disposition)}" if disposition
      url
    end

    def download(bucket, key, to=nil)
      opened_file = (to && to.is_a?(String))
      to = ::File.open(to, 'wb') if to.is_a?(String)
      digestor = Digest::SHA1.new
      data = ""
    
      uri = URI.parse(download_url)
      conn = Net::HTTP.new(uri.host, uri.port)
      conn.use_ssl = uri.scheme == 'https'

      req = Net::HTTP::Get.new("/file/#{bucket}/#{key}")
      req['Authorization'] = authorization_token
      conn.start do |http|
        http.request(req) do |response|
          case response
          when Net::HTTPSuccess
            response.read_body do |chunk|
              digestor << chunk
              if to
                to << chunk
              elsif block_given?
                yield(chunk)
              else
                data << chunk
              end
            end
      
            if digestor.hexdigest != response['X-Bz-Content-Sha1']
              raise 'file error'
            end
          when Net::HTTPNotFound
            raise B2::NotFound.new(JSON.parse(response.body)['message'])
          else
            begin
              body = JSON.parse(response.body)
              if body['code'] == 'not_found'
                raise B2::NotFound(body['message'])
              else
                raise "#{body['code']} (#{body['message']})"
              end
            rescue
              raise response.body
            end
          end
        end
      end
      
      if opened_file
        to.close
      elsif to
        to.flush
      end
      !block_given? && to.nil? ? data : nil
    end
    
    def get(path, body=nil, &block)
      request = Net::HTTP::Get.new(path)
      
      send_request(request, body, &block)
    end
    
    def post(path, body=nil, &block)
      request = Net::HTTP::Post.new(path)
      
      send_request(request, body, &block)
    end
    
  end
end

