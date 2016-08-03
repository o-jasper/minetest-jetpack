Use `/giveme hoverboard` an `/giveme jetpack`(and `/giveme ball`)
once installed and running.

Think I remember left click with the object throws it, right on object
in world picks it up again, and left uses it. Flying is with up/down etc.

## TODO (note: somewhat in the issues)

Collision not quite right yet... Actually look in the direction of movement, for one.

* A function that finds the first(if any) position of colision from a line.
* A function that finds the normal of that collision,
* A function representing bouncing off that.(done)

Jetpack:
* Decided for it not to use alternative physics. Collisions fine.

  Stumpeningly can't seem to give it friction with floor.

* Add getting hurt. Crunchy/auch sounds too, depending on case.
* Better thrust sounds.
* hitting stuff sounds.
* High winds sounds. (for hoverboard too)
* When on ground, just walk/run. (step sounds by distance)
* Stuff to make it less practical:
  + Some putting it on.
  + Smoke particles and even nodes.
  + Fuel.
* (optional)vibration.

Hoverboard:
* Collisions cause a mess sometimes.(better collision, normal finding)
* Convert some of the vertical movement to horizontal when landing.
  (*relative* to surface)
* Pushing in discrete steps? Max speed based on foot speed.(with sounds)
* Sounds based on how hard the hover apparatus needs to work.
* Less practical
  + Getting hurt, falling off.
  + Power use.

Other:
* Player model does not rotate.
* Get sizes of objects right.
* Crafting recipes.
* Use the configs to have different modes.
* Mod with just the high-speed wind sounds.

  It cannot distinguish if inside! So default off.
