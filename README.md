# B2
A Backblaze B2 Client

# Usage

```ruby
b2 = B2.new(account_id: B2_ACCOUNT_ID, application_key: B2_APPLICATION_KEY)

b2.upload('bucket_name', 'key', io_or_string)

b2.download('bucket_name', 'key') # => binary_string

b2.download('bucket_name', 'key') do |chunk|
    # ... process the file as it streams ...
end

b2.download_to_file('bucket_name', 'key', '/path/to/file')

b2.file('bucket_name', 'key') # => #<B2::File>

b2.delete('bucket_name', 'key') # => bool
```