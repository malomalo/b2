class B2
  class File

    attr_reader :id, :name, :account_id, :bucket_id, :size, :sha1, :mime_type, :uploaded_at, :metadata
    
    def initialize(attrs, connection, bucket: nil)
      @id = attrs['fileId']
      @name = B2.decode(attrs['fileName'])
      @account_id = attrs['accountId']
      @bucket = bucket
      @bucket_id = attrs['bucketId']
      @size = attrs['contentLength']
      @sha1 = attrs['contentSha1']
      @mime_type = attrs['contentType']
      @uploaded_at = attrs['uploadTimestamp']
      @metadata = attrs['fileInfo']
      
      @connection = connection
    end
    
    def delete!
      @connection.post('/b2api/v2/b2_delete_file_version', {
        fileId: @id,
        fileName: @name
      })
    end
    
    def read(to=nil, &block)
      @connection.download(@bucket.name, @name, to, &block)
    end
    
  end
end