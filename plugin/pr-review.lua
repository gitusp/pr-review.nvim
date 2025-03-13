if vim.g.loaded_pr_review == 1 or vim.opt.compatible:get() then
  return
end

vim.g.loaded_pr_review = 1

vim.api.nvim_create_user_command('PRBrowse', function()
  require('pr-review').browse()
end, {})

vim.api.nvim_create_user_command('PRReview', function()
  require('pr-review').review()
end, {})

vim.api.nvim_create_user_command('PRFetchThreads', function()
  require('pr-review').fetch_threads()
end, {})

vim.api.nvim_create_user_command('PRShowThreads', function()
  require('pr-review').show_threads()
end, {})

vim.api.nvim_create_user_command('PRHideThreads', function()
  require('pr-review').hide_threads()
end, {})

vim.api.nvim_create_user_command('PRToggleThreads', function()
  require('pr-review').toggle_threads()
end, {})
