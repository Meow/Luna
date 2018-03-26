luna.pp:AddProcessor("string_interp", function(code)
	local str_open, open_char, close_char, close_seq, open_seq, open_pos = false, "", "", "", "", -1
	local ignore_until = false
	local i = 0

	while (i < code:len()) do
		i = i + 1

		local v = code:sub(i, i)

		if (ignore_until) then
			if (ignore_until == v) then
				ignore_until = false
			end

			continue
		end

		if (v == "{" and code:sub(i - 1, i - 1) == "#") then
			ignore_until = "}"

			continue
		end

		if (str_open) then
			if (v != close_char) then
				continue
			elseif (code:sub(i, i + close_seq:len() - 1) == close_seq) then
				-- close sequence hit, can start interpolating...
				code = luna.pp:PatchStr(code, open_pos + 1, i - 1, code:sub(open_pos + 1, i - 1):gsub("#{([^#{}]+)}", close_seq.."..(%1).."..open_seq))

				-- reset
				str_open, open_char, close_char, close_seq, open_seq, open_pos = false, "", "", "", "", -1

				continue
			end
		end

		if (v == "\"" or v == "'") then
			str_open = true
			open_char = v
			open_seq = v
			close_char = v
			close_seq = v
			open_pos = i
		elseif (v == "[" and code:sub(i + 1, i + 1) == "[") then
			str_open = true
			open_char = "["
			open_seq = "[["
			close_char = "]"
			close_seq = "]]"
			open_pos = i
		end
	end

  code = save_strings(code, true)
  code = code:gsub("this%.", "self."):gsub("this:", "self:"):gsub("([%s\n]?)this([%s\n]?)", "%1self%2")
	code = restore_strings(code)

	return code
end)