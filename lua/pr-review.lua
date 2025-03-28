local M = {}

local namespace = vim.api.nvim_create_namespace('pr-threads')

local pr_threads_shown = false

local function fst(selected)
  local parts = vim.split(selected[1], ' ')
  return parts[1]
end

local function build_diagnostic(base_path, merge_base, thread)
  local messages = {}
  for _, comment in ipairs(thread.comments.nodes) do
    table.insert(messages, comment.author.login .. " (" .. comment.createdAt .. "):\n" .. comment.body)
  end

  local path = thread.diffSide == "RIGHT"
    and base_path .. '/' .. thread.path
    or 'fugitive://' .. base_path .. '/.git//' .. merge_base .. '/' .. thread.path

  local diag = {
    bufnr = vim.fn.bufadd(path),
    col = 0,
    message = table.concat(messages, "\n\n"),
    severity = vim.diagnostic.severity.INFO,
    source = "PR Comment"
  }

  if type(thread.startLine) == "number" then
    diag.lnum = thread.startLine - 1
    diag.end_lnum = thread.line - 1
  else
    diag.lnum = thread.line - 1
  end

  return diag
end

local function checkout(pr_number)
  vim.notify("Checking out PR " .. pr_number, vim.log.levels.INFO)
  local checkout_result = vim.system({ 'gh', 'pr', 'checkout', pr_number }):wait()
  if checkout_result.code ~= 0 then
    error("Failed to checkout PR: " .. checkout_result.stderr)
  end
end

function M.fetch_threads()
  vim.notify("Fetching PR threads...", vim.log.levels.INFO)

  vim.fn.jobstart('gh pr view --json headRefName --jq .headRefName', {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if #data == 0 or (data[1] == "" and #data == 1) then
        vim.notify("Failed to get PR' headRefName. Are you on a PR branch?", vim.log.levels.ERROR)
        return
      end

      local headRefName = data[1]:gsub('%s+$', '')

      local function load_threads(threads, cb, after)
        local after_arg = after and ' -F after=' .. vim.fn.shellescape(after) or ''
        vim.fn.jobstart(
          'gh api graphql -F owner=\'{owner}\' -F name=\'{repo}\' -F headRefName=\'' .. headRefName .. '\'' .. after_arg .. ' -f query=\'' ..
          '  query($name: String!, $owner: String!, $headRefName: String!, $after: String) {' ..
          '    repository(owner: $owner, name: $name) {' ..
          '      pullRequests(first: 1, headRefName: $headRefName) {' ..
          '        nodes {' ..
          '          baseRefName' ..
          '          reviewThreads(first: 100, after: $after) {' ..
          '            nodes {' ..
          '              path' ..
          '              line' ..
          '              startLine' ..
          '              diffSide' ..
          '              isResolved' ..
          '              isOutdated' ..
          '              comments(first: 100) {' ..
          '                nodes {' ..
          '                  body' ..
          '                  author {' ..
          '                    login' ..
          '                  }' ..
          '                  createdAt' ..
          '                }' ..
          '              }' ..
          '            }' ..
          '            pageInfo {' ..
          '              endCursor' ..
          '              hasNextPage' ..
          '            }' ..
          '          }' ..
          '        }' ..
          '      }' ..
          '    }' ..
          '  }\'',
          {
            stdout_buffered = true,
            on_stdout = function(_, repository_data)
              if #repository_data == 0 or (repository_data[1] == "" and #repository_data == 1) then
                vim.notify("Failed to fetch PR threads", vim.log.levels.ERROR)
                return
              end

              local repository_json = table.concat(repository_data, '\n')
              local decoded = vim.fn.json_decode(repository_json)

              if #decoded.data.repository.pullRequests.nodes == 0 then
                vim.notify("PR not found", vim.log.levels.ERROR)
                return
              end

              if #decoded.data.repository.pullRequests.nodes[1].reviewThreads.nodes == 0 then
                vim.notify("No threads found in this PR", vim.log.levels.INFO)
                return
              end

              for _, thread in ipairs(decoded.data.repository.pullRequests.nodes[1].reviewThreads.nodes) do
                table.insert(threads, thread)
              end

              if decoded.data.repository.pullRequests.nodes[1].reviewThreads.pageInfo.hasNextPage then
                load_threads(threads, cb, decoded.data.repository.pullRequests.nodes[1].reviewThreads.pageInfo.endCursor)
              else
                cb(threads, decoded.data.repository.pullRequests.nodes[1].baseRefName)
              end
            end,
            on_stderr = function(_, stderr_data)
              if #stderr_data > 0 and (stderr_data[1] ~= "" or #stderr_data > 1) then
                vim.notify("Error fetching PR threads: " .. table.concat(stderr_data, "\n"), vim.log.levels.ERROR)
              end
            end,
            on_exit = function(_, exit_code)
              if exit_code ~= 0 then
                vim.notify("Failed to fetch PR threads: exit code " .. exit_code, vim.log.levels.ERROR)
              end
            end,
          }
        )
      end

      load_threads({}, function(threads, baseRefName)
        local base_path
        local merge_base

        local function next()
          local buf_diagnostics = {}

          for _, thread in pairs(threads) do
            local hidden = thread.isResolved or thread.isOutdated
            local has_line = type(thread.startLine) == "number" or type(thread.line) == "number"
            if has_line and not hidden then
              local diag = build_diagnostic(base_path, merge_base, thread)

              if not buf_diagnostics[diag.bufnr] then
                buf_diagnostics[diag.bufnr] = {}
              end
              table.insert(buf_diagnostics[diag.bufnr], diag)
            end
          end

          vim.diagnostic.reset(namespace)
          for bufnr, diagnostics in pairs(buf_diagnostics) do
            vim.diagnostic.set(namespace, bufnr, diagnostics, {})
          end
          pr_threads_shown = true

          vim.notify("Loaded all the threads into diagnostics", vim.log.levels.INFO)
        end

        vim.system({ 'git', 'rev-parse', '--show-toplevel' }, nil, function(rev_parse_result)
          if rev_parse_result.code ~= 0 then
            vim.schedule(function()
              vim.notify("Failed to get git root: " .. rev_parse_result.stderr, vim.log.levels.ERROR)
            end)
            return
          end

          base_path = rev_parse_result.stdout:gsub('%s+$', '')

          if merge_base then
            vim.schedule(next)
          end
        end)

        vim.system({ 'git', 'merge-base', 'origin/' .. baseRefName, 'HEAD' }, nil, function(merge_base_result)
          if merge_base_result.code ~= 0 then
            vim.schedule(function()
              vim.notify("Failed to get merge base: " .. merge_base_result.stderr, vim.log.levels.ERROR)
            end)
            return
          end

          merge_base = merge_base_result.stdout:gsub('%s+$', '')

          if base_path then
            vim.schedule(next)
          end
        end)
      end)
    end,
    on_stderr = function(_, stderr_data)
      if #stderr_data > 0 and (stderr_data[1] ~= "" or #stderr_data > 1) then
        vim.notify("Error getting PR number: " .. table.concat(stderr_data, "\n"), vim.log.levels.ERROR)
      end
    end,
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        vim.notify("Failed to get PR number: exit code " .. exit_code, vim.log.levels.ERROR)
      end
    end,
  })
end

function M.review()
  M.fetch_threads()

  vim.notify("Fetching PR information...", vim.log.levels.INFO)
  local pr_view_result = vim.system({ 'gh', 'pr', 'view', '--json', 'baseRefName', '--jq', '.baseRefName' }):wait()
  if pr_view_result.code ~= 0 then
    vim.notify("Failed to get parent branch: " .. pr_view_result.stderr, vim.log.levels.ERROR)
    return
  end

  local parent_branch = "origin/" .. pr_view_result.stdout:gsub('%s+$', '')
  vim.cmd('G difftool -y ' .. parent_branch .. '...')
end

function M.browse()
  require('fzf-lua').fzf_exec('gh pr list --json number,title,author --template \'{{range .}}{{tablerow .number .title .author.login}}{{end}}{{tablerender}}\'', {
    prompt = "PRs> ",
    actions = {
      ['default'] = function(selected)
        local pr_number = fst(selected)
        vim.notify("Opening PR #" .. pr_number, vim.log.levels.INFO)
        vim.system({ 'gh', 'pr', 'view', pr_number, '-w' })
      end,
      ['ctrl-o'] = function(selected)
        local success, result = pcall(checkout, fst(selected))
        if not success then
          vim.notify(result and tostring(result) or "Failed to checkout", vim.log.levels.ERROR)
        end
      end,
      ['ctrl-r'] = function(selected)
        local success, result = pcall(checkout, fst(selected))
        if not success then
          vim.notify(result and tostring(result) or "Failed to checkout", vim.log.levels.ERROR)
        else
          M.review()
        end
      end,
    },
    preview = "CLICOLOR_FORCE=1 gh pr view `echo {} | cut -d' ' -f1`",
  })
end

function M.show_threads()
  vim.diagnostic.show(namespace)
  pr_threads_shown = true
end

function M.hide_threads()
  vim.diagnostic.hide(namespace)
  pr_threads_shown = false
end

function M.toggle_threads()
  if pr_threads_shown then
    M.hide_threads()
  else
    M.show_threads()
  end
end

return M
