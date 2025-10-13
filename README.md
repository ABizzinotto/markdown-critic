# Markdown Critic
Github action to review blog posts for correctness (spelling and grammar).

## Usage

```yaml
name: Markdown Critic Review
on:
  pull_request:
    types: [opened, ready_for_review]
  workflow_dispatch:
    inputs:
      branch:
        description: "Branch to run the review on"
        required: true
        type: string
      pr_number:
        description: "PR number to review"
        required: true
        type: number

jobs:
  review:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      checks: write
    steps:
      - uses: actions/checkout@v3
        with:
          ref: ${{ github.event.inputs.branch || github.head_ref }}
      - uses: ombulabs/markdown-critic@main
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          openai-api-key: ${{ secrets.OPENAI_API_KEY }}
          github-pr-number: ${{ github.event.inputs.pr_number || '' }}
```
