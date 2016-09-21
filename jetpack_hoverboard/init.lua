local jp = jetpack_physics

local configs = {
   default = {
      air_friction = 0.1, gravity = 10,
      push_rates = { jump = 5, right=5, left=-5, up=5, down=5, sneak=0 },

      foot_frict = 0.1, max_side_v=1, max_forw_v=2,
   }
}
local use_c = jetpack_configs("jetpack_ball", configs)

local air_friction, gravity = use_c.air_friction, use_c.gravity
local push_rates = use_c.push_rates

local function hoverboard_timestep(self, ts)
   local driver = self.driver

   local mass, object = driver and 5 or 1, self.object
   local to_v = jp.apply_air_friction(object:getvelocity(),
                                      air_friction/mass, ts)
   to_v.y = to_v.y - gravity*ts

   -- Figure if flying into anything
   local pos = object:getpos()
   local x,y,z = pos.x, pos.y,pos.z
   local nx,ny,nz, any, all = 0,0,0, false, true
   local function block_rel(dx,dy,dz)
      -- TODO anything you walk through, also prefer if some things more friction?
      if not jp.clear_place(x+dx, y+dy, z+dz) then
         any = true
         nx, ny, nz = nx - dx, ny - dy, nz - dz
         return true
      else
         all = false
      end
   end
   -- TODO this has to co-rotate with player direction..
   local dh,f = 1,0
   local can = {  -- If contact that way can use that to move.
      jump  = block_rel( 0, -1.5,  0), _     = block_rel(0,  1, 0),
      right = block_rel(-dh, 0,  0),   left  = block_rel(dh, 0, 0),
      up    = block_rel( 0,  0, -dh),  down  = block_rel(0,  0, dh)
   }
   if driver then
      local a = driver:get_look_yaw()
      local c,s = math.cos(a), math.sin(a)
      local fv, sv = to_v.x*c + to_v.y*s, to_v.x*s - to_v.y*c

      local cont = driver:get_player_control()

      if cont.sneak then f = use_c.foot_frict end  -- Apply friction on purpose.

      if cont.jump and can.jump then  -- Push off. -- TODO "only once"
         to_v.y = to_v.y + push_rates.jump
      end
      local f, r = 0, 0
      -- Todo step sounds.
      if cont.left and can.jump and math.abs(sv) < use_c.max_side_v then  -- TODO max speed.
         r = r + push_rates.left
      end
      if cont.right and can.jump and math.abs(sv) < use_c.max_side_v then
         r = r + push_rates.right
      end
      if cont.up and can.jump and math.abs(sv) < use_c.max_forw_v then
         f = f + push_rates.up
      end
      if cont.down and can.jump and math.abs(sv) < use_c.max_forw_v then
         f = f + push_rates.down
      end

      if f ~= 0 or r ~= 0 then
         local f, r = f*ts, r*ts

         local a = driver:get_look_yaw()
         local dx,dz = math.cos(a), math.sin(a)

         to_v.x = to_v.x + f*dx + r*dz
         to_v.z = to_v.z + f*dz - r*dx
      end
   end

   if any and not all then
      local len = function(v) return math.sqrt(v.x^2 + v.y^2 + v.z^2) end
      local vlen = len(to_v)
      to_v = jp.normal_collide({x=nx, y=ny, z=nz}, f,0, to_v)  -- Friction and bounceless.

      local post_vlen = len(to_v)  -- Conserve speed of collision.
      if post_vlen > 0 then  -- TODO just don't go under some fraction instead?
         local f = vlen/post_vlen
         to_v.x,to_v.y,to_v.z = to_v.x*f,to_v.y*f,to_v.z*f
      end
   end

   -- TODO walk if under-speed.(lower speed limit walking rate.)
   object:setvelocity(to_v)
end

local HoverboardItem = {
   description = "Hoverboard",
   inventory_image = "hoverboard.png",
   stack_max = 1,
   groups = {},  -- TODO surely groups to put it in.   
}
for k,v in pairs(jp.ThrowItem) do HoverboardItem[k] = HoverboardItem[k] or v end

local Hoverboard = {

--   physical = true,  -- Doesn't work too well here.
--   collide_with_object  =true,
--   collisionbox = {-0.1,-0.05,-0.1, 0.1,0.5,0.1},
--   weight = 4,

   Item = HoverboardItem,
--   description = "Hoverboard",

   attach_how = {{0,-1,0}, {0,-1,0}},

   on_step = hoverboard_timestep
}
for k,v in pairs(jp.ThrowObj) do Hoverboard[k] = Hoverboard[k] or v end

minetest.register_craftitem("jetpack_hoverboard:hoverboard", HoverboardItem)
minetest.register_entity("jetpack_hoverboard:hoverboard", Hoverboard)

minetest.register_alias("hoverboard", "jetpack_hoverboard:hoverboard")
