local M = {}

-- 检查文件是否存在
local function fileExists(filePath)
    local file = io.open(filePath, "r")
    if file then
        file:close()
        return true
    else
        return false
    end
end

-- 读取文件内容
local function readFile(filePath)
    local file = io.open(filePath, "r")
    local content = file:read("*a")
    file:close()
    return content
end

-- 写入文件内容
local function writeFile(filePath, content)
    local file = io.open(filePath, "w")
    file:write(content)
    file:close()
end

-- 去重函数
function table.unique(t)
    local check = {}
    local n = {}
    for _, v in ipairs(t) do
        if not check[v] then
            check[v] = true
            table.insert(n, v)
        end
    end
    return n
end

-- 主函数 asyncByLog
local function asyncByLog(currEdit)
    local path = "/tmp/rsync-git"
    if not fileExists(path) then
        local stream = io.open(path, "w")
        stream:close()
    end

    local lastEdit = {}
    for line in string.gmatch(readFile(path), "[^\n]+") do
        table.insert(lastEdit, line)
    end

    -- 将当前编辑内容写入文件
    writeFile(path, table.concat(currEdit, "\n"))

    -- 合并去重的编辑记录
    local bothEdit = currEdit
    
    for _, item in ipairs(lastEdit) do
        table.insert(bothEdit, item)
    end

    local uniqBothEdit = table.unique(bothEdit)

    return uniqBothEdit
end

-- 运行命令
local function runCommand(command)
    local handle = io.popen(command)
    local result = handle:read("*a")
    handle:close()
    return result
end

-- 从数组中删除特定关键词
local function removeItemsWithKeyword(array, keyword)
    for i = #array, 1, -1 do  -- 从后向前遍历数组
        if string.find(array[i], keyword) then  -- 检查当前项是否包含关键词
            table.remove(array, i)  -- 移除当前项
        end
    end
end

local function getGitEdit()
    -- 调用 git status --porcelain 命令
    local output = runCommand("git status --porcelain")
    
    -- 按行分割结果并存储在数组中
    local lines = {}
    for line in output:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    -- 对每行进行正则替换，删除开头的空格和一个字母
    for i, line in ipairs(lines) do
        lines[i] = line:gsub("^%s*%w%s*", "")  -- 删除开头的空格和一个字母
    end

    removeItemsWithKeyword(lines, "aweme_idl")
    
    return lines
end

local function findLastOccurrence(str, char)
    local reversedStr = string.reverse(str)  -- 反转字符串
    local _, index = string.find(reversedStr, char)  -- 查找字符在反转字符串中的位置
    if index then
        return string.len(str) - index + 1  -- 计算原始字符串中的位置
    else
        return nil  -- 如果没有找到，返回nil
    end
end

local function getDir(path)
    -- 查找最后一个斜杠的位置
    local lastIdx = findLastOccurrence(path, "/")  -- 从字符串末尾开始查找
    if lastIdx then
        return path:sub(1, lastIdx)  -- 返回斜杠之前的子字符串
    else
        return path  -- 如果没有斜杠，返回原始路径
    end
end

local function callRsync(path, args)
    local localPath = args.localPath
    local remotePath = args.remotePath
    local userIp = args.userIp
    local rsyncParam = M.args.config.rsyncParam

    local origPath = string.format("%s/%s", localPath, path)
    local tgtPath = string.format("%s:%s/%s", userIp, remotePath, string.gsub(path, "%[", "\\["):gsub("%]", "\\]"))
    
    local cmd = string.format("-av%s", rsyncParam)
    local rsyncCommand = string.format("rsync %s %s %s", cmd, origPath, tgtPath)

    if M.args.config.showLog then
      print(rsyncCommand)
    end
    -- 执行 rsync 命令
    local result = runCommand(rsyncCommand)

    return result
end


M.args = {
  rules = {},
  config = {
    rsyncParam = "",
    disableGit = true,
    showLog = false,
  }
}

function M.setup(cfg)
  M.args.config = {
    rsyncParam = cfg.config.rsyncParam or M.args.config.rsyncParam,
    disableGit = cfg.config.disableGit or M.args.config.disableGit,
    showLog = cfg.config.showLog or M.args.config.showLog,
  }
  M.args.rules = cfg.rules;
end

function M.rsync(rule)
  local disableGit = M.args.config.disableGit 
  local currEditFiles = asyncByLog(getGitEdit())
  local currEditDirs = table.unique(currEditFiles)
  for _, item in ipairs(currEditDirs) do
    callRsync(item, rule)
  end
  if not disableGit then
    callRsync(".git", rule)
  end
end

vim.api.nvim_create_autocmd({"BufWritePost"}, {
  callback = function()
    local curr = vim.api.nvim_buf_get_name(0)
    for _, rule in ipairs(M.args.rules) do
      if string.match(curr, rule.cond) then
        M.rsync(rule)
        break
      end
    end
  end
})

return M
