require 'uri'
require 'json'
require 'net/http'

require File.expand_path('../b2/file', __FILE__)
require File.expand_path('../b2/bucket', __FILE__)
require File.expand_path('../b2/connection', __FILE__)
require File.expand_path('../b2/upload_chunker', __FILE__)

class B2
  
  def initialize(account_id:, application_key:)
    @account_id = account_id
    @connection = B2::Connection.new(account_id, application_key)
    @buckets_cache = []
  end
  
  def buckets
    @connection.post('/b2api/v1/b2_list_buckets', {accountId: @account_id})['buckets'].map do |b|
      B2::Bucket.new(b, @connection)
    end
  end

  def lookup_bucket_id(name)
    bucket = @buckets_cache.find{ |b| b.name == name }
    return bucket.id if bucket
    
    @buckets_cache = buckets
    @buckets_cache.find{ |b| b.name == name }&.id
  end
  
  def file(bucket, key)
    bucket_id = lookup_bucket_id(bucket)
    
    file = @connection.post('/b2api/v1/b2_list_file_names', {
      bucketId: bucket_id,
      startFileName: key
    })['files'].find {|f| f['fileName'] == key }

    file ? B2::File.new(file.merge({'bucketId' => bucket_id})) : nil
  end
  
  def delete(bucket, key)
    object = file(bucket, key)
    if object
      @connection.post('/b2api/v1/b2_delete_file_version', {
        fileName: file.name,
        fileId: file.id
      })
    else
      false
    end
  end
  
  def get_upload_token(bucket)
    @connection.post("/b2api/v1/b2_get_upload_url", {
      bucketId: lookup_bucket_id(bucket)
    })
  end
  
  def upload_file(bucket, key, io_or_string, mime_type: nil, info: {})
    upload = get_upload_token(bucket)
  
    uri = URI.parse(upload['uploadUrl'])
    conn = Net::HTTP.new(uri.host, uri.port)
    conn.use_ssl = uri.scheme == 'https'

    chunker = B2::UploadChunker.new(io_or_string)
    req = Net::HTTP::Post.new(uri.path)
    req['Authorization']      = upload['authorizationToken']
    req['X-Bz-File-Name']     = B2::File.encode_filename(key)
    req['Content-Type']       = mime_type || 'b2/x-auto'
    req['X-Bz-Content-Sha1']  = 'hex_digits_at_end'
    info.each do |key, value|
      req["X-Bz-Info-#{key}"] = value
    end
    req['Content-Length']     = chunker.size
    req.body_stream           = chunker

    resp = conn.start { |http| http.request(req) }
    if resp.is_a?(Net::HTTPSuccess)
      JSON.parse(resp.body)
    else
      raise "Error connecting to B2 API"
    end
  end
  
  def get_download_url(bucket, filename, expires_in: 3_600)
    response = @connection.post("/b2api/v1/b2_get_download_authorization", {
      bucketId: lookup_bucket_id(bucket),
      fileNamePrefix: filename,
      validDurationInSeconds: expires_in
    })
    @connection.download_url + '/file/' + bucket + '/' + filename + "?Authorization=" + response['authorizationToken']
  end
  
  def download(bucket, filename, &block)
    digestor = Digest::SHA1.new
    data = ""
    
    @connection.get("/file/#{bucket}/#{filename}") do |response|
      response.read_body do |chunk|
        digestor << chunk
        block.nil? ? (data << chunk) : block(chunk)
      end
      if digestor.hexdigest != resp['X-Bz-Content-Sha1']
        raise 'file error'
      end
    end
    block.nil? ? data : nil
  end
  
  def download_to_file(bucket, key, filename)
    file = File.open(filename, 'w')
    download(bucket, key) do |chunk|
      file << chunk
    end
    file.close
  end

end