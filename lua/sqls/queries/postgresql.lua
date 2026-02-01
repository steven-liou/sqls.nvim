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
    [[SELECT tc.constraint_name, tc.table_name AS foreign_table_name, kcu.column_name AS foreign_column_name, ccu.column_name AS column_name, rc.update_rule, rc.delete_rule
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
    local where_clause = vim.fn.input({ prompt = "Condition: ", default = "WHERE ", cancelreturn = "" })
    if string.match(where_clause, "^%s*WHERE%s*$") then
        where_clause = ""
    end
    local limit_suffix = ""
    if where_clause ~= "" and not string.match(where_clause:lower(), "%s+limit%s*%d*%s*$") or where_clause == "" then
        limit_suffix = " LIMIT 100"
    end
    local result = string.format("SELECT * FROM %q.%q %s%s", schema, table, where_clause, limit_suffix)
    return result
end

---@param schema string
---@param table string
---@return query
M.describe_table = function(schema, table)
    -- show general info about table: columns, constraints, enum types with 3 separate queries
    local result = string.format(
        [[
    SELECT
         column_name,
         data_type,
         character_maximum_length,
         column_default,
         is_nullable
    FROM information_schema.columns
    WHERE table_schema = '%s' AND table_name = '%s'
    ORDER BY ordinal_position;

    SELECT
        con.conname AS "Constraint Name",
        CASE con.contype
            WHEN 'p' THEN 'PRIMARY KEY'
            WHEN 'f' THEN 'FOREIGN KEY'
            WHEN 'u' THEN 'UNIQUE'
            WHEN 'c' THEN 'CHECK'
            WHEN 'x' THEN 'EXCLUSION'
            ELSE 'OTHER'
        END AS "Type",
        pg_get_constraintdef(con.oid, true) AS "Definition"
    FROM pg_catalog.pg_constraint con
    JOIN pg_catalog.pg_class rel ON rel.oid = con.conrelid
    JOIN pg_catalog.pg_namespace nsp ON nsp.oid = con.connamespace
    WHERE nsp.nspname = '%s'
      AND rel.relname = '%s'
    ORDER BY "Type";

    SELECT
        a.attname AS "Column",
        t.typname AS "Data Type",
        string_agg(e.enumlabel, ', ' ORDER BY e.enumsortorder) AS "Enum Values"
    FROM pg_catalog.pg_attribute a
    JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
    JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
    JOIN pg_catalog.pg_type t ON a.atttypid = t.oid
    LEFT JOIN pg_catalog.pg_enum e ON t.oid = e.enumtypid
    WHERE n.nspname = '%s' -- Filter by Schema
      AND c.relname = '%s'  -- Filter by Table
      AND a.attnum > 0                  -- Exclude system columns
      AND NOT a.attisdropped            -- Exclude deleted columns
      AND e.enumlabel IS NOT NULL  -- Only include enum types
    GROUP BY n.nspname, c.relname, a.attname, t.typname, a.attnum
    ORDER BY a.attnum;
 ]],
        schema,
        table,
        schema,
        table,
        schema,
        table
    )
    return result
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
M.indices = function(schema, table)
    return string.format(
        "SELECT INDEXNAME, INDEXDEF FROM pg_indexes WHERE tablename='%s' AND schemaname='%s';",
        table,
        schema
    )
end

return M
