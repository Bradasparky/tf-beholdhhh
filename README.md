# [TF2] Behold, the Horseless Headless Horsemann!

Inspired by FlaminSarge's and Pelipoika's [Be The Horsemann](https://forums.alliedmods.net/showthread.php?t=166819)

Allows admins and other plugins to turn players into the Horseless Headless Horsemann.

The Horsemann is made to be faithful to the boss NPC both visually and mechanically, while still being loyal to RED/BLU.

[Video Demonstration](https://youtu.be/HjLfcrWLSoA)

### Dependencies

- SourceMod 1.12+
- This plugin will not work without the custom model provided in the repo!

### Admin Command

- `sm_behhh <#userid|name> [health]` - Choose a player to become the Horsemann. Optionally set the health of the player. Setting the health to 0 or below will default to the value of `sm_beholdhhh_maxhealth`.

### Convars

- `sm_beholdhhh_dropammo (Default 0)` - Whether HHH should drop an ammo kit on death.
- `sm_beholdhhh_maxhealth (Default 1000)` - HHH's max health.
- `sm_beholdhhh_scare_cooldown (Default 20.0)` - HHH's scare cooldown.
- `sm_beholdhhh_scare_duration (Default 2.0)` - HHH's scare duration.
- `sm_beholdhhh_scare_distance (Default 500.0)` - HHH's scare distance.
- `sm_beholdhhh_melee_damage_mult (Default 0.8)` - HHH's melee damage mult relative to the victim's max health.
- `sm_beholdhhh_screenshake_disabled (Default 0)` - Whether to disable HHH screen shake when walking or hitting the world.

### Model Credits

Improved Horsemann player model - [VSH+ on Gamebanana](https://gamebanana.com/mods/197926)

Removed the headtaker and removed cape jiggle bones to work with varying player model scales - [Dice](https://github.com/JimmyPLightning)