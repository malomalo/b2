class B2
  class Bucket

    attr_reader :id, :name, :account_id, :revision
    
    def initialize(attrs, connection)
      @id = attrs['bucketId']
      @name = attrs['bucketName']
      
      @account_id = attrs['accountId']
      @revision = attrs['revision']
      
      @connection = connection
    end
    
    def get_upload_token
      @connection.post("/b2api/v1/b2_get_upload_url", { bucketId: @id })
    end
    
    def upload_file(key, io_or_string, mime_type: nil, sha1: nil, info: {})
      upload = get_upload_token
  
      uri = URI.parse(upload['uploadUrl'])
      conn = Net::HTTP.new(uri.host, uri.port)
      conn.use_ssl = uri.scheme == 'https'

      chunker = sha1 ? io_or_string : B2::UploadChunker.new(io_or_string)
      req = Net::HTTP::Post.new(uri.path)
      req['Authorization']      = upload['authorizationToken']
      req['X-Bz-File-Name']     = B2::File.encode_filename(key)
      req['Content-Type']       = mime_type || 'b2/x-auto'
      req['X-Bz-Content-Sha1']  = sha1 ? sha1 : 'hex_digits_at_end'
      info.each do |key, value|
        req["X-Bz-Info-#{key}"] = value
      end
      req['Content-Length']     = chunker.size
      req.body_stream           = chunker

      resp = conn.start { |http| http.request(req) }
      result = if resp.is_a?(Net::HTTPSuccess)
        JSON.parse(resp.body)
      else
        raise "Error connecting to B2 API"
      end
      
      B2::File.new(result, @connection)
    end
    
    def has_key?(key)
      !@connection.post('/b2api/v1/b2_list_file_names', {
        bucketId: @id,
        startFileName: key,
        maxFileCount: 1,
        prefix: key
      })['files'].empty?
    end

    def file(key)
      file = @connection.post('/b2api/v1/b2_list_file_names', {
        bucketId: @id,
        startFileName: key,
        maxFileCount: 1,
        prefix: key
      })['files'].first

      file ? B2::File.new(file.merge({'bucketId' => @id}), @connection) : nil
    end
    
    def download(key, to=nil, &block)
      to = File.open(to, 'w') if to.is_a?(String)
      data = ""
      digestor = Digest::SHA1.new

      uri = URI.parse(@connection.download_url)
      conn = Net::HTTP.new(uri.host, uri.port)
      conn.use_ssl = uri.scheme == 'https'
    
      conn.get("/file/#{@name}/#{key}") do |response|
        
        response.read_body do |chunk|
          digestor << chunk
          if to
            to << chunk
          elsif block
            block(chunk)
          else
            data << chunk
          end
        end
        
        if digestor.hexdigest != resp['X-Bz-Content-Sha1']
          raise 'file error'
        end
        
      end
      block.nil? && to.nil? ? data : nil
    end
    
    def delete!(key)
      file(key).delete!
    end

  end
end