# frozen_string_literal: true

module DummySchema
  def self.load!
    return if @loaded
    @loaded = true

    ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"

    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Schema.define do
        create_table :active_storage_blobs do |t|
          t.string :key, null: false
          t.string :filename, null: false
          t.string :content_type
          t.text :metadata
          t.string :service_name, null: false
          t.bigint :byte_size, null: false
          t.string :checksum
          t.datetime :created_at, null: false
          t.index [:key], unique: true
        end

        create_table :active_storage_attachments do |t|
          t.string :name, null: false
          t.references :record, null: false, polymorphic: true, index: false
          t.references :blob, null: false
          t.datetime :created_at, null: false
        end
      end
    end
  end

  def self.cleanup!
    ActiveStorage::Attachment.delete_all
    ActiveStorage::Blob.delete_all
    FileUtils.rm_rf Rails.root.join("tmp/storage")
  end
end

RSpec.configure do |config|
  config.before(:all) { DummySchema.load! }
  config.after        { DummySchema.cleanup! }
end
