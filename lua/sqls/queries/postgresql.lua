--- @alias query string
--- @alias system_call boolean
local M = {}

---@param query
---@return boolean
M.make_system_call = function(query)
    local match = string.match(query, "^\\")
    return match ~= nil
end

---@param query string
---@return string
M.system_call = function(query)
    local command = [[psql -c "]] .. query .. '"'
    return vim.fn.system(command)
end

local basic_constraint_query =
    [[SELECT tc.constraint_name, tc.table_name, kcu.column_name, ccu.table_name AS foreign_table_name, ccu.column_name AS foreign_column_name, rc.update_rule, rc.delete_rule
	FROM
		information_schema.table_constraints AS tc
		JOIN information_schema.key_column_usage AS kcu
			ON tc.constraint_name = kcu.constraint_name
		JOIN information_schema.constraint_column_usage AS ccu
			ON ccu.constraint_name = tc.constraint_name
		LEFT OUTER JOIN information_schema.referential_constraints as rc
			ON tc.constraint_name = rc.constraint_name
    ]]

---@param schema string
---@param table string
---@return query
M.list = function(schema, table)
    local result = string.format("SELECT * FROM %q.%q LIMIT 500", schema, table)
    return result
end

---@param schema string
---@param table string
---@return query
M.describe_table = function(schema, table)
    local result = string.format([[\d+ %s.%s]], schema, table)
    return result
end

---@param schema string
---@param table string
---@return query
M.foreign_keys = function(schema, table)
    return string.format(
        "%s WHERE constraint_type = 'FOREIGN KEY' AND tc.table_name = '%s' AND tc.table_schema = '%s';",
        basic_constraint_query,
        table,
        schema
    )
end

---@param schema string
---@param table string
---@return query
M.references = function(schema, table)
    return string.format(
        "%s WHERE constraint_type = 'FOREIGN KEY' AND ccu.table_name = '%s' AND tc.table_schema = '%s';",
        basic_constraint_query,
        table,
        schema
    )
end

---@param schema string
---@param table string
---@return query
M.primary_keys = function(schema, table)
    return string.format(
        "%s WHERE constraint_type = 'PRIMARY KEY' AND tc.table_name = '%s' AND tc.table_schema = '%s';",
        basic_constraint_query,
        table,
        schema
    )
end

---@param schema string
---@param table string
---@return query
M.unique = function(schema, table)
    return string.format(
        "%s WHERE constraint_type = 'UNIQUE' AND tc.table_name = '%s' AND tc.table_schema = '%s';",
        basic_constraint_query,
        table,
        schema
    )
end

---@param schema string
---@param table string
---@return query
M.indices = function(schema, table)
    return string.format("SELECT * FROM pg_indexes WHERE tablename='%s' AND schemaname='%s'", table, schema)
end

return M
