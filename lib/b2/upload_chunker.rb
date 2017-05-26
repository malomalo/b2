class B2
  class UploadChunker
    attr_reader :size, :sha1

    def initialize(data)
      @data = data
      @sha_appended = false
      @digestor = Digest::SHA1.new
      @size = if data.is_a?(::File)
        data.size + 40
      elsif data.is_a?(String)
        data.bytesize + 40
      end
    end

    def read(length=nil, outbuf=nil)
      return_value = @data.read(length, outbuf)
  
      if outbuf.nil?
        if return_value.nil? && !@sha_appended
          @sha_appended = true
          @digestor.hexdigest
        else
          @digestor << return_value
          return_value
        end
      else
        if outbuf.empty? && !@sha_appended
          @sha_appended = true
          outbuf.replace(@digestor.hexdigest)
        else
          @digestor << outbuf
        end
        outbuf
      end
    end
  end
end