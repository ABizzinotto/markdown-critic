# frozen_string_literal: true

require_relative 'file_detector'
require_relative 'content_extractor'
require_relative 'grammar_checker'
require_relative 'github_reviewer'

module MarkdownCritic
  class Action
    REPOSITORY = ENV['GITHUB_REPOSITORY']

    def initialize
      @github_client = Octokit::Client.new(access_token: ENV['GITHUB_TOKEN'])
    end

    def self.run
      new.run
    end

    def run
      pr_number, commit_sha = parse_pr_info

      detector = FileDetector.new(
        client: @github_client,
        repository: REPOSITORY,
        pr_number: pr_number
      )

      added_file = detector.added_markdown_file

      if added_file
        extractor = ContentExtractor.new(
          client: @github_client,
          repository: REPOSITORY
        )

        content = extractor.extract_content(
          filename: added_file[:filename],
          commit_sha: commit_sha
        )

        grammar_result = GrammarChecker.new.check(content)
        errors = grammar_result[:errors] || []
        reviewer = GithubReviewer.new(
          client: @github_client,
          repository: REPOSITORY,
          pr_number: pr_number
        )

        reviewer.create_review(
          filename: added_file[:filename],
          errors: errors,
          commit_sha: commit_sha
        )

        puts 'Review complete!'
      else
        puts 'No new markdown file added in the PR.'
        exit 0
      end
    end

    private

    def parse_pr_info
      event_data = JSON.parse(File.read(ENV['GITHUB_EVENT_PATH']))
      pr_number = event_data.dig('pull_request', 'number')
      commit_sha = event_data.dig('pull_request', 'head', 'sha')
      [pr_number, commit_sha]
    end
  end
end
