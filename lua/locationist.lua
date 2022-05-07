local M = {}
local v = vim
local log = require("locationist.log")

-- Constants --

-- functions --
local function getComment(config_values)
    if config_values.comment == "none" then
        return ""
    elseif config_values.comment == "default" then
        return v.fn.input("Comment: ")
    elseif type(config_values.comment) == "function" then
        local user_comment = config_values.comment()
        if type(user_comment) ~= "string" then
            log.error([[
            You provided a comment function which did not return a string.
            Your function must return a string. Please fix your function.
            Continuing with empty comment.
            ]])
            return ""
        end
        return user_comment
    else
        log.error([[ 
            config.comment should be set to "none", "default" or your own function
            config.comment is:
                ]] .. v.inspect(config_values.comment) .. [[
            Continuing with empty comment.]])
        return ""
    end
end

local function sendStrTo(str, config_values)
    if config_values.send_to == "clipboard" then
        -- Fixup the str here, see TODO below
        local tmp = str:reverse()
        tmp = string.gsub(tmp, "^%s+", "")
        v.fn.setreg("+", tmp:reverse())
    elseif config_values.send_to == "clist" then
        v.cmd(string.format([[caddexpr "%s"]], str))
    elseif config_values.send_to == "llist" then
        v.cmd(string.format([[laddexpr "%s"]], str))
    else
        log.error("Unknown `send_config_values.send_to` location:", config_values.send_to)
    end
end

local function getLineNumberFormatted()
    if string.find(v.fn.mode(), "^V") ~= nil then
        local a = v.fn.getpos("v")[2]
        local b =  v.fn.getpos(".")[2]
        if (a > b) then
            a, b = b, a
        end
        return a .. ":" .. b
    else
        return v.fn.line(".")
    end
end

function M.yank(overwrite_config)
    local config_values = v.tbl_extend("force", M._config, overwrite_config or {})

    local path = v.fn.expand(config_values.expand_str)
    local lineNumber = getLineNumberFormatted()
    local comment = getComment(config_values)

    -- We hijack gcc's errorformat here. Somehow I am unable to get an errorformat working
    -- without everything breaking and vim complaining about "%-" in an errorformat
    -- TODO create custom errorformat
    local location
    if comment ~= "" then
        location = path .. ":" .. lineNumber .. ": " .. comment
    else
        location = path .. ":" .. lineNumber .. ": "
    end
    sendStrTo(location, config_values)
end


-- Configuration --

local function default_opts()
    return {
        -- How the file name will be expanded
        expand_str = "%", -- see :h expand for possible values
        -- locationist optionally asks for a comment to store together with the location
        -- set comment to
        --      * "none" to not ask for a comment
        --      * "default" to invoke vim.fn.input to ask for a comment
        --      * your own function. The signature should be `function() -> string`
        --        (If you created a nice func, please share it with us :) )
        comment = "none",
        -- Where the location shall be stored
        --      * clipboard = @+
        --      * clist     = current quickfix list
        --      * llist     = current location list
        send_to = "clipboard",
    }
end

function M.setup(opts)
    M._config = v.tbl_extend("force", default_opts(), opts)
end

M.setup({})

return M
