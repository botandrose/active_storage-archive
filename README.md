# active_storage-archive

Moves Active Storage blobs into cold storage, such as S3 Glacier Deep Archive, while keeping their rows, and guards every read of an archived blob.

```ruby
gem "active_storage-archive"
```

```ruby
blob.archive!  # tags the S3 object and records archived_at in the blob's metadata
blob.archived? # => true
blob.url       # raises ActiveStorage::Archive::ArchivedError, as do download, download_chunk, and open
```

Archiving only tags the object. Add a bucket lifecycle rule that transitions objects with that tag to the storage class you want.

```ruby
ActiveStorage::Archive.configure do |config|
  config.tag = { "archived" => "true" } # the default
  config.fallback = ->(blob, disposition) { ... } # where links to an archived blob redirect; without one they answer 410 Gone
end
```

Restoring is manual: restore the object in S3, copy it back into a readable storage class, and remove `archived_at` from the blob's metadata.

## License

MIT
