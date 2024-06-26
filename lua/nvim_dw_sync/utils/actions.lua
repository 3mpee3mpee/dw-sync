local Job = require("plenary.job")
local Path = require("plenary.path")
local file_utils = require("nvim_dw_sync.utils.file")
local logs = require("nvim_dw_sync.utils.logs")

local M = {}

local function validate_connection(config, callback)
  local validate_url = string.format(
    "https://%s/on/demandware.servlet/webdav/Sites/Cartridges/%s/",
    config.hostname,
    config["code-version"]
  )

  Job:new({
    command = "curl",
    args = { "-I", validate_url, "-u", config.username .. ":" .. config.password },
    on_exit = function(j, return_val)
      if return_val == 0 then
        local result = j:result()
        local status_code = tonumber(string.match(result[1], "%s(%d+)%s"))

        if status_code == 200 then
          logs.add_log("Connection validated successfully")
          callback(true)
        else
          logs.add_log("Failed to validate connection: HTTP status " .. status_code)
          logs.add_log("Response: " .. table.concat(result, "\n"))
          callback(false)
        end
      else
        logs.add_log("Failed to validate connection: " .. table.concat(j:stderr_result(), "\n"))
        callback(false)
      end
    end,
  }):start()
end

function M.execute_upload(config, cwd)
  logs.add_log("Upload Cartridges action triggered")
  local valid_cartridges = file_utils.update_cartridge_list(cwd)

  if #valid_cartridges == 0 then
    logs.add_log("No cartridges to upload")
    return
  end

  validate_connection(config, function(success)
    if not success then
      return
    end
    logs.add_log("Start uploading cartridges")
    logs.add_log("Cartridges to upload: " .. table.concat(valid_cartridges, "\n"))
    logs.add_log("Using config file: " .. Path:new(cwd .. "/dw.json"):absolute())
    logs.add_log("Hostname: " .. config.hostname)
    logs.add_log("Code version: " .. config["code-version"])

    for _, valid_cartridge in ipairs(valid_cartridges) do
      logs.add_log("Uploading: " .. valid_cartridge)
      file_utils.upload_cartridge(valid_cartridge, config)
    end
  end)
end

function M.execute_clean_project(config)
  logs.add_log("Clean Project triggered")
  file_utils.get_cartridge_list_and_clean(config)
end

function M.execute_enable_upload(config)
  logs.add_log("Enable Upload triggered")
  file_utils.start_watcher(config)
end

function M.execute_disable_upload()
  logs.add_log("Disable Upload triggered")
  file_utils.stop_watcher()
end

function M.execute_clean_project_upload_all(config, cwd)
  M.execute_clean_project(config)
  M.execute_upload(config, cwd)
  M.execute_enable_upload(config)
end

return M
