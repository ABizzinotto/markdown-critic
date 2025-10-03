# frozen_string_literal: true

require 'openai'
require 'json'

module MarkdownCritic
  class GrammarChecker
    MAX_RETRIES = 3

    def initialize
      @client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
    end

    def check(content)
      retries = 0
      previous_error = nil

      while retries < MAX_RETRIES
        messages = build_messages(content: content, error_message: previous_error)

        response = @client.chat(
          parameters: {
            model: model_name,
            response_format: { type: 'json_object' },
            messages: messages,
            temperature: temperature
          }
        )

        result = response.dig('choices', 0, 'message', 'content').strip

        begin
          return JSON.parse(result, symbolize_names: true)
        rescue JSON::ParserError => e
          previous_error = e.message
          retries += 1
        end
      end
    end

    private

    def model_name
      ENV['INPUT_MODEL_NAME'] || 'gpt-4o-mini'
    end

    def temperature
      ENV['INPUT_MODEL_TEMPERATURE']&.to_f || 0.1
    end

    def build_messages(content:, error_message: nil)
      base = [
        { role: 'system', content: system_prompt },
        { role: 'user', content: user_prompt(content) }
      ]

      base << { role: 'assistant', content: assistant_prompt(error_message) } if error_message

      base
    end

    def system_prompt
      <<~PROMPT
        You are a meticulous grammar and style checker. Your task is to analyze the provided markdown content for any grammatical or spelling errors.

        REVIEW INSTRUCTIONS:
        - You must check every line of the provided content.
        - You must identify all spelling and grammatical mistakes.
        - For each mistake, you must provide the line number (1-indexed) and the EXACT same line rewritten with the correction made.
        - If a line contains multiple errors, provide only one corrected version of the line with all errors fixed.
        - If there are no errors, you must return an empty list.
        - Blog posts are written in American English. You must correct any British English spellings to American English.

        GENERAL INSTRUCTIONS:
        - Content will be provided in markdown format with a front matter section.
        - You must ignore the front matter section (the part between the first two lines containing only "---").
        - You must only analyze the main content of the blog post.

        CRITICAL:
        - You must ONLY respond with a JSON object in the specified format below.
        - Your response must contain NO additional text or characters outside of the JSON object.
        - You must check ONLY for spelling and grammatical errors.
        - Do NOT provide suggestions for style, tone, or content changes.
        - Do NOT make any changes to formatting, punctuation, or capitalization unless it is necessary to correct a grammatical error.
        - Do NOT change any code snippets or technical terms.
        - Do NOT change any proper nouns, names, or titles unless they are misspelled.
        - Do NOT make ANY suggestions that aren't to fix a clear grammatical or spelling error.

        ALWAYS respond in the following JSON format:

        {
          "errors": [
            {
              "line": <line_number>,
              "corrected_line": "<corrected_line>"
            },
            ...
          ]
        }

        If no errors are found, return:

        {
          "errors": []
        }

        Ensure that your JSON is properly formatted and can be parsed without errors.
      PROMPT
    end

    def user_prompt(content)
      <<~PROMPT
        Your task is to review the blog post content below for any grammatical or spelling errors.

        #{content}

        Please analyze the content and provide your findings in the specified JSON format.
      PROMPT
    end

    def assistant_prompt(error_message)
      <<~PROMPT
        The previous response could not be parsed as valid JSON.
        It failed with an error: #{error_message}
        Return ONLY valid JSON as specified.
      PROMPT
    end
  end
end
