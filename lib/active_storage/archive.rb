# frozen_string_literal: true

require_relative "archive/version"

module ActiveStorage
  module Archive
    class ArchivedError < StandardError; end

    mattr_accessor :tag, default: { "archived" => "true" } # object tag a bucket lifecycle rule moves to cold storage
    mattr_accessor :fallback # ->(blob, disposition) { url } redirects to url; nil answers 410 Gone.

    def self.configure = yield self

    module BlobExtension
      def archived? = metadata["archived_at"].present?

      def archive!
        with_lock do # so a stale copy can't clobber metadata
          next if archived?
          tag_for_archive if service.respond_to?(:bucket)
          update_columns(metadata: metadata.merge("archived_at" => Time.current.iso8601))
        end
      end

      %i[url download download_chunk open].each do |reader|
        define_method(reader) do |*args, **options, &block|
          raise ArchivedError, "#{key} is archived" if archived?
          super(*args, **options, &block)
        end
      end

      private

      def tag_for_archive
        tag_set = Archive.tag.map { |name, value| { key: name, value: } }
        service.client.client.put_object_tagging(bucket: service.bucket.name, key:, tagging: { tag_set: })
      end
    end

    module ControllerExtension
      def show
        if @blob.archived?
          url = Archive.fallback&.call(@blob, params[:disposition])
          url ? redirect_to(url, allow_other_host: true) : head(:gone)
        else
          super
        end
      end
    end

    class Engine < ::Rails::Engine
      config.to_prepare do
        ActiveStorage::Blob.prepend(BlobExtension)
        ActiveStorage::Blobs::RedirectController.prepend(ControllerExtension)
        ActiveStorage::Blobs::ProxyController.prepend(ControllerExtension)
      end
    end
  end
end
