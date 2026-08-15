# SkyParkour NG — what it does and what of it we can use

Source read: <https://github.com/Tsptds/skyrim-SkyParkourNG>, branch `v3`, mainly
`src/Parkouring.cpp` and `src/Util/ParkourUtility.cpp`. The shipped mod also
carries a full 23 MB PDB, which is how the module list was found before the repo
turned up.

Skyrim, so some of this cannot cross over. Noted where that is the case.

## The architecture, and the part that surprised me

**The plugin never moves the player.** `ParkourReadyRun` writes the ledge type
into an animation graph variable, computes a start position, and fires
`NotifyAnimationGraph`. That is the whole of it. The animation does the moving,
by root motion.

Two lines say this was arrived at rather than assumed:

    // RE::hkVector4 hkPos = nipoint_to_hkvector(startPos);
    // ctrl->SetPositionImpl(hkPos, true, false);

and in `HavokHandler.hpp`, the character-state hook that would let them drive the
climb through Havok:

    // res &= climbing::InstallHook::Update();

Both written, both switched off. They compute `startPos` and then do not use it.

We move the player with `SetPos Z` on an eased curve. That is the thing they
tried and abandoned. Whether the same conclusion holds for us is open --
FNV has no behaviour graph and no Nemesis, and whether a `ForcePlayIdle` special
idle applies root translation to the player is a question nobody here has
answered yet. Worth answering before building anything else on `SetPos`.

## Their ledge search, against ours

Same shape as ours -- rays forward to find the face, rays down to find the top --
with six differences that are all worth having.

**The forward ray starts at the top of the range, not the bottom.**
`fwdRayStart = playerPos + (0, 0, maxLedgeHeight)`. Ours scans upward from the
ankles looking for the first face. Theirs starts above everything climbable and
sweeps outward.

**The forward loop grows the ray's length, and a hit means skip.**

    const auto curFwdProbeLen = fwdCheckStep * i;
    RayCastResult fwdRay = RayCast(fwdRayStart, actorDirFlat, curFwdProbeLen, ...);
    if (fwdRay.distance < curFwdProbeLen) continue;

They are not looking for the obstacle with this ray, they are looking for *clear
air* at a given distance, and only then dropping a ray down from it. Inverted
from ours, and it removes the whole problem of choosing an offset past the face.

**The down ray is bounded to the valid window.** Length is
`maxLedgeHeight - minLedgeHeight`, so it physically cannot reach the floor. This
is the direct fix for the thing that cost us a whole evening: our down casts run
200 units, always find the ground, and report a height of zero -- which reads
identically to finding nothing. Bound the ray and a miss is a real miss.

**All hits are considered, not the first.** The cast returns
`hkInplaceArray<hkpWorldRayCastOutput, 8>` and they walk it, taking the first hit
whose collision layer is not excluded. Their own comment:

> There is no one solution fits all collision layer mask for raycast, so v3.5.0
> iterates over all hits for climb and filters their layers

JIP gives us one hit and no layer, so we cannot copy this. It does explain a
class of failure we have seen and could not name.

**The surface normal decides whether a top is a top.**

    if (normalZ < minLedgeFlatness) continue;

No normals from JIP either. Two down rays a few units apart, comparing Z, is the
poor man's version and is worth trying.

**Candidates must climb.** `lastZ` starts at `minLedgeHeight` and every accepted
candidate must be higher than the previous one, commented as preventing a grab
through an obstruction.

Plus: reject if the down ray travelled less than 10 units; reject by form type
("DON'T CLIMB ON DOORS FFS"); headroom rays on the left and right rather than one
up the middle.

## The obstruction check, which is cleverer than it looks

From a point 15 units back from the ledge and 5 above it, they cast forward. If
that passes, they cast a second ray along the *negated surface normal* of the
first hit, flattened:

> 2 rays. if 1 distance is too low, not valid. if 1 passes, cast another ray with
> the ledge normal obtained from 1. this prevents extending the distance by
> looking slightly sideways

Approaching a wall at an angle makes a forward ray measure a longer distance than
the wall is deep. Casting the second ray perpendicular to the surface instead of
along the player's facing takes the player's approach angle out of the answer.
We have hit exactly this and treated it as noise.

## The trigger, and why ours is slower than it needs to be

They never wait. They measure velocity as a ratio:

    float GetRelativeVelocityToMT(actor) {
        return GetCharForwardVelocity(actor) / actor->DoGetMovementSpeed();
    }

and then

    /* Smart Climb */   if (relativeVel > 0.2f) return false;

"Only climb when nearly stopped" -- the same intent as our `PPBlockedTime`, with
no accumulation. Available on the first frame, where ours needs 0.05 s of history
before it can say anything.

**Player Physics already computes both halves of this.** `wanted` and `moved` sit
next to each other in `hook_MoveCharacter`; the blocked timer is built from them
and then throws the ratio away. Exposing `PPSpeedRatio` alongside `PPBlockedTime`
is a few lines and removes the last delay from the trigger.

The same ratio is used a second way, which we have nothing like: in
`StepsExtraChecks` the minimum ledge height is *scaled by it*, so a running
player steps over larger obstacles and stops tripping on small ones.

And for the airborne case:

    const auto fallTime = player->GetCharController()->fallTime;
    const bool considerGrounded = fallTime < 0.17f;  // Delay grabbing immediately after jumping

A grab is refused for the first 0.17 s off the ground. Ours fires the moment
`PPInAir` goes true, which is the moment of the jump, when the player is still at
ankle height and nothing is in reach.

## Smaller things worth stealing

- Height **bands** with their own checks: Highest / High / Medium / Low /
  StepHigh / StepLow / Grab. All limits multiplied by the player's scale. We have
  one band and a fixed 128-unit fallback height.
- `CamLedgeAngleValid`: in third person, if camera yaw and body yaw differ by
  more than 0.4 rad, refuse -- because the ray goes where the body faces and the
  player is looking somewhere else.
- Other mods block parkour by setting a graph variable, listed in an ini. Same
  idea as our `PPBeginInteraction`, but discoverable and editable by users.
- Debug draws every ray in the world through TrueHUD's `DrawArrow`/`DrawLine`.
  We read numbers out of a log file. No FNV equivalent is known, but the gap in
  iteration speed between the two is enormous.

## Player Physics

Nothing here transfers except the velocity ratio. Our model is already a Quake
derivative by inheritance, and the reference implementations found -- QMovement
(a GoldSrc `pmove.c` port), q2unity, OpenGoldSrc -- are re-treads of what is
already in `UpdateVelocity`. The one genuinely useful document is
<https://adrianb.io/2015/02/14/bunnyhop.html>, which derives the dot-product
acceleration cap: the same mechanism behind `fAcceleration` setting both the
inertia and the top speed, which we worked out from behaviour rather than from
the maths.

For the hanging feature: <https://github.com/beatrate/LedgeDetector>, freeform
ledge detection for Unity, written against what Dying Light does. Handles tilted
ledges, which is the case our flatness test will not.
