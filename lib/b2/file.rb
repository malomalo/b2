class B2
  class File

    attr_reader :id, :name, :account_id, :bucket_id, :size, :sha1, :mime_type, :uploaded_at, :metadata
    
    def initialize(attrs, connection)
      @id = attrs['fileId']
      @name = B2::File.decode_filename(attrs['fileName'])
      @account_id = attrs['accountId']
      @bucket_id = attrs['bucketId']
      @size = attrs['contentLength']
      @sha1 = attrs['contentSha1']
      @mime_type = attrs['contentType']
      @uploaded_at = attrs['uploadTimestamp']
      @metadata = attrs['fileInfo']
      
      @connection = connection
    end
    
    def self.encode_filename(str)
      URI.encode_www_form_component(str.force_encoding(Encoding::UTF_8)).gsub("%2F", "/")
    end
    
    def self.decode_filename(str)
      URI.decode_www_form_component(str, Encoding::UTF_8)
    end
    
    def delete!
      @connection.post('/b2api/v2/b2_delete_file_version', {
        fileId: @id,
        fileName: @name
      })
    end

  end
end