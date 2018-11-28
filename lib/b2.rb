require 'uri'
require 'json'
require 'net/http'

require File.expand_path('../b2/errors', __FILE__)
require File.expand_path('../b2/file', __FILE__)
require File.expand_path('../b2/bucket', __FILE__)
require File.expand_path('../b2/connection', __FILE__)
require File.expand_path('../b2/upload_chunker', __FILE__)

class B2
  
  def initialize(account_id:, application_key:)
    @account_id = account_id
    @connection = B2::Connection.new(account_id, application_key)
  end
  
  def buckets
    @connection.buckets
  end
  
  def file(bucket, key)
    bucket_id = @connection.lookup_bucket_id(bucket)
    
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
      bucketId: @connection.lookup_bucket_id(bucket)
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
  
  def get_download_url(bucket, filename, **options)
    @connection.get_download_url(bucket, filename, **options)
  end
  
  def download(bucket, key, to=nil, &block)
    @connection.download(bucket, key, to, &block)
  end

  
  def download_to_file(bucket, key, filename)
    file = File.open(filename, 'w')
    download(bucket, key) do |chunk|
      file << chunk
    end
    file.close
  end

end