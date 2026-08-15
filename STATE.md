# Mantle — where things stand

Written so the state survives a compacted context or a fresh session. Read this
and RESEARCH.md and you are caught up.

## Shipped

`Mantle-v22.zip` on the share, alongside `PlayerPhysics-v27-trace.zip`. Both are
needed: the blocked detection lives in Player Physics, exposed as `PPBlockedTime`.

Mantle has **no DLL**. It is `ln_Mantle.txt`, `MainLoop.gek`, and a borrowed
animation. The plugin it started as was deleted once the detection moved.

## What works

- Trigger: hold forward and activate (control **5**, not 12 -- Climbing's
  comment is wrong). Jump is no longer an activate key.
- **No wait.** `PPSpeedRatio` (moved over asked-for, 0 to 1) must be under 0.25.
  This replaces `PPBlockedTime`, which needed history before it could answer and
  so cost three frames of feeling dead. Same test as SkyParkour's Smart Climb,
  which refuses to climb above a fifth of commanded speed.
  `PPBlockedTime` is still exported; nothing uses it.
- Airborne uses `PPAirTime >= 0.17` instead, since the ratio never drops in the
  air -- nothing stops a jump against a wall. The delay keeps a climb from being
  asked for at ankle height in the first moments of the jump.
- **Jump mantling.** Airborne (`PPInAir`) replaces the blocked test entirely, on
  the grounds that nothing stops a jump against a wall so the stall never
  arrives, and that leaving the ground at a wall is deliberate in a way that
  bumping into one is not. There is no second height path: every measurement is
  relative to where the player is *now*, so a jump moves the whole window up by
  the height of the jump. `0.70` was never "how tall an object may be", it is
  "how far above himself a person can haul themselves".
- A 0.15 s cooldown is charged on every *attempt*, so leaning on a wall does not
  cost thirty ray casts per frame.
- Blocked detection in Player Physics: compares `move.input` length against
  distance actually covered. Solid, confirmed over several sessions.
- **No face-finding.** One forward ray at the top of the window says how far
  ahead is clear; the sweep then walks outward along the facing every 4 units
  and drops a ray down at each stop. The downward rays do not care what is in
  front of the player, so the face never has to be located -- which removes the
  vertical scan, the offset-past-the-face, and every failure that came from
  choosing that offset. From SkyParkour, inverted.
- **The downward rays are bounded to the window**: they start at
  `startZ + maxHeight` and are `maxHeight - minHeight` long, so they cannot
  reach the floor. A hit is a ledge, a miss is a miss. The old 200 unit rays
  always found the ground and reported zero, which read exactly like finding
  nothing; that ambiguity cost an evening. The minimum-height test afterwards is
  gone -- the cast geometry enforces it.
- **Depth is measured**: consecutive stops at the same height are one surface,
  and the run length times the 4 unit spacing is how deep it is. Printed, not
  gated on -- thin fences are what finally started working and are exactly what
  a depth requirement would refuse.
- The facing vector comes from `fSin`/`fCos` of `GetAngle Z` and is the one
  piece built on an assumed convention. It is printed in the debug line for
  that reason.
- Motion: `SetPos` on all three axes, duration scaled by height. Up on
  `1-(1-t)^2`, forward on `t*t` -- a mantle is not a diagonal, the body goes up
  first and over second.
  Forward used to be left to the player's own walking, which contradicted the
  trigger: it insists the player is nearly stopped, and then the climb depended
  on a walk. Low crates hid it, since the feet finish 8 units clear and a step
  covers the rest; anything taller rose against the face and slid back down.
  The target is 20 units past the winning sample (which sits at the near edge,
  being the first stop to reach the top height), clamped to how far the
  head-height ray reached -- `SetPos` does not check collision, and that ray is
  the only evidence the space is free.
- Physics suppressed for the duration via `PPBeginInteraction`, switchable with
  `*_Mantle_Yield`. Tried both ways in play; no noticeable difference.
- The script does not touch the camera. It did in v29 to v31 -- looking control
  taken away, yaw frozen, pitch driven in an eased look-at at the ledge -- and
  it was removed on purpose. **Do not build it again in script.** Camera work
  during a climb belongs in the animation, where it is authored against the
  hands rather than guessed at from the geometry, and stays in step with them
  for free.
  The working version is kept in `attic/camera-lock.gek.txt` -- there is no git
  here, so removing it would have been losing it. The facts it established are
  under Hard-won facts below and are worth more than the code.

## Settled: the keyless trigger

**This one is right. Do not redesign it.** Tested and confirmed good in play;
turned off afterwards only so that a self-firing trigger does not muddy the
diagnosis of everything still being built. `*_Mantle_Auto` in `ln_Mantle.txt`,
set it to 1.

Held forward plus 0.05 s of being blocked, and nothing else. No key.

The numbers that felt right, and why they are not adjustable knobs:

- **0.05 s (three frames).** Not a filter -- the shortest run of frames from
  which "stopped against something" can be told apart from a landing or a
  scrape along a wall. Longer values were tried at 0.24 and 0.10 and both felt
  dead.
- **No separate, shorter wait for the key.** The key used to be faster because
  pressing it proved intent. It does not prove anything here: walking into
  geometry is nearly always accidental, so a filter for deliberate shoving has
  nobody standing on the far side of it. Both paths now use 0.05.
- **0.15 s cooldown per attempt**, not per success. Approaching a fence at an
  angle can miss on the first measurement and hit on the second, and this is
  the whole distance between the two.

What actually separates a climb from an accident is the measurement, not the
timing: a surface between 0.14 and 0.70 of player height with a full standing
height of clearance above it. Walls, posts and NPCs fail that on their own.

## Open

- **Height cutoff.** `0.70` of player height. Not the fence problem: `raw` came
  back equal to `height` every time, so the cap has never rejected anything.
  Two real causes were found instead, both in v23:
  the scan's loop guard compared an absolute world Z against a relative height,
  which killed it after one pass at ankle level; and it took the first hit going
  up, which is the shack wall seen through the gap under the fence.
- **Depth is not measured.** The fan already contains the answer -- which
  samples hit the top and which fell to the floor -- it is simply discarded.
  Would give: vault-through vs mantle-onto, animation choice, and a check that
  there is anywhere to land. Agreed to do after the height cutoff.
- Animation is Climbing's `SpecialIdle_ClimbUp.kf`, borrowed. Not ours to ship.
- Debug `PrintC` output is still on.

## Hard-won facts

- `.gek` files **must be CRLF** or JIP silently fails to precompile.
- No comment block before the variable declarations.
- ScriptVar out-parameters go in parentheses: `(fHitX)`.
- Negative literals as arguments go in parentheses: `(-90)`, or the parser reads
  subtraction.
- `fsqrt` is not available; multiplication only.
- Collision flag **19** is what works, not the documented 6.
- `Player.SetAngle X` does move the first person view; `SetAngleEx` is not
  needed for it. B42Interact drives the pitch this way.
- **Positive `GetAngle X` looks down.** B42Leaning hands the ray caster
  `-Player.GetAngle X`, and down is `-90` there.
- `DisablePlayerControls 0 0 0 0 1 0 0` -- the fifth flag is looking. Disabling
  looking does not stand Player Physics down; only the movement flag does that.
- `fATan2` and `V3Length` exist and are usable from a `.gek`. `fATan2` takes
  `(y, x)` and returns degrees.
- Signatures for all of the above came from the loose scripts under
  `/Volumes/Share/parkour/scripts`, which is faster and more reliable than
  geckwiki (which 403s).
- Player Physics does not call the original `MoveCharacter` once its physics
  take over, so nothing can chain onto that hook for the player.

## Debug workflow

Console output goes to a file via `SetConsoleOutputFilename`. Send it filtered:

    grep -a "Mantle:" <file> | tail -60

`PlayerPhysics.log` is small enough to send whole.
