local util = {}

-- Produces a string; detailing the values in a table.
--
function util.table_tostring(value)
   local str = ''
   if type(value) == 'table' then
      local noComma = true
      for key, val in pairs(value) do
         if noComma then
            str = str .. key .. '=' .. util.table_tostring(val)
            noComma = false
         else
            str = str .. ',' .. key .. '=' .. util.table_tostring(val)
         end
      end
      str = '[' .. str .. ']'
   else
      str = tostring(value)
   end

   return str
end

-- Check if an element exists within table.
--
function util.contains(table, element)
   for _,value in pairs(table) do
      if value == element then
         return true
      end
   end

   return false
end

-- Returns a table with unique values from `old_table`.
-- `keep_keys` ensures that the keys used from `old_table` is kept,
-- if not then the values will simply be inserted.
--
function util.only_unique_values(old_table, keep_keys)
   local new_table = {}

   for key, value in pairs(old_table) do
      if not homf.util.contains(new_table, value) then
         if keep_keys then
            new_table[key] = value
         else
            table.insert(new_table, value)
         end
      end
   end

   return new_table
end

-- Increment/decrement an index.
-- If that index points outside of its correspinding table,
-- then have it point at the other end of the table.
--
function util.rotate_table_index(index, table_len, increment)
   if type(table_len) == 'table' then
      table_len = #table_len
   end

   assert(type(index)     == 'number', 'wrong type given to argument #1, expected a number but got %s', type(index))
   assert(type(table_len) == 'number', 'wrong type given to argument #2, expected either a table or number but got %s', type(table_len))

   if increment ~= false then
      increment = true
   end

   if increment then
      index = index + 1
      if index > table_len then
         index = 1
      end
   else
      index = index - 1
      if index < 1 then
         index = table_len
      end
   end

   return index
end

return util
