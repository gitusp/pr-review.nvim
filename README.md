pr-review.nvim
===

A Neovim plugin for GitHub PR review workflows focused on reading and navigating pull request information directly from your editor.

## Features

- Browse and select PRs from a searchable list
- Checkout PRs directly from Neovim
- Review PRs with side-by-side diffs using fugitive
- Display PR comments as diagnostics
- Toggle visibility of PR comment threads

## Philosophy

This plugin focuses on **reading and reviewing** PRs rather than writing comments:

- Simplifies the PR review workflow
- Avoids reimplementing the full GitHub web UI
- Stays focused on the strengths of terminal-based workflows
- Minimizes the learning curve with familiar interfaces

## Requirements

- [Git](https://git-scm.com/)
- [GitHub CLI (gh)](https://cli.github.com/)
- [fzf-lua](https://github.com/ibhagwan/fzf-lua)
- [vim-fugitive](https://github.com/tpope/vim-fugitive)

## Example Usage

### Complete PR Review Workflow

1. Find and checkout a PR:
   ```
   :PRBrowse
   ```
   Navigate to the PR you want to review and press `Ctrl-o` to checkout or `Ctrl-r` to checkout and start reviewing.

2. Review the PR with side-by-side diffs:
   ```
   :PRReview
   ```

3. Toggle comment visibility as needed:
   ```
   :PRToggleThreads
   ```

4. Navigate between files in the PR using fugitive's interface.

## Commands

| Command | Description |
|---------|-------------|
| `:PRBrowse` | Open a searchable list of PRs |
| `:PRReview` | Review the current PR with side-by-side diffs |
| `:PRFetchThreads` | Fetch comment threads for the current PR |
| `:PRShowThreads` | Display PR comment threads as diagnostics |
| `:PRHideThreads` | Hide PR comment threads |
| `:PRToggleThreads` | Toggle visibility of PR comment threads |

## Usage

### Browsing PRs

1. Run `:PRBrowse` to see a list of PRs
2. Actions in the PR browser:
   - `Enter`: Open PR in your web browser
   - `Ctrl-o`: Checkout the selected PR
   - `Ctrl-r`: Checkout and start reviewing the PR

### Reviewing PRs

When on a PR branch:

1. Run `:PRReview` to:
   - Fetch PR comment threads
   - Open side-by-side diffs using fugitive

### Working with Comment Threads

- `:PRFetchThreads` - Load PR comments as diagnostics
- `:PRShowThreads` - Show comment threads (after fetching)
- `:PRHideThreads` - Hide comment threads
- `:PRToggleThreads` - Toggle visibility of comment threads

## Health Check

Run `:checkhealth pr-review` to verify that all dependencies are properly installed.
