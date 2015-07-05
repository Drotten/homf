local util = {}

-- Produces a string; detailing the values in a table.
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

-- Check if an element exists in table.
function util.contains(table, element)
   for _,value in pairs(table) do
      if value == element then
         return true
      end
   end

   return false
end

-- Increment/decrement an index.
-- If that index points outside of its correspinding table,
-- then have it point at the other end of the table.
function util.rotate_table_index(index, table_len, is_next)
   if type(table_len) == 'table' then
      table_len = #table_len
   end

   assert(type(index)     == 'number', 'wrong type given to argument #1, expected a number but got %s', type(index))
   assert(type(table_len) == 'number', 'wrong type given to argument #2, expected either a table or number but got %s', type(table_len))

   -- In case is_next == nil or some value type other than a boolean
   if is_next ~= false then
      is_next = true
   end

   if is_next then
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