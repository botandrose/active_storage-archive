# frozen_string_literal: true

require_relative "lib/active_storage/archive/version"

Gem::Specification.new do |spec|
  spec.name = "active_storage-archive"
  spec.version = ActiveStorage::Archive::VERSION
  spec.authors = ["Micah Geisel"]
  spec.email = ["micah@botandrose.com"]

  spec.summary = "Archive Active Storage originals into cold storage after they age, and unarchive them on demand."
  spec.homepage = "https://github.com/botandrose/active_storage-archive"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ gemfiles/ Appraisals .github/])
    end
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "activestorage", ">= 8.1"
end
