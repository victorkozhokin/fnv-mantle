# fnv-mantle

Climbing over things in Fallout: New Vegas.

The obstacle is measured with ray casts at the moment you ask, so the height of
the climb is whatever the obstacle happens to be — a kerb, a picket fence, a
crate, a wall taken with a running jump. Nothing is authored per object and
nothing is snapped to preset heights.

There is **no plugin and no esp**. It is two scripts, three animations and ten
sounds.

## Requirements

- **xNVSE**
- **JIP LN NVSE** — the ray casts, and the loose script layer this runs in
- **JohnnyGuitar NVSE** — `PlaySoundFromPath`, which is what keeps the climb
  sounds esp-less
- **[Player Physics](https://github.com/victorkozhokin/fnv-player-physics)** —
  the trigger asks it whether the player is getting anywhere and how long they
  have been off the ground. Those two questions can only be answered honestly
  from inside the movement solve, which is why they live there. An older build
  fails to compile the script at all, which disables the whole mod rather than
  one feature.

Optional:

- **MCM Extender** — for the settings menu. Without it the defaults apply and
  everything is still adjustable from `Data\config\Mantle.ini`.
- **Enhanced Movement** — supplies the sprint state the running climb animation
  is chosen by. Without it that animation simply never comes up.

## Installing

Copy `nvse`, `meshes`, `Sound`, `config` and `MCM` into `Data`. Contents of
`MCM-RU` are optional Russian menu text; see the readme inside it.

## Using it

Hold forward into something and press activate. That is all of it.

Jumping at a wall works too, and reaches higher: every measurement is taken
relative to where the player is *now*, so a jump lifts the whole reachable
window along with the body.

The settings worth knowing:

| | |
|---|---|
| Automatic | Climbs on being stopped by something, without the key. Off by default. |
| Retry delay | The whole of the delay before a climb — none of the tests wait. |
| Camera dip | Degrees the view dips mid-climb. Additive; nothing is locked and the mouse answers throughout. |
| Forward push | The shove that stops you arriving on top of an obstacle and standing dead still. |

## How it works

`STATE.md` is the short version: what is settled, what is open, and the facts
about the engine that cost a session each to find. `RESEARCH.md` covers what
New Vegas does and does not offer here, and `RESEARCH-skyparkour.md` is a read
of Skyrim's SkyParkour NG, several ideas from which are in this.

## Credits

- Animations — **DRIIRE**
- Sounds — **Mr.Shersh**

Both made for this mod and used with permission.

The animation that shipped during development was borrowed from Climbing
(ESPless) as a placeholder. It is no longer present.

## License

GPL-3.0. See `LICENSE`.
