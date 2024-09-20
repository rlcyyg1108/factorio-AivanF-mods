data:extend{
  -- Startup
  {
    type = "double-setting",
    name = "wh40k-titans-ruin-prob",
    setting_type = "startup",
    minimum_value = 0.01,
    default_value = 0.06,
    maximum_value = 0.1,
    order = "a-1",
  },
  {
   type = "bool-setting",
    name = "wh40k-titans-aai-vehicle",
    setting_type = "startup",
    default_value = true,
    order = "a-2",
  },
  {
    type = "int-setting",
    name = "wh40k-titans-resist-const",
    setting_type = "startup",
    minimum_value = 0,
    default_value = 500,
    maximum_value = 10 * 1000,
    order = "a-3",
  },
  {
    type = "int-setting",
    name = "wh40k-titans-resist-mult",
    setting_type = "startup",
    minimum_value = 0,
    default_value = 100,
    maximum_value = 10 * 1000,
    order = "a-4",
  },
  {
    type = "int-setting",
    name = "wh40k-titans-base-shield-cap-cf",
    setting_type = "startup",
    minimum_value = 1,
    default_value = 1,
    maximum_value = 10,
    order = "a-5",
  },

  -- Map/global
  {
    type = "bool-setting",
    name = "wh40k-titans-talk",
    setting_type = "runtime-global",
    default_value = true,
    order = "a-1",
  },
}