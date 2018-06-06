local Vec3       = _radiant.csg.Point3
local Quat       = _radiant.csg.Quaternion
local Ray        = _radiant.csg.Ray3
local cam        = stonehearth.camera
local deg_to_rad = 3.14159 / 180.0
local cam_moving = false
local CameraCallHandler = class()

-- Finds the best spot for the camera to move to for a close up of the entity
function CameraCallHandler:move_to_entity(session, response, entity)
   --[[ Take back when the Quaternion bug is done
   local facing = entity:add_component('mob'):get_facing()
   local cam_rot_x = Quat(Vec3(0,1,0), (facing+180.0)*deg_to_rad)
   local cam_rot_y = Quat(Vec3(1,0,0), -30.0*deg_to_rad)

   local camera_pos_x = radiant.math.rotate_about_y_axis(Vec3(0,0,1), facing-90)
   camera_pos_x:scale(3)
   local camera_pos_y = Vec3(0,12,0)
   local entity_pos = entity:add_component('mob'):get_world_location()
   local entity_dir = radiant.math.rotate_about_y_axis(Vec3(0,0,1), facing)
   entity_dir:scale(13)
   local camera_pos_z = entity_pos - entity_dir

   local camera_pos = camera_pos_x + camera_pos_y + camera_pos_z
   local camera_rot = cam_rot_x * cam_rot_y
   --]]

   -- [[ TEMP: only until the Quaternion bug is fixed
   if not entity or type(entity) == 'string' or not entity:is_valid() then
      return
   end
   local cam_height = cam:get_position().y
   local entity_pos = entity:get_component('mob'):get_location()
   local t = (cam_height - entity_pos.y) / -cam:get_forward().y
   if t > 20 then
      t = 20
   end
   local camera_pos = entity_pos + -cam:get_forward():scaled(t) + cam:get_left():scaled(3)
   local camera_rot = Quat()
   --]] /TEMP

   if not cam_moving then
      cam:push_controller('homf:move_rotate_to_camera_controller')
   end
   cam:controller_top():set_cam_values(camera_pos, camera_rot, 2500, self)
end

function CameraCallHandler:follow_entity(session, response, entity)
   --TODO: create a different camera controller that follows the entity entity in real time
end

function CameraCallHandler:stop_follow(session, response)
   --TODO: stop following the entity
end

function CameraCallHandler:set_cam_moving(is_moving)
   cam_moving = is_moving
end

return CameraCallHandler
