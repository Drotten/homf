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

      var zoomToHearthling = cfg['zoom_to_hearthling'];
      if (zoomToHearthling == null)
         zoomToHearthling = true;

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
         zoom_to_hearthling: zoomToHearthling,
         pause_during_customization: pauseDuringCustomization,
      });
   });

   // The view will be added after the town name has been decided
   App.gameView.views.complete.push('HomfCustomizeHearthlingBGView');

   App.stonehearthClient._homfCustomizeHearthling = null;
   App.stonehearthClient.showHomfCustomizer = function(hearthling, isMultiplayer) {
      // Toggle the hearthling customizer
      if (!this._homfCustomizeHearthling || this._homfCustomizeHearthling.isDestroyed) {
         this._homfCustomizeHearthling = App.gameView.addView(App.HomfCustomizeHearthlingView);
         this._homfCustomizeHearthling.startCustomization(hearthling, isMultiplayer);
      } else {
         this._homfCustomizeHearthling.destroy();
         this._homfCustomizeHearthling = null;
      }
   };


   // Adds a console command that begins customization on a selected hearthling

   var selected;

   $(top).on("radiant_selection_changed.unit_frame", function (_, data) {
      selected = data.selected_entity;
   });

   radiant.console.register('homf_custom', {
      call: function(cmdobjs, fn, args) {
         var entity;
         if (args.length > 0)
            entity = 'object://game/' + args[0];
         else
            entity = selected;
         return radiant.call('homf:force_start_customization', entity);
      },
      description: "Customizes a hearthling's looks. " +
                   "Arg 0 is id of the hearthling. " +
                   "If no argument is provided, customizes the " +
                   "currently selected hearthling. " +
                   "If the entity is not your own hearthling, " +
                   "then nothing happens. Usage: homf_custom 12345"
   });
});

App.HomfCustomizeHearthlingBGView = App.View.extend({

   init: function() {
      var self = this;
      radiant.call('radiant:play_sound', {'track': 'stonehearth:sounds:ui:start_menu:submenu_select'});

      // Keep track of whenever a new hearthling joins a player's settlement
      radiant.call('homf:add_customizer')
         .done(function(response) {
            radiant.call('homf:get_tracker')
               .done(function(response) {
                  self.trace = radiant.trace(response.tracker)
                     .progress(function(data) {
                        var hearthling = data.hearthling;
                        var player_id = data.player_id;
                        // The hearthling needs to belong to the current player
                        if (hearthling && player_id && player_id == App.stonehearthClient.getPlayerId()) {
                           self._startCustomization(hearthling);
                        }
                     })
                     .fail(function(e) {
                        console.log(e);
                     });
               });
         });

      // Keep track of whether we are in a multiplayer game
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
   },

   _startCustomization: function(hearthling) {
      App.stonehearthClient.showHomfCustomizer(hearthling, this.get('isMultiplayer'));
   }
});
