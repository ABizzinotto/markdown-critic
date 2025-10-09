# frozen_string_literal: true

require 'octokit'

module MarkdownCritic
  class GithubReviewer
    def initialize(client:, repository:, pr_number:)
      @client = client
      @repository = repository
      @pr_number = pr_number
    end

    def create_review(filename:, errors:, commit_sha:)
      if errors.empty?
        post_summary_comment('✅ Grammar and spelling review complete - looks good!')
        return
      end

      review_comments = errors.map do |error|
        {
          path: filename,
          line: error[:line],
          body: create_suggestion_comment(error[:corrected_line])
        }
      end

      @client.create_pull_request_review(
        @repository,
        @pr_number,
        {
          commit_id: commit_sha,
          event: 'COMMENT',
          comments: review_comments
        }
      )

      post_summary_comment("✅ Grammar and spelling review complete - made #{errors.length} suggestion(s)")
    end

    private

    def create_suggestion_comment(corrected_line)
      "```suggestion\n#{corrected_line}\n```"
    end

    def post_summary_comment(message)
      @client.add_comment(@repository, @pr_number, message)
    end
  end
end
