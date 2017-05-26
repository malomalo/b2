class B2
  class Bucket

    attr_reader :id, :name, :account_id, :revision
    
    def initialize(attrs)
      @id = attrs['bucketId']
      @name = attrs['bucketName']
      
      @account_id = attrs['accountId']
      @revision = attrs['revision']
    end
    
  end
end