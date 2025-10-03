# frozen_string_literal: true

require 'octokit'
require 'json'

module MarkdownCritic
  class FileDetector
    def initialize(client:, repository:, pr_number:)
      @client = client
      @repository = repository
      @pr_number = pr_number
    end

    def added_markdown_file
      files = @client.pull_request_files(@repository, @pr_number)

      file = files.find do |f|
        f.filename.start_with?('blog/_posts/') &&
          f.filename.end_with?('.md') &&
          f.status == 'added'
      end

      return nil unless file

      {
        filename: file.filename,
        status: file.status,
        sha: file.sha
      }
    end

    def has_changes?
      !added_markdown_file.nil?
    end
  end
end
