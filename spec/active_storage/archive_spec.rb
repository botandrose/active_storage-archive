# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveStorage::Archive do
  let(:blob) { ActiveStorage::Blob.create_and_upload!(io: File.open("spec/support/fixtures/image.png"), filename: "image.png") }

  describe "archiving a blob" do
    it "remembers when" do
      freeze_time do
        blob.archive!

        expect(blob.reload).to be_archived
        expect(blob.metadata["archived_at"]).to eq(Time.current.iso8601)
      end
    end

    it "keeps metadata written since the blob was loaded" do
      ActiveStorage::Blob.find(blob.id).update!(metadata: { "analyzed" => true })

      blob.archive!

      expect(blob.reload.metadata).to include("analyzed" => true, "archived_at" => be_present)
    end

    it "is a no-op when already archived" do
      blob.archive!

      expect { blob.archive! }.not_to change { blob.reload.metadata["archived_at"] }
    end

    it "tags the object for the bucket's lifecycle rule" do
      described_class.tag = { "smh-archive" => "original" }
      s3_blob = ActiveStorage::Blob.create!(key: "abc", filename: "a.mov", byte_size: 1, checksum: "x", service_name: "s3")

      s3_blob.archive!

      tagging = s3_blob.service.client.client.api_requests.find { |request| request[:operation_name] == :put_object_tagging }
      expect(tagging[:params]).to include(bucket: "media", key: "abc", tagging: { tag_set: [{ key: "smh-archive", value: "original" }] })
    ensure
      described_class.tag = { "archived" => "true" }
    end
  end

  describe "reading a blob" do
    it "works until it is archived" do
      expect(blob.download).to eq(File.binread("spec/support/fixtures/image.png"))
      expect(blob.download_chunk(0..3)).to eq(File.binread("spec/support/fixtures/image.png", 4))
      expect(blob.open(&:size)).to eq(File.size("spec/support/fixtures/image.png"))
    end

    it "raises once it is archived" do
      blob.archive!

      expect { blob.url }.to raise_error(ActiveStorage::Archive::ArchivedError, /#{blob.key}/)
      expect { blob.download }.to raise_error(ActiveStorage::Archive::ArchivedError)
      expect { blob.download_chunk(0..3) }.to raise_error(ActiveStorage::Archive::ArchivedError)
      expect { blob.open { } }.to raise_error(ActiveStorage::Archive::ArchivedError)
    end
  end

  describe "links to an archived blob", type: :request do
    after { described_class.fallback = nil }

    it "redirect to the app's fallback" do
      described_class.fallback = ->(archived, disposition) { "https://cdn.example.com/#{archived.key}.mp4?#{disposition}" }
      blob.archive!

      get rails_blob_path(blob, disposition: "attachment")

      expect(response).to redirect_to("https://cdn.example.com/#{blob.key}.mp4?attachment")
    end

    it "redirect through the proxy controller too" do
      described_class.fallback = ->(archived, _) { "https://cdn.example.com/#{archived.key}.mp4" }
      blob.archive!

      get rails_storage_proxy_path(blob)

      expect(response).to redirect_to("https://cdn.example.com/#{blob.key}.mp4")
    end

    it "are gone without a fallback" do
      blob.archive!

      get rails_blob_path(blob)

      expect(response).to have_http_status(:gone)
    end

    it "are gone when the fallback has nothing" do
      described_class.fallback = ->(*) { nil }
      blob.archive!

      get rails_blob_path(blob)

      expect(response).to have_http_status(:gone)
    end

    it "pass through while the blob isn't archived" do
      get rails_blob_path(blob)

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include("/rails/active_storage/disk/")
    end
  end

  it "is configured through a block" do
    described_class.configure { |config| config.tag = { "cold" => "yes" } }

    expect(described_class.tag).to eq("cold" => "yes")
  ensure
    described_class.tag = { "archived" => "true" }
  end
end
