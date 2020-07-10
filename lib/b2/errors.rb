class B2

  class Error < StandardError
  end
  
  class NotFound < Error
  end

  class FileIntegrityError < Error
  end
  
  class ExpiredAuthToken < Error
  end

end