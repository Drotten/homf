App.HomfCustomizerView = App.View.extend({
   templateName: 'customizer',
   classNames: ['flex', 'fullScreen'],
   closeOnEsc: true,

   lockDependencies: {
      1: [ 'roleLock' ],
      2: [ 'genderLock' ],
      3: [ 'bodyLock' ],
      4: [ 'headLock' ],
   },

   init: function() {
      this._super();
      this._pause_during_customization = true;
      this._zoom_to_entity = true;
      var self = this;

      radiant.call('radiant:get_config', 'mods.homf')
         .done(function(o) {
            var cfg = (o || {})['mods.homf'] || {};

            self._pause_during_customization = cfg['pause_during_customization'];
            if (self._pause_during_customization == null)
               self._pause_during_customization = true;

            self._zoom_to_entity = cfg['zoom_to_entity'];
            if (self._zoom_to_entity == null)
               self._zoom_to_entity = true;
         });
   },

   didInsertElement: function() {
      this._super();
      var self = this;

      this.$('#entityName').keydown(function(e) {
         // Backspace - remove the last character in the name
         if (e.keyCode == 8) {
            var newName = self.$('#entityName').val();
            newName = newName.substring(0, newName.length-1);
            radiant.call('homf:set_entity_name', newName);
         }
         // Enter - deselect the input text
         else if (e.keyCode == 13) {
            self.$('#entityName').blur();
         }
      });

      this.$('#entityName').keypress(function(e) {
         var newName = self.$('#entityName').val() + String.fromCharCode(e.keyCode);
         radiant.call('homf:set_entity_name', newName);
      });

      this.$('.ok').click(function() {
         self.destroy();
      });

      this._updateTooltips();
   },

   actions: {
      randomize: function() {
         radiant.call('radiant:play_sound', {'track': 'stonehearth:sounds:ui:start_menu:reroll'});
         this._randomizeEntity(null);
      },

      setGender: function(gender) {
         radiant.call('radiant:play_sound', {'track': 'stonehearth:sounds:ui:start_menu:submenu_select'});
         this._randomizeEntity(gender);
         if (gender == 'male') {
            self.$('#maleButton').addClass('selected');
            self.$('#femaleButton').removeClass('selected');
         }
         else {
            self.$('#maleButton').removeClass('selected');
            self.$('#femaleButton').addClass('selected');
         }
      },

      nextRole: function(isNext) {
         radiant.call('radiant:play_sound', {'track': 'stonehearth:sounds:ui:start_menu:submenu_select'});

         var self = this;
         radiant.call('homf:next_role', isNext)
            .done(function(response) {
               self._resetLocks(2);
               self._processEntityData(response);
            });
      },

      nextModel: function(key, isNext) {
         radiant.call('radiant:play_sound', {'track': 'stonehearth:sounds:ui:start_menu:submenu_select'});

         var self = this;
         radiant.call('homf:next_model', key, isNext)
            .done(function(response) {
               var modelName = response.model.name;
               document.getElementById(key).innerHTML = self._localeString(modelName, {});
            });
      },

      nextMaterialMap: function(key, isNext) {
         radiant.call('radiant:play_sound', {'track': 'stonehearth:sounds:ui:start_menu:submenu_select'});

         var self = this;
         radiant.call('homf:next_material_map', key, isNext)
            .done(function(response) {
               var matName = response.material_map.name;
               document.getElementById(key).innerHTML = self._localeString(matName, {strip: '_material_map|skin_|hair_'});
            });
      },

      toggleLock: function(key) {
         this._toggleLock(key);
      }
   },

   destroy: function() {
      if (this._entity) {
         radiant.call('radiant:play_sound', {'track': 'stonehearth:sounds:ui:start_menu:trigger_click'});

         radiant.call('homf:finish_customization');
         if (this._pause_during_customization && !this.get('isMultiplayer'))
            radiant.call('stonehearth:dm_resume_game');
      }

      this._entity = null;
      this._super();
   },

   startCustomization: function(entity, isMultiplayer) {
      if (entity != null) {
         this.set('isMultiplayer', isMultiplayer);
         var self = this;

         this._entity = entity;

         radiant.call('homf:start_customization')
            .done(function(response) {
               self.$('#entityName').val(response.name);

               if (response.gender == 'male')
                  self.$('#maleButton').addClass('selected');
               else
                  self.$('#femaleButton').addClass('selected');

               self.set('multiple_roles', response.sizes.role > 1);
               self.set('role', self._prettyString(response.role, {}));
               self.set('roleLockStatus', 'unlocked');

               self._resetLocks();

               var options = {};

               var models = radiant.map_to_array( self._modifyMap(response.models, response.sizes, options) );
               self.set('models', models);

               options.displayNameStrip = '_material_map|skin_|hair_';
               var material_maps = radiant.map_to_array( self._modifyMap(response.material_maps, response.sizes, options) );
               self.set('material_maps', material_maps);

               self._setupLocks([ models, material_maps ]);

               if (self._zoom_to_entity)
                  radiant.call('homf:move_to_entity', entity);
               if (self._pause_during_customization && !self.get('isMultiplayer'))
                  radiant.call('stonehearth:dm_pause_game');
            });
      }
      else {
         this.destroy();
      }
   },

   _randomizeEntity: function(newGender) {
      var self = this;
      var locks = null;

      if (newGender == null)
         locks = self._getLocks();

      radiant.call('homf:randomize_entity', newGender, locks)
         .done(function(response) {
            if (newGender)
               self._resetLocks(3);

            self._processEntityData(response, locks);
         });
   },

   _processEntityData: function(data, locks) {
      if (!locks)
         locks = this._getLocks();

      if (data.name) {
         this.$('#entityName').val(data.name);
         radiant.call('homf:set_entity_name', data.name);
      }

      self.$('#femaleButton').removeClass('selected');
      self.$('#maleButton').removeClass('selected');
      if (data.gender == 'male')
         self.$('#maleButton').addClass('selected');
      else
         self.$('#femaleButton').addClass('selected');

      if (data.role) {
         this.set('multiple_roles', data.sizes.role > 1);
         this.set('role', this._prettyString(data.role, {}));
         var lockStatus = 'unlocked';
         if (locks  &&  locks.role)
            lockStatus = locks.role;
         this.set('roleLockStatus', lockStatus);
      }

      var options = {};

      var models = radiant.map_to_array( this._modifyMap(data.models, data.sizes, options) );
      this.set('models', models);

      options.displayNameStrip = '_material_map|skin_|hair_';
      var material_maps = radiant.map_to_array( this._modifyMap(data.material_maps, data.sizes, options) );
      this.set('material_maps', material_maps);

      this._setupLocks([ models, material_maps ]);
   },

   _updateTooltips: function() {
      var self = this;
      var ttPath = "homf:ui.data.tooltips.";

      var buttons = ["maleButton", "femaleButton", "randomButton", "nextButton", "previousButton"];
      radiant.each(buttons, function(i, button) {
         var description = i18n.t(ttPath + button + ".description");
         self.$('#' + button).tooltipster({content: description});
      });

      var size = this._getObjectSize(this.lockDependencies);
      var description = i18n.t(ttPath + "lock.description");
      for (var i = 1; i <= size; i+=1) {
         radiant.each(this.lockDependencies[i], function(_, lock) {
            self.$('#' + lock).tooltipster({content: description});
         });
      }
   },

   _resetLocks: function(startInd) {
      if (startInd == null)
         startInd = 1;

      var self = this;

      var size = this._getObjectSize(this.lockDependencies);
      for (var i = startInd; i <= size; i+=1) {
         radiant.each(this.lockDependencies[i], function(_, lock) {
            self.$('#' + lock).attr('class', 'unlocked');
         });
      }

      this.$('#nameLock').attr('class', 'unlocked');
   },

   _setupLocks: function(componentsArr) {
      // Setup the locks so that when something is locked, it will also make sure to lock everything that
      // it is dependent on (e.g. when locking a model, it will also have to lock the gender)
      var self = this;
      this.lockDependencies[5] = [];
      var variousDependencies = [];

      radiant.each(componentsArr, function(_, components) {
         radiant.each(components, function(_, component) {
            var push = true;
            radiant.each(self.lockDependencies, function(_, lockDepArr) {
               radiant.each(lockDepArr, function(_, lockDep) {
                  if (lockDep == component.lockKey) {
                     push = false;
                     return;
                  }
               });

               if (!push) return;
            });
            if (push)
               variousDependencies.push(component.lockKey);
         });
      });

      this.lockDependencies[5] = variousDependencies;
   },

   _getLocks: function() {
      var locks = {};

      locks.name   = this.$('#nameLock').attr('class');
      locks.gender = this.$('#genderLock').attr('class');

      var mulRoles = this.get('multiple_roles');
      if (mulRoles)
         locks.role = this.$('#roleLock').attr('class');
      else
         locks.role = 'locked';

      var material_maps = this.get('material_maps');
      radiant.each(material_maps, function(_, material_map) {
         var element = this.$('#' + material_map.lockKey);
         if (element)
            locks[material_map.key] = element.attr('class');
         else
            locks[material_map.key] = 'locked';
      });

      var models = this.get('models');
      radiant.each(models, function(_, model) {
         var element = this.$('#' + model.lockKey);
         if (element)
            locks[model.key] = element.attr('class');
         else
            locks[model.key] = 'locked';
      });

      return locks;
   },

   _toggleLock: function(lock) {
      var toStatus = 'unlocked';
      if (this.$('#' + lock).attr('class') == 'unlocked')
         toStatus = 'locked';

      this._changeLockStatus(lock, toStatus);
   },

   _changeLockStatus: function(lock, newStatus) {
      radiant.call('radiant:play_sound', {'track': 'stonehearth:sounds:ui:start_menu:submenu_select'});

      var self = this;

      var lockOrder = 0;
      radiant.each(this.lockDependencies, function(order, lockDepArr) {
         radiant.each(lockDepArr, function(_, lockDep) {
            if (lockDep == lock) {
               lockOrder = parseInt(order);
               return;
            }
         });

         if (lockOrder > 0) return;
      });

      this.$('#' + lock).attr('class', newStatus);
      if (newStatus == 'unlocked') {
         var size = this._getObjectSize(this.lockDependencies);
         for (var i = lockOrder + 1; i <= size; i+=1) {
            radiant.each(this.lockDependencies[i], function(_, lockDep) {
               self.$('#' + lockDep).attr('class', newStatus);
            });
         }
      }
      else { // (newStatus == 'locked')
         for (var i = lockOrder - 1; i > 0; --i) {
            radiant.each(this.lockDependencies[i], function(_, lockDep) {
               self.$('#' + lockDep).attr('class', newStatus);
            });
         }
      }
   },

   _getObjectSize: function(obj) {
      var size = 0;
      for (key in obj) {
         if (obj.hasOwnProperty(key))
            ++size;
      }
      return size;
   },

   _modifyMap: function(map, sizes, options) {
      var self = this;
      var locks = this._getLocks();
      var new_map = {};

      $.each(map, function(id, val) {
         var displayKeyOptions = {
            prefix: options.displayKeyPrefix,
            postfix: options.displayKeyPostfix,
            strip: options.displayKeyStrip,
         };

         var displayNameOptions = {
            prefix: options.displayNamePrefix,
            postfix: options.displayNamePostfix,
            strip: options.displayNameStrip,
         };

         var lockStatus = 'unlocked';
         if (locks[id])
            lockStatus = locks[id];

         new_map[id] = {
            displayKey: self._localeString(id, displayKeyOptions),
            displayName: self._localeString(val.name, displayNameOptions),
            key: id,
            lockKey: id + 'Lock',
            lockStatus: lockStatus,
            multiple_choices: sizes[id] > 1,
         };
      });

      return new_map;
   },

   _localeString: function(str, options) {
      var locStr = i18n.t('stonehearth:ui.shell.select_roster.' + str);
      if (locStr === 'stonehearth:ui.shell.select_roster.' + str)
         locStr = this._prettyString(str, options);
      return locStr;
   },

   _prettyString: function(str, options) {
      if (str == null  ||  typeof str !== 'string')
         return str;

      if (options.strip) {
         var stripArr = options.strip.split('|');
         $.each(stripArr, function(_, strip) {
            str = str.replace(RegExp(strip, 'g'), '');
         });
      }

      // Replace underscores with a space
      str = str.replace(/_/g, ' ');

      // Remove all brackets
      str = str.replace(/\[/g, '').replace(/\]/g, '');

      // Turn the first character of each word into upper case
      str = str.replace(/\w\S*/g, function(txt) {
         return txt.charAt(0).toUpperCase() + txt.substring(1).toLowerCase();
      });

      return (options.prefix ? options.prefix : '') +
             str +
             (options.postfix ? options.postfix : '');
   }
});
