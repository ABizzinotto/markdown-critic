# frozen_string_literal: true

require 'octokit'
require 'base64'

module MarkdownCritic
  class ContentExtractor
    def initialize(client:, repository:)
      @client = client
      @repository = repository
    end

    def extract_content(filename:, commit_sha:)
      file_content = @client.contents(@repository, path: filename, ref: commit_sha)
      decoded_content = Base64.decode64(file_content.content)

      {
        filename: filename,
        content: decoded_content,
        lines: decoded_content.split("\n")
      }
    end
  end
end
