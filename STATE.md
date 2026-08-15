# Mantle — where things stand

Written so the state survives a compacted context or a fresh session. Read this
and RESEARCH.md and you are caught up.

## Shipped

`Mantle-v45.zip` on the share, alongside `PlayerPhysics-v33.zip`. **Both are
needed** -- the trigger reads `PPSpeedRatio`, `PPAirTime` and `PPInAir`, and an
older Player Physics fails to compile the script at all, which kills the whole
mod rather than one feature.

Mantle has **no DLL**. It is `ln_Mantle.txt`, `MainLoop.gek`, three
animations and ten sounds. The plugin it started as was deleted once the detection moved
into Player Physics, which is the only code that can see both the speed the
engine asked for and the distance actually covered.

## What works

- Trigger: hold forward and activate (control **5**, not 12 -- Climbing's
  comment is wrong). Jump is no longer an activate key.
- **No wait.** In keyless mode `PPSpeedRatio` (moved over asked-for, 0 to 1)
  must be under 0.25. This replaces `PPBlockedTime`, which needed history before
  it could answer and so cost three frames of feeling dead. Same test as
  SkyParkour's Smart Climb, which refuses above a fifth of commanded speed.
  `PPBlockedTime` is still exported; nothing uses it.
- **A key press excuses the ratio test.** Waiting to be stopped can only find
  obstacles that stop you, and low ones do not -- the character controller steps
  over them and the ratio never falls. That, and not the test that picks it, is
  why the low animation never once played. A press says what the stall was being
  used to infer. The ratio stays in force for keyless mode, where nothing else
  separates climbing a kerb from walking over one.
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
- **The downward rays reach past the bottom of the window**, and the window is
  applied afterwards as a test. Three answers instead of two: a surface worth
  climbing, a surface too low to bother with but real and measurable, and a
  genuine drop.
  Both earlier shapes were worse. 200 unit rays always found something, so a
  miss and a floor reading were the same answer. Bounding the ray to the
  climbable range fixed that and broke the step test (below): ground a unit
  under the window came back as a miss, a miss read as ground level, and the
  first stop to enter the window always showed a step of the window's own depth
  out of nothing.
- **Depth is measured**: how many stops came back at the height that won, times
  the 4 unit spacing.
  Counted against the winner, not as a running streak. The streak version was
  wrong and reported a depth of one for everything -- on a flat top the winner
  is the *first* stop to reach that height, so the streak at the moment of
  winning is always one, and every stop afterwards matched without beating it
  and went uncounted.
  Only the low band is gated on it (see below); thin fences are a single sample
  too, and they are the case that finally started working.
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
  **Forward is driven only from the ground.** In the air the player is already
  travelling, so driving the position does not add movement, it replaces it: a
  jump aimed at the next ledge was being rewritten into a short hop to twenty
  units past the near edge, which lands short and falls. Up there the climb only
  lifts and the player's own arc finishes the job.
- Physics stood down via `PPBeginInteraction` **on the ground only**; master
  switch `*_Mantle_Yield`.
  In the air it is the wrong thing to do, and not because of the movement model:
  Player Physics runs the player at roughly double gravity, so standing it down
  swaps that to the engine's value for the length of the climb and back again --
  a discontinuity dropped into the middle of the jump arc. Rooting is re-armed
  exactly while the idle plays, and the faked fall distance goes with it.
- **The view dips and comes back; turning is untouched.** `*_Mantle_CamDur`
  (0.9 s) on its own clock, `*_Mantle_CamNudge` (16 degrees, scaled by how far
  the climb goes), on a half sine so it returns on its own with no restore step.
  Last frame's contribution is subtracted before this frame's is worked out, so
  what sits underneath is always the player's own aim and nothing accumulates.
  In FNV **X is pitch and Z is yaw**. The dip on X is the wanted effect. Lagging
  Z was tried in v41 and removed: being able to turn while climbing is worth
  more than any weight added to it.
  Locking either axis is settled and wrong -- v29-v31 and v38-v39 both did, and
  a mouse that stops answering reads as a bug before it reads as a flourish.
  The load script still hands the looking control back, for saves made then.
- **Three animations**, chosen at the moment of the climb. Each is cloned onto
  its own throwaway form at load, so the choice is which form to hand
  `ForcePlayIdle` rather than a path swapped under time pressure.
  Sprint wins first -- it is a whole-body state and its animation is a running
  vault, right whatever the obstacle is. `*_EMSprint` is Enhanced Movement's own
  flag, read the same way by three other mods in this load order. Then height:
  below `*_Mantle_LowMax` (0.35 of player height) the obstacle is stepped over
  rather than hauled onto. Otherwise Base.
  A low climb additionally needs a **rise of 10 units onto the winning
  surface**, measured against the real ground one stop back -- the price of
  letting the key skip the stall test, which used to exclude sloping ground for
  free, since you are not stopped by a hill.
  Two wrong versions of that test first: a plateau at the top (a *gentle* slope
  has plenty of stops near its highest one, precisely because it is gentle), and
  the same rise measured against a window-bounded ray, which fabricated a step
  of ~18 units at the first stop to enter the window. Raising the threshold
  could not have fixed the second -- it would have had to pass 18 and take every
  real low ledge with it.
  There is **no weapon test**; it was dropped in v45 because the animations hide
  the weapon themselves. `GetWeaponType` 8 and 9 were the heavy pair, if it is
  ever wanted again.
  Animation folder names contain spaces, kept so a fresh export drops in
  unchanged. Suspect that first if one silently fails to play.
- **A random climb sound**, one of `*_Mantle_Sounds` (10) files at
  `Data\Sound\FX\STRADAT\climb_NN.wav`, played with JohnnyGuitar's
  `PlaySoundFromPath`.
  Not a text key in the animation: a key can name one sound per animation, and
  naming it means naming a form, which means an esp. Taking the file path
  directly keeps the mod esp-less and turns the choice into a number, so an
  eleventh file costs one line in the load script.
  All ten are normalised to **mono 44100 Hz 16-bit PCM** -- they arrived mixed
  44.1/48 kHz and mixed mono/stereo, which FNV handles inconsistently.
- A single `PushActorNoRagdoll` as the climb releases, `*_Mantle_Push` (40).
  The climb arrives on top carrying no velocity -- the trigger required a
  standstill and the drive moved positions, not speeds -- so without this the
  player stops dead up there. `PushActorNoRagdoll` and not `SetActorVelocity`
  because the heading convention is known from a working script and the velocity
  pair's scale is not, and a one-off shove is the case Player Physics' own
  knockback path is written for.

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

- **Depth is measured but nothing uses it.** It would give vault-through versus
  mantle-onto, and a check that there is anywhere to land.
- **Momentum through the climb.** `SetActorVelocity Z 0` on release forgets the
  fall the climb invented, but horizontal velocity is still whatever survives
  the `SetPos`. Carrying it properly means writing X/Y velocity every frame --
  and first establishing the getter/setter scale factor, see Hard-won facts.
- **Grabbing was tried and reverted** (v35, commit `fc0a3f4`). A second height
  band up to 1.15 of player height, entered only where the leg band found
  nothing, with the forward move delayed to `t^3` to read as hauling rather than
  stepping. It worked and did not help. If it comes back it should probably wait
  for a real hanging animation, since the thing it was missing was the hang.
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
  `(y, x)` and returns degrees. `fSin`, `fCos`, `fTan` also exist, in JIP.
- `reference.SetActorVelocity axis:X/Y/Z velocity:float`, and it applies **for
  one frame only** -- to hold a velocity you write it every frame.
  **The getter and setter do not appear to share a scale.** The setter is
  documented in units of 7 units per second; `GetActorVelocity` reads like raw
  units per second (HUD Inertia caps it at 1000, which would be meaningless on
  the other scale). Feeding one straight into the other would multiply the
  player's speed sevenfold. Establish the factor before moving any measured
  velocity through this pair -- a wrong guess launches the player rather than
  failing quietly.
- Signatures for all of the above came from the loose scripts under
  `/Volumes/Share/parkour/scripts`, which is faster and more reliable than
  geckwiki (which 403s).
- Player Physics does not call the original `MoveCharacter` once its physics
  take over, so nothing can chain onto that hook for the player.

## Debug workflow

Console output goes to a file via `SetConsoleOutputFilename`. Send it filtered:

    grep -a "Mantle:" <file> | tail -60

`PlayerPhysics.log` is small enough to send whole.
