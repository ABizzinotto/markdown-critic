# Markdown Critic
Github action to review blog posts for correctness (spelling and grammar).

## Usage

```yaml
name: Markdown Critic Review
on:
  pull_request:
    types: [opened, ready_for_review]

jobs:
  review:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      checks: write
    steps:
      - uses: actions/checkout@v3
      - uses: ombulabs/markdown-critic@main
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          openai-api-key: ${{ secrets.OPENAI_API_KEY }}
```
