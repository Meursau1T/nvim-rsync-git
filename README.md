# rsync-git.nvim
rsync-git.nvim is a plugin that synchronizes the results of git status to a server via rsync, enabling high-performance remote development on neovim, freeing users from the latency of ssh-based solutions.
## Installation and setup
You need to configure `rules` as part of the `setup`. If a file path that triggers a save contains `rules.cond`, it will invoke rsync to perform synchronization.
```
require("lazy").setup({
  {
    "Meursau1T/rsync-git.nvim",
    config = function()
      require("rsync-git").setup {
        rules = {
          {
            cond = "dirname1/",
            localPath = "/your/local/path/dirname1",
            remotePath = "/your/remote/path/dirname1",
            userIp = "username@yourip",
          },
          {
            cond = "dirname2/",
            localPath = "/your/local/path/dirname2",
            remotePath = "/your/remote/path/dirname2",
            userIp = "username@yourip",
          },
        },
        config = {
          showLog = true,
          disableGit = true, -- do not sync .git. Default is true
          rsyncParam = "",
        }
      }
    end
  }
})
```
