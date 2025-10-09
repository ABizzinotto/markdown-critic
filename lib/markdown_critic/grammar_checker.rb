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
      processed_content = prepare_numbered_content(content[:content])

      retries = 0
      previous_error = nil

      while retries < MAX_RETRIES
        messages = build_messages(content: processed_content, error_message: previous_error)

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

    def prepare_numbered_content(content)
      lines = content.split("\n")

      # Skip front matter (between first two --- lines)
      start_index = 0
      end_index = lines.length - 1

      first_frontmatter = lines.find_index { |line| line.strip == '---' }
      if first_frontmatter
        second_frontmatter = lines[(first_frontmatter + 1)..-1]&.find_index { |line| line.strip == '---' }
        if second_frontmatter
          start_index = first_frontmatter + second_frontmatter + 2
        end
      end

      content_lines = lines[start_index..end_index]

      numbered_lines = content_lines.map.with_index(start_index + 1) do |line, line_number|
        "#{line_number}: #{line}"
      end

      numbered_lines.join("\n")
    end

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
        - The content will be provided with line numbers in the format "line_number: content"
        - You must check every line of the provided content for spelling and grammatical mistakes.
        - For each mistake, you must provide the EXACT line number and the corrected line content (WITHOUT the line number prefix).
        - If a line contains multiple errors, provide only one corrected version of the line with all errors fixed.
        - If there are no errors, you must return an empty list.
        - Blog posts are written in American English. You must correct any British English spellings to American English.
        - You must NOT make any changes to line breaks, section distribution, or any other formatting.
        - You must NOT make any suggestions for style, tone, or content changes.
        - You must PRESERVE ALL markdown formatting elements including: headers (#), lists (- or *), links, bold (**), italic (*), code blocks (```), inline code (`), blockquotes (>), etc.
        - When correcting a line with formatting elements, keep ALL formatting exactly as it was and ONLY fix spelling/grammar errors in the text content.

        IMPORTANT LINE NUMBER HANDLING:
        - The input will show lines like "5: This is line content"
        - If line 5 has an error, you must return "line": 5 and "corrected_line": "This is line content" (corrected, without the "5: " prefix)
        - You must use the EXACT line numbers shown in the input
        - The front matter has already been excluded from the content you receive.

        CRITICAL:
        - You must ONLY respond with a JSON object in the specified format below.
        - Your response must contain NO additional text or characters outside of the JSON object.
        - You must check ONLY for spelling and grammatical errors.
        - Do NOT provide suggestions for style, tone, or content changes.
        - Do NOT make any changes to formatting, punctuation, or capitalization unless it is necessary to correct a grammatical error.
        - Do NOT change any code snippets or technical terms.
        - Do NOT change any proper nouns, names, or titles unless they are misspelled.
        - Do NOT remove or modify ANY markdown formatting elements (-, *, #, `, ```, >, **, etc.).
        - Do NOT make ANY suggestions that aren't to fix a clear grammatical or spelling error.
        - PRESERVE the exact structure and formatting of each line, only fix spelling and grammar mistakes in the actual text content.

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

        Each line is prefixed with its line number. Use these EXACT line numbers in your response.

        #{content}

        Please analyze the content and provide your findings in the specified JSON format.
        Remember:
        - Return the corrected line content WITHOUT the line number prefix
        - PRESERVE ALL markdown formatting elements exactly as they appear
        - Example: If input is "5: - This is a list item with a typo hre", return "- This is a list item with a typo here" (keep the "- " list indicator)
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
