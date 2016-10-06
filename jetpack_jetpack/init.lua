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

      thrust_sound_period = 1, particle_period = 1,

      fire_tex = "tnt_boom.png",
      -- TODO probably want vaguer than TNT version.
      smoke_tex = "tnt_smoke.png", heavy_smoke_tex = "tnt_smoke.png",
   }
}
local use_c = jetpack_configs("jetpack", configs)

-- Patch it through.
local thrust = use_c.thrust
local rates = use_c.rates
local gravity, air_friction = use_c.gravity, use_c.air_friction
local ground_bounce, ground_friction = use_c.ground_bounce, use_c.ground_friction

local walk_force = 1

-- TODO neater..
local function new_t() return 0.1+math.log(1+math.random()/60) end

 -- Somewhat randomly times thrust sounds.
local function thrust_sounds(self, ts)
   self.t = (self.t or -1) - ts
   if self.t < 0 then
      self.t = use_c.thrust_sound_period*new_t()
      minetest.sound_play({name = "fire_extinguish_flame"}, { pos = self.object:getpos() })
   end
end

-- TODO smoke-filled air blocks possible?
local function thrust_particles(self, pos, vel, ts)
   self.t_p = (self.t_p or -1) - ts
   if self.t_p < 0 then
      self.t_p = use_c.particle_period*new_t()

      local radius = 2*(1+math.random())
      minetest.add_particle{
            pos = pos,
            velocity = vel,
            acceleration = vector.new(), expirationtime = 0.4,
            size = radius,
            collisiondetection = false,
            vertical = false,
            texture = use_c.fire_tex,
      }

      local ppos = { x=pos.x, y=pos.y-0.5, z=pos.z }
      local aa = 4
      minetest.add_particlespawner{
            amount = 8, time = 2,
            minpos = pos, maxpos = pos,
            minvel = vel, maxvel = vel,

            minacc = {x=-aa,y=-aa,z=-aa}, maxacc = {x=aa,y=aa,z=aa},
            minexptime = 1, maxexptime = 2.5,
            minsize = radius * 1, maxsize = radius * 3,
            texture = use_c.heavy_smoke_tex,

            collisiondetection=true,
      }
      minetest.add_particlespawner{
            amount = 32, time = 0.5,
            minpos = pos, maxpos = pos,
            minvel = vel, maxvel = vel,

            minacc = {x=-aa,y=-aa,z=-aa}, maxacc = {x=aa,y=aa,z=aa},
            minexptime = 1, maxexptime = 2.5,
            minsize = radius * 1, maxsize = radius * 3,
            texture = use_c.heavy_smoke_tex
      }
   end
end

local function jetpack_timestep(self, ts)
   local driver = self.driver

   local mass, object = driver and 5 or 1, self.object
   local to_v = jp.apply_air_friction(object:getvelocity(), air_friction/mass, ts)
   to_v.y = to_v.y - gravity*ts

   local pos = object:getpos()
   local x,y,z = pos.x, pos.y,pos.z
   local feet = not jp.clear_place(x, y-1, z)  -- Feets on ground.

   local any = false
   if driver then -- TODO emit particles.
      local drown = not jp.clear_place(x, y, z)

      object:set_detach()
      jp.ThrowObj_attach(driver, object)

      local cont = driver:get_player_control()

      local function add_if(which)
         if cont[which] then
            any = true
            return rates[which]
         else
            return 0
         end
      end
      -- Direction of thrust based on direction of input.
      local u = add_if("jump")  + add_if("sneak")
      local f = add_if("up")    + add_if("down")
      local r = add_if("right") + add_if("left")

      local a = driver:get_look_yaw()
      object:setyaw(a)

      if any then -- Any thrust.
         if not drown then
            thrust_sounds(self, ts)

            local factor = thrust*ts/math.sqrt(u*u + f*f + r*r) -- Normalize and acceleration.
            local u,f,r = factor*u, factor*f, factor*r
            local dx,dz = math.cos(a), math.sin(a)

            local tf = 40
            thrust_particles(self, pos,
                             {  x = to_v.x - tf*(dz*r + dx*f),
                                y = to_v.y - tf*u,
                                z = to_v.z + tf*(dx*r - dz*f)
                             }, ts)

            to_v = {
               x = to_v.x + dz*r + dx*f,
               y = to_v.y + u,
               z = to_v.z - dx*r + dz*f
            }
         --else  -- TODO gurgle sound
         end
      end
   end
   if feet then  -- TODO doesnt work.. Does not make sense..

      if not self.last_step or
         driver and (self.last_step.x - pos.x)^2 + (self.last_step.y - pos.y)^2 > 1
      then
         self.last_step = { x=pos.x, y=pos.y }   -- TODO pick right sound?
         minetest.sound_play({name = "default_dirt_footstep"},
            { pos = { x=pos.x, y=pos.y-0.5, z=pos.z } })
      end
      local v = math.sqrt(to_v.x^2 + to_v.z^2)
      local v_reduce = 0.1
      local f = v<0.1 and 0 or (v - v_reduce)/v

      to_v = { x = to_v.x*f, z = to_v.z*f, y = to_v.y }
   else
      self.last_step = nil
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
   visual="mesh",
   mesh="jetpack.obj",
   textures={"jetpack_tex.png"},

   Item = JetpackItem,

   physical = true,
   collide_with_object  =true,
   collisionbox = {-0.3,-0.5,-0.3, 0.3,0.5,0.3},
   weight = 10,

   makes_footstep_sound=false,
   automatic_rotate=true,

--   description = "Jetpack",
   on_step = jetpack_timestep
}
for k,v in pairs(jp.ThrowObj) do Jetpack[k] = Jetpack[k] or v end

-- Actual declaring.
minetest.register_craftitem("jetpack_jetpack:jetpack", JetpackItem)
minetest.register_entity("jetpack_jetpack:jetpack", Jetpack)

minetest.register_alias("jetpack",    "jetpack_jetpack:jetpack")

-- Crafting.
if true then -- minetest.get_modpath("mesecon") then  -- TODO ...
--   local function got(y, n) return minetest.get_modpath("mesecon") and y or n or "" end

   minetest.register_craft{  -- TODO want it kindah expensive?
      output = "jetpack_jetpack:jetpack 1",
      recipe = {
         {"",  --"mesecons_insulated:insulated_off",
          "vessels:steel_bottle",
          "vessels:steel_bottle",
         },
         {"", --"mesecons_switch:mesecon_switch_off",
          "default:steelblock",
          "", --"mesecons_walllever:wall_lever",
         },
         {"", --"mesecons_insulated:insulated_off",
          "default:steelblock",
          "", ---"mesecons_insulated:insulated_off",
         }
      }
   }
end
