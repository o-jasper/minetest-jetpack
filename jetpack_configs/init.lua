
function jetpack_configs(modname, configs)
   local function setting(name)
      return minetest.setting_get(modname .. "_" .. name)
   end

   local by_name = setting("config")

   local matched = string.match(by_name or "", "^(.+):?custom$")
   if matched then  -- Custom version, changes to `matched`
      if not config_matched[matched] and matched ~= "" then  -- TODO better.
         print("WARNING invalid named config, using default", matched)
      end
      local custom = {}
      for k,v in pairs(config[matched] or config.default) do  -- Base on default/given set.
         if type(v) == "number" then
            custom[k] = v or tonumber(setting(k))
         elseif type(v) == "string" then
            custom[k] = v or setting(k)
         elseif type(v) == "boolean" then
            if v ~= nil then
               custom[k] = v
            else
               custom[k] = (setting(k) == "true")
            end
         else  -- Not yet supported.
            custom[k] = v
         end
      end
      return custom
   else
      -- TODO warn if .default via incorrect specification.
      return configs[by_name or "default"] or configs.default
   end
end
