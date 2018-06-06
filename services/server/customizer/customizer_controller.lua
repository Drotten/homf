local rng = _radiant.math.get_default_rng()

local CustomizerController = class()

-- Copied from Stonehearth's customization_service.lua
local CUSTOMIZATION = {
   NONE = '[none]',
   MATERIAL_MAP = 'material_map',
   MODEL = 'model',
   ROOT = 'root',
   PACKAGES = 'packages',
   DEFAULT_VARIANT = 'default',
}

local GENDER = {
   MALE = 'male',
   FEMALE = 'female',
}

function CustomizerController:activate()
   self._log = radiant.log.create_logger('customizer')
end

function CustomizerController:start_customization(entity, continue)
   -- Load all data concerning the entity's models if we haven't already
   if not self._data then
      self._roles = {}
      self._mats = {}
      self._models = {}

      local pop = stonehearth.population:get_population(entity)
      self._data = self:_load_faction_data(pop:get_kingdom())
      self:_setup_customization_options_data(self._data)
      self:_complement_gender_data(self._models)
      self:_complement_gender_data(self._mats)
   end

   self._customizing_entity = entity
   self._model_variants = entity
      :get_component('model_variants'):get_variant('default')
   self._render_info = entity:get_component('render_info')

   assert(self._model_variants, 'HoMF: model_variants component not found')
   assert(self._render_info, 'HoMF: render_info component not found')

   local entity_values = {}
   local role_key
   local gender

   -- Get current gender
   gender = entity:get_component('render_info'):get_model_variant()
   if gender ~= GENDER.FEMALE then
      gender = GENDER.MALE
   end
   self._gender = gender

   -- Get current role
   --TODO: really get current role, don't randomize it!
   --      tmp: solve by only getting the default role, wonder if the entity knows its own role...
   self._role_ind = rng:get_int(1, #self._roles)
   role_key = self._roles[self._role_ind]

   -- Used to store the indexes for the models and material maps used
   self._indexes = {}

   -- Find out which models and material maps are in use
   self:_find_entity_models_and_mats()

   entity_values.material_maps = {}
   for mat_key, mat_table in pairs(self._mats[role_key][gender]) do
      entity_values.material_maps[mat_key] = mat_table[ self._indexes[mat_key] ]
   end

   entity_values.models = {}
   for model_key, model_table in pairs(self._models[role_key][gender]) do
      entity_values.models[model_key] = model_table[ self._indexes[model_key] ]
   end

   entity_values.name   = self:get_entity_name()
   entity_values.gender = gender
   entity_values.role   = role_key
   entity_values.sizes  = self:_get_table_sizes()

   return entity_values
end

function CustomizerController:_load_faction_data(faction_uri)
   local data = radiant.resources.load_json(faction_uri, false)

   -- Remove all duplicate values among the entities' uris.
   for _, role_data in pairs(data.roles) do
      if role_data.male then
         role_data.male.uri = homf.util.only_unique_values(role_data.male.uri, false)
      end

      if role_data.female then
         role_data.female.uri = homf.util.only_unique_values(role_data.female.uri, false)
      end
   end

   return data
end

-- Get data from customization index (male and female) such as customization categories (head_hair, skin_color)
-- and styles data (material map and model file paths for each subcategory).
function CustomizerController:_setup_customization_options_data(data)
   local genders = { GENDER.MALE, GENDER.FEMALE }
   local variant_options_processed = {}

   for role, role_data in pairs(data.roles) do
      for _, gender in pairs(genders) do
         if not role_data[gender] then
            break
         end

         for _, entities_uri in pairs(role_data[gender].uri) do
            local entity_json = radiant.resources.load_json(entities_uri)
            local all_variants = entity_json.entity_data['stonehearth:customization_variants']
            if not all_variants then
               self._log:info('\'%s\' has no customization variants',
                  tostring(entities_uri))
               break
            end

            -- Ensure that customization variants are only processed once
            if homf.util.contains(variant_options_processed,
                                  all_variants.customization_options) then
               break
            end
            table.insert(variant_options_processed, all_variants.customization_options)

            local options =
               radiant.resources.load_json(all_variants.customization_options,
                                           false, false)
            if not options then
               self._log:info('No Json file is linked to \'%s\'',
                  tostring(all_variants.customization_options))
               break
            end

            local mats = {}
            local models = {}

            -- Get all the material maps and models used by
            -- our entity's faction
            for category, cat_data in pairs(options.styles) do
               for key, value in pairs(cat_data.values) do
                  if cat_data.type == CUSTOMIZATION.MATERIAL_MAP then
                     if not mats[category] then
                        mats[category] = {}
                     end
                     if not homf.util.contains(mats[category], key) then
                        table.insert(mats[category], {name = key, mat = value.file})
                     end
                  elseif cat_data.type == CUSTOMIZATION.MODEL then
                     if not models[category] then
                        models[category] = {}
                     end
                     if not homf.util.contains(models[category], key) then
                        table.insert(models[category], {name = key, model = value.file})
                     end
                  end
               end
            end

            -- Get the models from the 'model_variants' component
            local entity_default_models =
               entity_json.components.model_variants.default.models
            for _, model in pairs(entity_default_models) do
               local model_name = self:_get_name_from_model(model)
               if not models[model_name] then
                  models[model_name] = {}
               end

               if not homf.util.contains(models[model_name], model_name) then
                  self._log:detail('adding "%s" among the "%s" models for %ss',
                     model, model_name, gender)
                  table.insert(models[model_name], {name = model_name, model = model})
               else
                  self._log:spam('"%s" has already been added among the "%s" models for %ss',
                     model, model_name, gender)
               end
            end

            -- Store the role
            if not homf.util.contains(self._roles, role) then
               table.insert(self._roles, role)
            end

            -- Store the models and material maps
            if not self._mats[role] then
               self._mats[role] = {}
            end
            if not self._models[role] then
               self._models[role] = {}
            end

            self._mats[role][gender] = mats
            self._models[role][gender] = models
         end
      end
   end
end

function CustomizerController:_complement_gender_data(data)
   for _, role_models in pairs(data) do
      for model, _ in pairs(role_models.male) do
         if not role_models.female[model] then
            role_models.female[model] = { CUSTOMIZATION.NONE }
         end
      end
      for model, _ in pairs(role_models.female) do
         if not role_models.male[model] then
            role_models.male[model] = { CUSTOMIZATION.NONE }
         end
      end
   end
end

function CustomizerController:_find_entity_models_and_mats()
   local role_key = self._roles[self._role_ind]
   local gender   = self._gender

   self._log:spam('finding models and material maps used by %s',
      tostring(self._customizing_entity))

   -- Get the material maps used
   self._render_info:trace_material_maps('getting attached material maps')
      :on_added(function(mat)
         for mat_key, mat_table in pairs(self._mats[role_key][gender]) do
            for index, mat_vals in pairs(mat_table) do
               if mat_vals.mat == mat then
                  self._log:spam('found material map "%s" for "%s"',
                                 mat_vals.name, mat_key)
                  self._indexes[mat_key] = index
                  return
               end
            end
         end
      end)
      :push_object_state()
      :destroy()

   -- Get the models used
   self._model_variants:trace_models('getting attached models')
      :on_added(function(model)
         for model_key, model_table in pairs(self._models[role_key][gender]) do
            for index, model_vals in pairs(model_table) do
               if model_vals.model == model then
                  self._log:spam('found model "%s" for "%s"',
                                 model_vals.name, model_key)
                  self._indexes[model_key] = index
                  return
               end
            end
         end
      end)
      :push_object_state()
      :destroy()

   -- In case the model used wasn't found (i.e. if it's set to CUSTOMIZATION.NONE)
   -- then fill in the blanks to make sure all the keys are registered
   for model, _ in pairs(self._models[role_key][gender]) do
      if not self._indexes[model] then
         self._log:spam('found model "%s" for "%s"', CUSTOMIZATION.NONE, model)
         self._indexes[model] = 1
      end
   end
end

function CustomizerController:randomize_entity(new_gender, locks, new_role_ind)
   local role_key = self._roles[self._role_ind]
   local gender   = self._gender
   local switch_mats_data = {}
   local switch_models_data = {}

   -- Get information on the current material maps and models used,
   -- the information gathered will be later used when switching to new ones
   for mat_key, mat_table in pairs(self._mats[role_key][gender]) do
      if self:_is_open(locks, mat_key) then
         switch_mats_data[mat_key] = {
            old_table = mat_table,
            old_index = self._indexes[mat_key],
         }
      end
   end
   for model_key, model_table in pairs(self._models[role_key][gender]) do
      if self:_is_open(locks, model_key) then
         switch_models_data[model_key] = {
            old_table = model_table,
            old_index = self._indexes[model_key],
         }
      end
   end

   -- Decide the new role
   -- NOTE: if `new_gender` has a value, that means a new gender was chosen by
   -- the player, and, since different roles can have different sets of genders,
   -- it's not randomized
   if new_role_ind then
      self._role_ind = new_role_ind
   elseif not new_gender and self:_is_open(locks, 'role') then
      self._role_ind = rng:get_int(1, #self._roles)
   end
   role_key = self._roles[self._role_ind]

   -- Decide the new gender
   if new_gender then
      gender = new_gender
   else
      gender = self:_get_random_gender(locks)
   end
   if self._gender ~= gender then
      --TODO: get the correct animation table from the entity's json file
      self._render_info:set_animation_table('stonehearth:skeletons:humanoid:' .. gender)
   end
   self._gender = gender

   -- Define some variables. Get copy of the current models and materials used, which will later
   -- be replaced by the newly randomized ones (unless they are locked)
   local name
   local new_mats, new_models, _ = self:get_current_data()

   -- Randomize material maps
   for mat_key, mat_data in pairs(switch_mats_data) do
      local new_mat_table = self._mats[role_key][gender][mat_key]
      local new_mat_index = rng:get_int(1, #new_mat_table)
      new_mats[mat_key] = self:_switch_material_maps(mat_key,
                                                     mat_data.old_index,
                                                     new_mat_index,
                                                     mat_data.old_table,
                                                     new_mat_table)
   end

   -- Randomize models
   for model_key, model_data in pairs(switch_models_data) do
      local new_model_table = self._models[role_key][gender][model_key]
      local new_model_index = rng:get_int(1, #new_model_table)
      new_models[model_key] = self:_switch_models(model_key,
                                                  model_data.old_index,
                                                  new_model_index,
                                                  model_data.old_table,
                                                  new_model_table)
   end
   self:_update_models()

   -- Randomize name
   if self:_is_open(locks, 'name') then
      name = self:_random_name()
   end

   -- self._log:debug('Animation table: %s', tostring(self._render_info:get_animation_table()))

   return {
      name = name,
      gender = gender,
      role = role_key,
      material_maps = new_mats,
      models = new_models,
      sizes = self:_get_table_sizes(),
   }
end

function CustomizerController:get_entity_name()
   return radiant.entities.get_custom_name(self._customizing_entity)
end

function CustomizerController:set_entity_name(name)
   if type(name) == "string" then
      radiant.entities.set_custom_name(self._customizing_entity, name)
   end
end

function CustomizerController:next_role(increment)
   local new_role_ind =
      homf.util.rotate_table_index(self._role_ind, self._roles, increment)
   return self:randomize_entity(nil, nil, new_role_ind)
end

function CustomizerController:next_material_map(mat_name, increment)
   local role_key = self._roles[self._role_ind]
   local gender   = self._gender

   local mat_table = self._mats[role_key][gender][mat_name]

   local old_mat_index = self._indexes[mat_name]
   local new_mat_index =
      homf.util.rotate_table_index(self._indexes[mat_name], mat_table, increment)

   return self:_switch_material_maps(mat_name, old_mat_index, new_mat_index, mat_table)
end

function CustomizerController:next_model(model_name, increment)
   local role_key = self._roles[self._role_ind]
   local gender   = self._gender

   local model_table = self._models[role_key][gender][model_name]

   local old_model_index = self._indexes[model_name]
   local new_model_index =
      homf.util.rotate_table_index(self._indexes[model_name], model_table, increment)

   local new_model =
      self:_switch_models(model_name, old_model_index, new_model_index, model_table)
   self:_update_models()

   return new_model
end

function CustomizerController:get_current_data()
   local role_key = self._roles[self._role_ind]
   local gender   = self._gender

   local current_mats = {}
   for key, mats in pairs(self._mats[role_key][gender]) do
      current_mats[key] = mats[ self._indexes[key] ]
   end

   local current_models = {}
   for key, models in pairs(self._models[role_key][gender]) do
      current_models[key] = models[ self._indexes[key] ]
   end

   return current_mats, current_models, self._roles[role_key]
end

function CustomizerController:_get_random_gender(locks)
   local new_gender = self._gender

   if self:_is_open(locks, 'gender') then
      if rng:get_int(1,2) == 1 then
         new_gender = GENDER.FEMALE
      else
         new_gender = GENDER.MALE
      end
   end

   return new_gender
end

function CustomizerController:_switch_material_maps(mat_key, from_mat_index, to_mat_index, from_mat_map, to_mat_map)
   if not to_mat_map then
      to_mat_map = from_mat_map
   end

   -- Don't switch between the same material maps
   if from_mat_map[from_mat_index].mat == to_mat_map[to_mat_index].mat then
      return to_mat_map[to_mat_index]
   end

   self:_remove_material_map( from_mat_map[from_mat_index].mat )

   self._indexes[mat_key] = to_mat_index
   local new_mat_map = to_mat_map[to_mat_index]
   self:_add_material_map(new_mat_map.mat)

   return new_mat_map
end

function CustomizerController:_add_material_map(material_map)
   if self:_is_valid_style(material_map) then
      self._log:detail('adding material map %s', material_map)
      self._render_info:add_material_map(material_map)
   end
end

function CustomizerController:_remove_material_map(material_map)
   if self:_is_valid_style(material_map) then
      self._log:detail('removing material map %s', material_map)
      self._render_info:remove_material_map(material_map)
   end
end

function CustomizerController:_switch_models(model_key, from_model_index, to_model_index, from_model_table, to_model_table)
   if not to_model_table then
      to_model_table = from_model_table
   end

   -- Don't switch between the same models
   if from_model_table[from_model_index].model == to_model_table[to_model_index].model then
      return to_model_table[to_model_index]
   end

   self:_remove_model( from_model_table[from_model_index].model )

   self._indexes[model_key] = to_model_index
   local new_model = to_model_table[to_model_index]
   self:_add_model(new_model.model)

   return new_model
end

function CustomizerController:_add_model(model)
   if self:_is_valid_style(model) then
      self._log:detail('adding model %s', model)
      self._model_variants:add_model(model)
   end
end

function CustomizerController:_remove_model(model)
   if self:_is_valid_style(model) then
      self._log:detail('removing model %s', model)
      self._model_variants:remove_model(model)
   end
end

function CustomizerController:_update_models()
   -- Set the model variant to its default/female variant
   -- which will force the engine to display the new model
   local variant = ''
   if self._gender == GENDER.FEMALE then
      variant = GENDER.FEMALE
   end
   self._render_info:set_model_variant(variant)
end

function CustomizerController:_random_name()
   local role_key = self._roles[self._role_ind]
   local gender   = self._gender

   local given_names = self._data.roles[role_key][gender].given_names
   local surnames    = self._data.roles[role_key].surnames

   return given_names[rng:get_int(1, #given_names)] ..' '..
          surnames[rng:get_int(1, #surnames)]
end

function CustomizerController:_is_open(locks, lock_name)
   return not locks or not locks[lock_name] or locks[lock_name] == 'unlocked'
end

function CustomizerController:_is_valid_style(style)
   return style ~= nil and style ~= CUSTOMIZATION.NONE and style ~= ''
end

function CustomizerController:_get_name_from_model(model)
   -- We use the first word found in the model's name and get its corresponding key
   -- NOTE: The model key needs to have the key that was used when storing the key.
   --       E.g. chops and various facial hair has the key 'facial_hair'
   --       rather than using its name as a basis.

   local model_filename_start = model:find('/[^/]*$') or 1
   return model:match('%a+', model_filename_start)
end

function CustomizerController:_find_key_from_model(model)
   local role_key = self._roles[self._role_ind]
   local gender   = self._gender

   for model_key, model_table in pairs(self._models[role_key][gender]) do
      for _, model_name in pairs(model_table) do
         if model == model_name then
            return model_key
         end
      end
   end

   return ''
end

function CustomizerController:_get_table_sizes()
   local role_key = self._roles[self._role_ind]
   local gender   = self._gender
   local sizes = {}

   for model_key, model_table in pairs(self._models[role_key][gender]) do
      sizes[model_key] = radiant.size(model_table)
   end

   for mat_key, mat_table in pairs(self._mats[role_key][gender]) do
      sizes[mat_key] = radiant.size(mat_table)
   end

   sizes.role = radiant.size(self._roles)

   return sizes
end

return CustomizerController
