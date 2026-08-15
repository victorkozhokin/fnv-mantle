# Mantling in Fallout New Vegas — what is actually available

Notes taken before writing any of this plugin, from reading two working mods and
searching the xNVSE source. Recorded because the last project lost six builds to
a premise nobody had checked.

## The short version

**JIP LN has ray casts.** They are absent from xNVSE and unused by every mod in
this load order, which is why the first pass through the scripts missed them --
but they are right there in `jip_nvse.dll`:

| function | alias |
| --- | --- |
| `GetRayCastPos` | |
| `GetRayCastRef` | |
| `GetRayCastMaterial` | |
| `GetPointRayCastPos` | |
| `GetP2PRayCastRange` | |
| `GetCollisionNodes` | |

Also present and possibly useful: `GetCollisionObjProperty` / `GetCollProp`,
`GetCollisionObjLayerType` / `GetCollLayer`, `ToggleObjectCollision` (SUP NVSE).

Signatures, from GECKWiki:

```
(distance:float) GetP2PRayCastRange
    originX:float originY:float originZ:float
    targetX:float targetY:float targetZ:float
    collisionFlag:int

(success:bool) GetPointRayCastPos
    originX:float originY:float originZ:float
    rotationX:float rotationY:float
    xOut:ScriptVar yOut:ScriptVar zOut:ScriptVar
    collisionFlag:int maxRange:float
```

The first is the one this plugin mostly wants: give it two points and it returns
how far along the line the geometry is. Measuring a ledge is exactly that -- cast
from a known point to another known point and read the distance back.

The second aims by rotation instead and writes the hit position into three
variables, which suits probing along the player's facing. Which of its two
rotation arguments is pitch and which is yaw the wiki does not say; the example
passes `0 90`, so it needs one console test to settle.

`collisionFlag` is documented on the Collision Flags page as a table of layer
sets. **6** is the projectile layers, and it is what both wiki examples use --
a sane default here too, since it is what has to be solid for a bullet and so
roughly what has to be solid for a knee.

This changes the design from the one the shipped climbing mod uses. The
obstacle can be measured before the player is moved.

## Climbing (ESPless) — the mod that already does this

`NVSE/user_defined_functions/Climbing/MainLoop.gek`, run at 90 Hz by
`CallWhilePerSeconds 0.011`.

**Trigger.** Hold forward *and* activate. Not automatic — which sidesteps the
whole false-positive problem: no need to tell a fence from an NPC, a doorway or
a slope, because the player has said what they want.

**Blocked test.** It samples the player's XY position across two ticks and
compares the delta against `fMovementThreshold` (3.5 units). Pressing forward
and not moving means something is in the way. Crude, and 3.5 units of slack is
generous, but it needs nothing the engine does not already offer.

**Contact test.** `player.GetContactRefs` returns the refs the player is
touching; an empty array bails out. This is the closest thing to a collision
query available from script.

**The climb itself.**

```
set fTargetZ to fCurrentZ + fClimbSpeed     ; 2.5 units per tick
player.SetPos Z fTargetZ
```

Straight up, no forward component, ~225 units/second. The character controller
does not fight it, which is the important discovery: `SetPos Z` sticks during
gameplay. Duration is capped by `fMaxClimbTime`, itself scaled by Agility --
around 0.6 s at AG 5, so roughly 135 units of lift before it gives up.

Forward motion over the ledge is left to the player still holding the key.

**Animation, with no esp.** Worth stealing wholesale:

```
ref rPUIdle = TempCloneForm LooseCallForHelpA
SetIdleAnimPath rPUIdle "characters\_male\idleanims\Climbing\SpecialIdle_ClimbUp.kf"
player.ForcePlayIdle rPUIdle
```

A throwaway clone of an existing idle form, repointed at a new kf. Same trick
for the sound with `TempCloneForm ITMKeyDown` + `SetSoundSourceFile`. First
person only, behind a 5 second cooldown, and only once at least 10 units have
been climbed so it does not fire on a kerb.

**Guards it applies:** not while jumping (`GetAnimAction == 2`), not with a
crippled leg, not while crouching, not while over-encumbered, not while dead.

## FPS Lowering Weapons — not a ray cast

Checked because it looked like one. It is not: `FPSTracking` walks
`GetActorsByProcessingLevel`, filters by heading angle and distance, and calls
`Player.GetLineOfSight rActor`. Line of sight to *actors*, plus cone maths. No
geometry probing anywhere.

Its script sources were readable straight out of the esp: SCPT records keep the
original text in their `SCTX` subrecord alongside the compiled `SCDA`, so any
esp can be read this way without the GECK.

## What this plugin can do that a script cannot

The script version is limited in two ways worth fixing:

1. **Its blocked test is a guess.** We sit inside `MoveCharacter` and write the
   player's velocity ourselves. Comparing what we asked for against what the
   player actually achieved is a direct answer to "did we hit something", with
   no threshold to tune and no 22 ms sampling window.

2. **It fights the movement code.** Player Physics applies friction and
   acceleration every frame, including during a climb. The suppression built for
   interaction animations already solves this and can be reused.

Smoothness is a third, smaller win: per-frame position instead of 90 Hz ticks.

## Design for the first version

Climbing's approach is not worth copying. It lifts at a fixed speed until a
timer expires, having never looked at what it is climbing -- so a kerb and a
fence get the same motion, and whether either works is down to how the timer
happens to land. With ray casts available that is simply unnecessary.

**Measure first, then move.** The obstacle's height decides the motion instead
of a constant deciding it.

1. **Intent.** Manual, as in Climbing: forward held against something. This is
   the one part of their design worth keeping, because it removes every
   false-positive question at a stroke -- no need to tell a fence from an NPC or
   a doorway when the player has said what they want.
2. **Blocked.** From the velocity discrepancy, not position sampling. We write
   the velocity, so we can compare what was asked for against what was covered.
3. **Probe.** Only now, and only because being blocked is rare -- a cast per
   frame would have been unaffordable, a cast per attempt costs nothing.
   - a downward cast from above and slightly in front finds **the top**, which
     is the height H everything else is derived from;
   - a forward cast just above that top finds **the depth**: a thin rail to
     vault over, or a wide ledge to end up standing on;
   - a short upward cast checks **headroom**, so the player is not launched into
     a low ceiling.
4. **Scale by H, continuously.** Not buckets: a 0.2 obstacle and a 0.3 one
   should visibly differ, so the height of the hop is a function of what was
   measured rather than a class it fell into. The only hard edges are at the
   ends -- below the controller's own step height the engine already handles it
   and we stay out; above the limit we refuse rather than produce something
   that looks broken.
5. **Express the limits as fractions of the player's own height**, not in game
   units. Roughly half the character's height is the ceiling for a vault. Taking
   it from `GetObjectDimensions Z` rather than hardcoding ~64 units means it
   holds for any race, and for whatever a body mod has done to the player.
6. **Generate the motion from H.** Apex a little above the measured top,
   forward distance from the measured depth, duration scaled to the height.
   Nothing is a constant that the world has to happen to suit.

The timer stops being how a climb ends and becomes only a safety net.

Physics is suspended for the duration through the interaction path already built
into Player Physics. Animation and sound come from the script layer using the
TempCloneForm trick, chosen by the same classification -- vault and mantle are
different animations.

The probing lives in the script layer, where JIP's functions are. The DLL asks
for a measurement when it wants one and gets back three numbers. That is the
split already proven on the interaction restrict, and it keeps every per-frame
cost in C++.

## Animation

`meshes/characters/_male/idleanims/Mantle/SpecialIdle_ClimbUp.kf` is Climbing's
own animation, borrowed as a placeholder so the mechanic can be built and felt
before anything final exists. **It is not ours to ship.** It comes out the
moment a replacement arrives, and nothing goes public with it in place.

One animation is also not enough for the design above: a hop over a rail and a
pull onto a ledge are different movements, and with the height scaling
continuously the animation wants to at least distinguish the two ends.

## Open questions

- Which of `GetPointRayCastPos`'s two rotation arguments is pitch and which is
  yaw. One console call settles it.
- Does `SetPos` fight the Havok controller at per-frame rates? Climbing gets
  away with 90 Hz, but it only ever moves up.
- Third person needs root motion and is out of scope; first person only.
