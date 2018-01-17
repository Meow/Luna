luna = luna or {}
luna.pp = luna.pp or {}
luna.util = luna.util or {}

function luna.util.FindClosure(str, opener, closer, start, opnd, chk)
    chk = chk or function() return end
    local open = opnd or 1
    local sc = false

    for i = (start or 1), str:len() do
        -- first check for opener
        local opnr = str:sub(i, i + opener:len() - 1)

        if (chk(opnr, str, i)) then continue end

        if (str:sub(i, i + opener:len() - 1) == opener) then
            open = open + 1
        elseif (str:sub(i, i + closer:len() - 1) == closer) then -- then check for closure
            open = open - 1
        end

        -- we've found the closure for the current block, bail out!
        if (open == 0) then return i, i + closer:len() - 1 end
    end

    return -1
end

function luna.util.FindLogicClosure(str, pos, opnd)
    local open = opnd or 1
    local sc = false

    for i = (pos or 1), str:len() do
        -- first check for opener
        local prev = str:sub(i - 1, i - 1) -- previous letter
        local opnr = str:sub(i, i + 1) -- if, do
        local opnr2 = str:sub(i, i + 7) -- function
        local opnr3 = str:sub(i, i + 8) -- namespace

        -- elseif or part of another word
        if ((!prev:match("([^%w])") and prev != "\n") or (opnr == "if" and str:sub(i - 1, i - 1) == "e")) then continue end

        if (opnr == "if" or opnr == "do" or opnr2 == "function" or opnr3 == "namespace") then
            open = open + 1
        elseif (str:sub(i, i + 2) == "end") then -- then check for closure
            open = open - 1
        end

        -- we've found the closure for the current block, bail out!
        if (open == 0) then return i, i + 2 end
    end

    return -1
end

function luna.util.FindTableVal(str, tab)
    tab = tab or _G

    local pieces = str:split(".")

    for k, v in ipairs(pieces) do
        if (tab[v] == nil) then
            return false
        else
            tab = tab[v]
        end
    end

    return tab
end

include("preprocessor.lua")