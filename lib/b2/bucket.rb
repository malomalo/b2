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
      @connection.post("/b2api/v2/b2_get_upload_url", { bucketId: @id })
    end
    
    def upload_file(key, io_or_string, mime_type: nil, sha1: nil, content_disposition: nil, info: {})
      upload = get_upload_token
  
      uri = URI.parse(upload['uploadUrl'])
      conn = Net::HTTP.new(uri.host, uri.port)
      conn.use_ssl = uri.scheme == 'https'

      chunker = sha1 ? io_or_string : B2::UploadChunker.new(io_or_string)
      req = Net::HTTP::Post.new(uri.path)
      req['Authorization']      = upload['authorizationToken']
      req['X-Bz-File-Name']     = B2.encode(key)
      req['Content-Type']       = mime_type || 'b2/x-auto'
      req['X-Bz-Content-Sha1']  = sha1 ? sha1 : 'hex_digits_at_end'
      req['X-Bz-Info-b2-content-disposition'] = B2.encode(content_disposition) if content_disposition
      info.each do |key, value|
        req["X-Bz-Info-#{key}"] = B2.encode(value)
      end
      req['Content-Length']     = chunker.size
      req.body_stream           = chunker

      resp = conn.start { |http| http.request(req) }
      result = if resp.is_a?(Net::HTTPSuccess)
        JSON.parse(resp.body)
      else
        raise "Error connecting to B2 API #{resp.body}"
      end
      
      B2::File.new(result, @connection)
    end
  
    def keys(prefix: nil, delimiter: nil)
      #TODO: add abilty to get all names
      @connection.post('/b2api/v2/b2_list_file_names', {
        bucketId: @id,
        maxFileCount: 1000,
        prefix: prefix,
        delimiter: delimiter
      })['files'].map{ |f| f['fileName'] }
    end
    
    def has_key?(key)
      !@connection.post('/b2api/v2/b2_list_file_names', {
        bucketId: @id,
        startFileName: key,
        maxFileCount: 1,
        prefix: key
      })['files'].empty?
    end

    def file(key)
      file = @connection.post('/b2api/v2/b2_list_file_names', {
        bucketId: @id,
        startFileName: key,
        maxFileCount: 1,
        prefix: key
      })['files'].first

      file ? B2::File.new(file.merge({'bucketId' => @id}), @connection) : nil
    end
    
    def get_download_url(key, **options)
      @connection.get_download_url(@name, key, **options)
    end

    def download(key, to=nil, &block)
      @connection.download(@name, key, to, &block)
    end
    
    def delete!(key)
      file(key).delete!
    end

  end
end
