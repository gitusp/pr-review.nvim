local M = {}

function M.check()
  local health = require("health")
  local start = health.report_start
  local ok = health.report_ok
  local error = health.report_error

  start("PR Review")

  if vim.fn.executable("gh") == 1 then
    ok("GitHub CLI (gh) is installed")
  else
    error("GitHub CLI (gh) not found. Install it from https://cli.github.com/")
  end

  if vim.fn.executable("git") == 1 then
    ok("git is installed")
  else
    error("git not found. Required for repository operations.")
  end

  local has_fugitive = vim.g.loaded_fugitive == 1
  if has_fugitive then
    ok("fugitive.vim is installed")
  else
    error("fugitive.vim not found. Required for git integration functionality.")
  end

  local has_fzf_lua, _ = pcall(require, "fzf-lua")
  if has_fzf_lua then
    ok("fzf-lua is installed")
  else
    error("fzf-lua not found. Required for PR browsing functionality.")
  end
end

return M
