-- jetpack - wooosh

-- THIS MOD CODE AND TEXTURES LICENSED
--            <3 TO YOU <3
--    UNDER TERMS OF WTFPL LICENSE

-- 2016 o-jasper; Jasper den Ouden

local jp = jetpack_physics

local function setting(name)
   return minetest.setting_get("jetpack_" .. name)
end

local configs = {
   default = {
      thrust=15,  -- Total resulting thrust. (1.5G)
      -- Amount at which diffent buttons change thrust direction.
      rates = { left = -2, right = 2, up=6, down=-2, jump=6, sneak=-4 },
      gravity = 10, air_friction = 0.1,
      ground_bounce = 0.5, ground_friction = 0.1,
   }
}
local use_c = jetpack_configs("jetpack", configs)

-- Patch it through.
local thrust = use_c.thrust
local rates = use_c.rates
local gravity, air_friction = use_c.gravity, use_c.air_friction
local ground_bounce, ground_friction = use_c.ground_bounce, use_c.ground_friction

 -- Somewhat randomly times thrust sounds.
local function thrust_sounds(self, ts)
   local function new_t() return 0.1+math.log(1+math.random()/60) end
   self.t = (self.t or new_t()) - ts
   if self.t < 0 then
      self.t = new_t()
      minetest.sound_play({name = "fire_extinguish_flame"}, { pos = pos })
   end
end

local function jetpack_timestep(self, ts)
   local driver = self.driver

   local mass, object = driver and 5 or 1, self.object
   local to_v = jp.apply_air_friction(object:getvelocity(), air_friction/mass, ts)
   to_v.y = to_v.y - gravity*ts

   if driver then -- TODO emit particles.
      object:set_detach()
      jp.ThrowObj_attach(driver, object)

      local cont = driver:get_player_control()

      local any = false
      local function add_if(which)
         if cont[which] then
            any = true
            return rates[which]
         else
            return 0
         end
      end
      -- Direction of thrust based on direction of input.
      local u = add_if("jump") + add_if("sneak")
      local f = add_if("up") + add_if("down")
      local r = add_if("right") + add_if("left")

      if any then -- Any thrust.
         thrust_sounds(self, ts)

         local factor = thrust*ts/math.sqrt(u*u + f*f + r*r) -- Normalize and acceleration.
         local u,f,r = factor*u, factor*f, factor*r

         local a = driver:get_look_yaw()
         local dx,dz = math.cos(a), math.sin(a)
         to_v = {
            x = to_v.x + dz*r + dx*f,
            y = to_v.y + u,
            z = to_v.z - dx*r + dz*f,dw
         }
      end
   end

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
   local d,dh,f,b = 1,0.5, ground_friction, ground_bounce
   if block_rel( 0, -d,  0) and driver then
      f = 10  -- Mushy parts handle this
      b = 0
   end

   block_rel(0,  d, 0)
   block_rel(-dh, 0,  0)  block_rel(dh, 0, 0)
   block_rel( 0,  0, -dh) block_rel(0,  0, dh)

   if any and not all then
      to_v = jp.normal_collide({x=nx, y=ny, z=nz}, f,b, to_v)
   end

   -- TODO walk if under-speed.(lower speed limit walking rate.)
   object:setvelocity(to_v)
end

local JetpackItem = {
   description = "Jetpack",
   inventory_image = "jetpack.png",
   stack_max = 1,
   groups = {},  -- TODO surely groups to put it in.   
}
for k,v in pairs(jp.ThrowItem) do JetpackItem[k] = JetpackItem[k] or v end

local Jetpack = {
   Item = JetpackItem,
--   description = "Jetpack",
   on_step = jetpack_timestep
}
for k,v in pairs(jp.ThrowObj) do Jetpack[k] = Jetpack[k] or v end
jp.obj_list["jetpack_jetpack:jetpack"] = Jetpack

-- Actual declaring.
minetest.register_craftitem("jetpack_jetpack:jetpack", JetpackItem)
minetest.register_entity("jetpack_jetpack:jetpack", Jetpack)

minetest.register_alias("jetpack",    "jetpack_jetpack:jetpack")
