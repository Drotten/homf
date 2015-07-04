local Vec3       = _radiant.csg.Point3
local Quat       = _radiant.csg.Quaternion
local Ray        = _radiant.csg.Ray3
local camera     = stonehearth.camera
local deg_to_rad = 3.14159 / 180.0
local moving     = false
local HearthlingCameraCallHandler = class()

-- Finds the best spot for the camera to move to for a close up of the hearthling
function HearthlingCameraCallHandler:move_to_hearthling(session, response, hearthling)
   --[[ Take back when the Quaternion bug is done
   local facing = hearthling:add_component('mob'):get_facing()
   local cam_rot_x = Quat(Vec3(0,1,0), (facing+180.0)*deg_to_rad)
   local cam_rot_y = Quat(Vec3(1,0,0), -30.0*deg_to_rad)

   local camera_pos_x = radiant.math.rotate_about_y_axis(Vec3(0,0,1), facing-90)
   camera_pos_x:scale(3)
   local camera_pos_y = Vec3(0,12,0)
   local entity_pos = hearthling:add_component('mob'):get_world_location()
   local entity_dir = radiant.math.rotate_about_y_axis(Vec3(0,0,1), facing)
   entity_dir:scale(13)
   local camera_pos_z = entity_pos - entity_dir

   local camera_pos = camera_pos_x + camera_pos_y + camera_pos_z
   local camera_rot = cam_rot_x * cam_rot_y
   --]]

   -- [[ TEMP: only until the Quaternion bug is fixed
   if not hearthling or type(hearthling) == 'string' or not hearthling:is_valid() then
      return
   end
   local cam_height = camera:get_position().y
   local entity_pos = hearthling:get_component('mob'):get_location()
   local t = (cam_height - entity_pos.y) / -camera:get_forward().y
   if t > 20 then
      t = 20
   end
   local camera_pos = entity_pos + -camera:get_forward():scaled(t) + camera:get_left():scaled(3)
   local camera_rot = Quat()
   --]] /TEMP

   if moving then
      camera:controller_top():new_position(camera_pos, camera_rot, 2500)
   else
      camera:push_controller('homf:move_rotate_to_camera_controller', camera_pos, camera_rot, 2500, self)
   end
end

function HearthlingCameraCallHandler:follow_hearthling(session, response, hearthling)
   --TODO: create a different camera controller that follows the hearthling entity in real time
end

function HearthlingCameraCallHandler:stop_follow(session, response)
   --TODO: stop following the hearthling
end

function HearthlingCameraCallHandler:set_moving(val)
   moving = val
end

return HearthlingCameraCallHandler