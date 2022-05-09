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

local function getLineNumber()
    if string.find(v.fn.mode(), "^V") ~= nil then
        local a = v.fn.getpos("v")[2]
        local b =  v.fn.getpos(".")[2]
        if (a > b) then
            a, b = b, a
        end
        return {type = 'v', startLine = a, endLine = b }
    else
        return {type = 'n', startLine = v.fn.line(".")}
    end
end

local function fmtLineNumber(lineNumber)
    if lineNumber.type == 'v' then
        return lineNumber.startLine .. "-" .. lineNumber.endLine
    else
        return lineNumber.startLine
    end
end

local function addToList(config_values, listAddFunc, path, lineNumber, comment)
    if config_values.indicator:len() > 1 then
        -- setting type to indicator will only use first char
        log.error("Config value 'indicator' must be a string of maximally 1 character.")
        log.error("Actual value:", config_values.indicator)
        log.error("Continuing with the first character of indicator.")
    end
    local listItem = {
        bufnr = vim.fn.bufnr('%'),
        filename = path,
        lnum = lineNumber.startLine,
        end_lnum = lineNumber.endLine,
        text = comment,
        type = config_values.indicator,
        valid = true,
    }
    listAddFunc(listItem)
end

function M.yank(overwrite_config)
    local config_values = v.tbl_extend("force", M._config, overwrite_config or {})

    local path = v.fn.expand(config_values.expand_str)
    local lineNumber = getLineNumber()
    local comment = getComment(config_values)

    if config_values.send_to == "clipboard" then
        -- Fixup the str here, see TODO below
        v.fn.setreg("+", path .. ":" .. fmtLineNumber(lineNumber) .. " " .. comment)
    elseif config_values.send_to == "clist" then
        addToList(
            config_values,
            function(dic) vim.fn.setqflist({dic}, 'a') end,
            path, lineNumber, comment
        )
    elseif config_values.send_to == "llist" then
        addToList(
            config_values,
            function(dic) vim.fn.setloclist(0, {dic}, 'a') end,
            path, lineNumber, comment
        )
    else
        log.error("Unknown `config value send_to`:", config_values.send_to, ". Valid values are 'clipboard', 'llist' or 'clist'.")
    end
end

-- Configuration --

local function default_opts()
    return {
        -- Where the location shall be stored
        --      * clipboard = @+
        --      * clist     = current quickfix list
        --      * llist     = current location list
        send_to = "clipboard",
        -- locationist optionally asks for a comment to store together with the location
        -- set comment to
        --      * "none" to not ask for a comment
        --      * "default" to invoke vim.fn.input to ask for a comment
        --      * your own function. The signature should be `function() -> string`
        --        (If you created a nice func, please share it with us :) )
        comment = "none",
        -- How the file name will be expanded
        expand_str = "%", -- see :h expand for possible values
        -- If indicator is non empty, a character is displayed next to the line number in the llist/clist
        -- Ignored for send_to = "clipboard"
        indicator = '', -- Can be 1 character long string at most!
    }
end

function M.setup(opts)
    M._config = v.tbl_extend("force", default_opts(), opts)
end

M.setup({})

return M
