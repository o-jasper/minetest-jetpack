-- jetpack - wooosh

-- THIS MOD CODE AND TEXTURES LICENSED
--            <3 TO YOU <3
--    UNDER TERMS OF WTFPL LICENSE

-- 2016 o-jasper; Jasper den Ouden

--[[ TODO

Collision not quite right yet...

* A function that finds the first(if any) position of colision from a line.
* A function that finds the normal of that collision,
* A function representing bouncing off that.(done)

Jetpack:
* Add getting hurt. (crunchy/auch sounds too)
* Better thrust sounds.
* hitting stuff sounds.
* When on ground, just walk/run.

Hoverboard:
* Convert some of the vertical to horizontal when landing.
* Pushing in discrete steps? Max speed based on foot speed.(with sounds)
* Sounds based on how hard the hover apparatus needs to work?

Other:
* High-speed-wind mod.
* Split off into parts a bit more?
* Crafting recipes.
* Different modes/version. fun&easy and harder version.(hmm lag is an issue)
]]

--[[ TODO
minetest.register_craft({
      output = 'jetpack:jetpack',
      recipe = {
         { '', '', '' },
         { '', '', '' },
         { '','', '' },
      }})
]]

-- minetest.register_globalstep(function(dtime)nunix$

-- TODO easy mode, and -omg-jetpacks-are-super-dangerous- -mode.

local function dot(v, w)	-- Inproduct.
	return v.x*w.x + v.y*w.y + v.z*w.z
end
local function sqr(x) return dot(x,x) end

local function normal_bounce(normal, b, to_v)
   local factor = 2*b*dot(normal, to_v)/sqr(normal)
   if factor > 0 then
      return { x = to_v.x - factor*normal.x,
               y = to_v.y - factor*normal.y,
               z = to_v.z - factor*normal.z }, factor
   else
      return to_v
   end
end

local function normal_collide(normal, f,b, to_v)
   local inpr = -dot(normal, to_v)
   if inpr > 0 then return to_v end

   local nlen = math.sqrt(sqr(normal))
   local factor = inpr/(nlen*nlen)  -- Delta-speed for full stop.
   local dvx,dvy,dvz = factor*normal.x, factor*normal.y, factor*normal.z

   local rdx,rdy,rdz = to_v.x + dvx, to_v.y + dvy, to_v.z + dvz
   -- Figure friction/
   -- Speed parallel surface.
   local bf = 1 + b
   if f > 0 then
      local rdlen = math.sqrt(rdx*rdx + rdy*rdy + rdz*rdz)
      local frict_force = f*bf*factor*nlen
      local ff = math.max(frict_force/rdlen, 1)

      return { x = to_v.x + bf*dvx - ff*rdx,
               y = to_v.y + bf*dvy - ff*rdy,
               z = to_v.z + bf*dvz - ff*rdz, }
   else
      return { x = to_v.x + bf*dvx,
               y = to_v.y + bf*dvy,
               z = to_v.z + bf*dvz, }
   end
end

-- Rates at which they affect thrust direction.
local thrust = 15  -- 1.5 gravity.
local rates = { left = -2, right = 2, up=6, down=-2, jump=6, sneak=-4 }
-- Acceleration provided.
local gravity, air_friction = 10, 0.1

local ground_bounce, ground_friction = 0.5, 0.1

 -- Somewhat randomly times thrust sounds.
local function thrust_sounds(self, ts)
   local function new_t() return 0.1+math.log(1+math.random()/60) end
   self.t = (self.t or new_t()) - ts
   if self.t < 0 then
      self.t = new_t()
      minetest.sound_play({name = "fire_extinguish_flame"}, { pos = pos })
   end
end

local function jetpack_pair(driver, object)
   local a = driver:get_look_yaw()
   local d = 5
   driver:set_attach(object, "", {x=d*math.cos(a),y=0,z=d*math.sin(a)}, {x=0,y=0,z=0})
   object:setyaw(a)
end

local function ok_place(x,y,z)
   local node = minetest.env:get_node({x=x, y=y, z=z})
   local name = node.name
   if name == "air" then
      return true
   end

   local reg = minetest.registered_nodes[node.name]  -- Pass through plants too.(giving a shot)
   if reg then
      -- TODO can give other properties, like lower bump?
      local drawtype = reg.drawtype
      if drawtype == "plantlike" or reg.groups.flora == 1 then
         return true
      end
   end
end

local function apply_gravity_and_air_friction(v, air_friction, gravity, ts)
   local vlen = math.sqrt(v.x^2 + v.y^2 + v.z^2)
   local air_factor = math.max(0, 1 - ts*air_friction*vlen)
   return {
      x = v.x*air_factor,
      y = v.y*air_factor - gravity*ts,
      z = v.z*air_factor,
   }
end

local function jetpack_timestep(self, ts)
   local driver = self.driver

   local mass, object = driver and 5 or 1, self.object
   local to_v = apply_gravity_and_air_friction(object:getvelocity(),
                                               air_friction/mass, gravity, ts)

   if driver then -- TODO emit particles.
      object:set_detach()
      jetpack_pair(driver, object)

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
   local n, any, all = {x=0,y=0,z=0}, false, true
   local function block_rel(dx,dy,dz)
      -- TODO anything you walk through, also prefer if some things more friction?
      if not ok_place(x+dx, y+dy, z+dz) then
         any = true
         n.x, n.y, n.z = n.x + dx, n.y + dy, n.z + dz
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
      to_v = normal_collide(n, f,b, to_v)
   end

   -- TODO walk if under-speed.(lower speed limit walking rate.)
   object:setvelocity(to_v)
end

local push_rates = { jump = 5, right=5, left=-5, up=5, down=5, sneak=0 }
local foot_frict = 2

local function hoverboard_timestep(self, ts)
   local driver = self.driver

   local mass, object = driver and 5 or 1, self.object
   local to_v = apply_gravity_and_air_friction(object:getvelocity(),
                                               air_friction/mass, gravity, ts)

   -- Figure if flying into anything
   local pos = object:getpos()
   local x,y,z = pos.x, pos.y,pos.z
   local n, any, all = {x=0,y=0,z=0}, false, true
   local function block_rel(dx,dy,dz)
      -- TODO anything you walk through, also prefer if some things more friction?
      if not ok_place(x+dx, y+dy, z+dz) then
         any = true
         n.x, n.y, n.z = n.x + dx, n.y + dy, n.z + dz
         return true
      else
         all = false
      end
   end
   -- TODO this has to co-rotate with player direction..
   local d,dh,f = 1,0.5,0
   local can = {  -- If contact that way can use that to move.
      jump  = block_rel( 0, -d,  0),  sneak = block_rel(0,  d, 0),
      right = block_rel(-dh, 0,  0),  left  = block_rel(dh, 0, 0),
      up    = block_rel( 0,  0, -dh), down  = block_rel(0,  0, dh)
   }
   if driver then
      local cont = driver:get_player_control()

      if cont.sneak then f = foot_frict end  -- Apply friction on purpose.

      if cont.jump and can.jump then  -- Push off.
         to_v.y = to_v.y + push_rates.jump
      end
      local f, r = 0, 0
      if cont.left and can.jump then  -- TODO max speed.
         r = r + push_rates.left
      end
      if cont.right and can.jump then
         r = r + push_rates.right
      end
      if cont.up and can.jump then
         f = f + push_rates.up
      end
      if cont.down and can.jump then
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
      to_v = normal_collide(n, f,0, to_v)  -- Bounceless.
   end

   -- TODO walk if under-speed.(lower speed limit walking rate.)
   object:setvelocity(to_v)
end

local function is_water(pos)
	local nn = minetest.env:get_node(pos).name
	return minetest.get_item_group(nn, "water") ~= 0
end

local function surface_rel(pointed)
   local u,a = pointed.under, pointed.above
   for k,v in pairs(u) do
      if v ~= a[k] then
         return k, a[k] - v
      end
   end
end

local function on_place_fun(name)
   return function(itemstack, placer, pointed_thing)
      -- Just throw it a bit.
      local pos,dir = placer:getpos(), placer:get_look_dir()
      pos.x,pos.y,pos.z = pos.x + dir.x,pos.y + dir.y + 1,pos.z + dir.z

      local obj = minetest.env:add_entity(pos, name)
      local v, vy = 2, 1
      local spd = { x=0,y=0,z=0 } -- placer:getvelocity() (ah well)
      obj:setvelocity{ x=spd.x + v*dir.x, y=spd.y + v*dir.y + vy, z=spd.z + v*dir.z }

      itemstack:take_item()
      return itemstack
   end
end

minetest.register_craftitem("jetpack:jetpack", {
	description = "Jetpack",
	inventory_image = "jetpack.png",
	stack_max = 1,
	groups = {},  -- TODO surely groups to put it in.

	on_place = on_place_fun("jetpack:jetpack"),
})

local function on_punch_fun(name)
   return  function(self, puncher, time_from_last_punch, tool_capabilities, direction)
      self.object:remove()
      if puncher and puncher:is_player() then
         -- TODO can use self. something?
         puncher:get_inventory():add_item("main", name)
      end
   end
end

local Jetpack = {
  on_rightclick = function(self, clicker)
     if not clicker or not clicker:is_player() then
        return
     end
     if self.driver and clicker == self.driver then
        self.driver = nil
        clicker:set_detach()
     elseif not self.driver then
        self.driver = clicker  -- TODO anim of putting on back?
        jetpack_pair(clicker, self.object)
     end
  end,
  on_activate = function(self, staticdata, dtime_s)
     self.object:set_armor_groups({immortal=1})
     if staticdata then
        self.v = tonumber(staticdata)
     end
  end,

  on_punch = on_punch_fun("jetpack:jetpack"),

  on_step = jetpack_timestep
}

minetest.register_entity("jetpack:jetpack", Jetpack)

minetest.register_craftitem("jetpack:hoverboard", {
	description = "Hoverboard",
	inventory_image = "hoverboard.png",
	stack_max = 1,
	groups = {},  -- TODO surely groups to put it in.

	on_place = on_place_fun("jetpack:hoverboard"),
})

local Hoverboard = {
   on_rightclick = Jetpack.on_rightclick,
   on_activate = Jetpack.on_activate,
   on_punch = on_punch_fun("jetpack:hoverboard"),

   on_step = hoverboard_timestep
}
minetest.register_entity("jetpack:hoverboard", Hoverboard)

minetest.register_alias("jetpack",    "jetpack:jetpack")
minetest.register_alias("hoverboard", "jetpack:hoverboard")
