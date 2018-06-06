$(top).on('stonehearthReady', function(cc) {
   // Initiates the config with new values if these aren't there already
   radiant.call('radiant:get_config', 'mods.homf').done(function(o) {
      var cfg = (o || {})['mods.homf'] || {};

      var customizeEmbarking = cfg['customize_embarking'];
      if (customizeEmbarking == null)
         customizeEmbarking = false;

      var customizeImmigrating = cfg['customize_immigrating'];
      if (customizeImmigrating == null)
         customizeImmigrating = true;

      var zoomToEntity = cfg['zoom_to_entity'];
      if (zoomToEntity == null)
         zoomToEntity = true;

      var pauseDuringCustomization = cfg['pause_during_customization'];
      if (pauseDuringCustomization == null)
         pauseDuringCustomization = true;

      /*
      var cameraFollow = cfg['camera_follow'];
      if (cameraFollow == null)
         cameraFollow = true;
      */

      radiant.call('radiant:set_config', 'mods.homf', {
         customize_embarking: customizeEmbarking,
         customize_immigrating: customizeImmigrating,
         zoom_to_entity: zoomToEntity,
         pause_during_customization: pauseDuringCustomization,
      });
   });

   // Adding the background view which initiates a customizer window for the entities
   App.gameView.views.complete.push("HomfCustomizerBGView");


   // Adds a console command that begins customization on a selected entity

   var selected;

   $(top).on("radiant_selection_changed.unit_frame", function (_, data) {
      selected = data.selected_entity;
   });

   radiant.console.register('homf_custom', {
      call: function(cmdobjs, fn, args) {
         var entity;
         if (args._.length > 0)
            entity = 'object://game/' + args._[0];
         else
            entity = selected;
         return radiant.call('homf:force_start_customization', entity);
      },
      description: "Customizes an entity's looks. " +
                   "Arg 0 is id of the entity. " +
                   "If no argument is provided, customizes the " +
                   "currently selected entity. " +
                   "If the entity is not your own: " +
                   "nothing happens. Usage: homf_custom 12345"
   });
});


App.HomfCustomizerBGView = App.View.extend({

   init: function() {
      var self = this;
      this._customizerWindow = null;

      // Keep track of whenever a new entity joins a player's settlement
      radiant.call('homf:add_customizer')
         .done(function(response) {
            radiant.call('homf:get_tracker')
               .done(function(response) {
                  self.trace = radiant.trace(response.tracker)
                     .progress(function(data) {
                        var entity = data.entity;
                        var player_id = data.player_id;
                        // The entity needs to belong to the current player
                        if (entity && player_id && player_id == App.stonehearthClient.getPlayerId()) {
                           self._startCustomization(entity);
                        }
                     })
                     .fail(function(e) {
                        console.log(e);
                     });
               });
         });

      // Keep track of whether we are in a multiplayer game
      if (App.stonehearthClient.isHostPlayer === "function") {
         if (App.stonehearthClient.isHostPlayer()) {
            radiant.call('stonehearth:get_service', 'session_server')
               .done(function(response) {
                  self._sessionTrace = new RadiantTrace(response.result)
                     .progress(function (service) {
                        if (self.isDestroying || self.isDestroyed) {
                           return;
                        }
                        self.set('isMultiplayer', service.remote_connections_enabled);
                     });
                  });
         } else {
            this.set('isMultiplayer', true);
         }
      }
   },

   _startCustomization: function(entity) {
      // Toggle the entity customizer window
      if (!this._customizerWindow || this._customizerWindow.isDestroyed) {
         this._customizerWindow = App.gameView.addView(App.HomfCustomizerView);
         this._customizerWindow.startCustomization(entity, this.get('isMultiplayer'));
      } else {
         this._customizerWindow.destroy();
         this._customizerWindow = null;
      }
   }
});
