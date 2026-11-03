# Polish audit

Played from main `a71a4fc`. Clips are about 6–10 seconds, captured with `tools/record_movie.py`. Nothing in this branch is a fix.

## 1. The jumpship is a white lamp

The hull you built never reads in flight. Two engine blooms eat the nose, the wings, and the glossy white paint. Boost makes it worse: the ship is a blob in the middle of the frame.

Clip: `audit_flight.mp4`, `audit_thrust_outside.mp4`

Hurts: high

Fix: turn the engine glow down until the hull silhouette stays, and keep a dark rim on the white panels. The bloom can stay, just not as the whole ship.

Size: medium

## 2. Stars streak when you are only cruising

Ordinary flight already stretches the starfield into a radial pixel tunnel. The same noise fills the cockpit window during a burn, so the boost streaks do not feel special. They look like static snow.

Clip: `audit_flight.mp4`, `audit_thrust_outside.mp4`, `audit_thrust_inside.mp4`

Hurts: high

Fix: streak only while boosting, and draw fewer, longer lines instead of moving every star.

Size: medium

## 3. The bay window is a sun, bands, and a floating hotbar

The open shuttle bay should be the best view of Mina. Instead the sun blows out the top of the door, the opening is cut by horizontal bands, and the inventory hotbar sits in the middle of the glass like a HUD. That fights the rule that the ship computer is the only screen.

Clip: `audit_bay.mp4`

Hurts: high

Fix: pull the sun's bloom down in the cabin, soften or remove the banding on the door glass, and hang the hotbar on the locker wall instead of over the opening.

Size: medium

## 4. CRT text falls apart when you are not square to it

From the aisle the green readouts turn into broken glyphs, and the sun through the forward window washes the glass. You cannot trust the screens while you walk.

Clip: `audit_walk.mp4`

Hurts: high

Fix: keep screen text crisp at an angle (a flat unshaded pass, or a font that survives the CRT shader), and keep that sun out of the aisle windows.

Size: medium

## 5. Saving writes over the readout

`SHIP STATE SAVED` lands on top of `THR 0.00`. The center screen is doing two jobs in the same pixels, so the one confirmation you get is half a sentence.

Clip: `audit_save.mp4`

Hurts: med

Fix: keep the readout in the top half and type the reply on a clear line under it. Same treatment for every command, not only SAVE.

Size: small

## 6. The title never shows your ship

The planet card looks finished. The jumpship is not in the shot, and the only prompt is a tiny "CLICK TO BEGIN" even though any key also starts.

Clip: `audit_title.mp4`

Hurts: med

Fix: park the ship in the lower corner of the title frame, and change the prompt to a key or a click.

Size: small

## 7. Standing up is a camera cut

E does leave the seat, then you are simply in the aisle. There is no rise from the chair, so the action feels like a swap. The walk that follows is where you land.

Clip: `audit_walk.mp4`

Hurts: med

Fix: a short stand, about half a second, from the seated eyes up to the aisle.

Size: medium

## 8. The ship computer is silent and blunt

The center glass shows `NEW LOG` instead of a prompt, the cursor is a thin underscore, a wrong command is only `?`, and nothing clicks. Output appears all at once.

Clip: `audit_crt.mp4`

Hurts: med

Fix: a short boot, soft key clicks, history, tab completion, a block cursor, a suggested command on a typo, and output that types on. That work is the terminal polish pass, not this audit.

Size: medium

## 9. Orbit is the best view, and the prompt is still lost

Mina sits in the window and `AUTOPILOT: ORBIT` is readable. The center screen then repeats the side readout, and the command line is a stray mark under the numbers.

Clip: `audit_orbit.mp4`

Hurts: low

Fix: one status line on the center glass, readout on the side screens, prompt left clear.

Size: small

## 10. The walk barely bobs

Head bob is so small the aisle feels like a slide. Combined with the sun in the window, walking does not yet feel like boots on a deck.

Clip: `audit_walk.mp4`

Hurts: low

Fix: raise `FlightProfile.BOB` a little and give the footstep a touch more weight.

Size: small
