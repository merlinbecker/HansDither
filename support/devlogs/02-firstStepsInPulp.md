---
publish_url: https://merlinbecker.itch.io/hans-dither/devlog/1499252/first-steps-in-pulp
publish_date: 2026-04-24
---

# first steps in pulp

I decided to develop [**Hans-Dither**](https://github.com/merlinbecker/HansDither) using [Pulp](https://play.date/pulp/) for the Playdate. Getting started was surprisingly easy: the editor is intuitive, and you can see results quickly. Pulp operates on a room-based concept, where a room is essentially a game board where you can place objects and use a standard player workflow. The built-in scripting language, **[Pulpscript](https://play.date/pulp/docs/pulpscript/)**, is quite limited—dynamic variables or comparisons between variables aren't possible—but that's what makes the challenge interesting.

For **Hans-Dither**, I created two rooms: a start screen that also functions as a card, and a canvas area. The player acts as a brush. The A button places pixels or patterns, while the B button erases them. The crank is used to select patterns. By rotating the Playdate 90 degrees, you return to the menu, where you can toggle the grid, continue, or clear the canvas.

Development took about two weekends. Learning Pulpscript was the most time-consuming part, but the logic is straightforward: events are processed in entities like the player or room. Another advantage is that you can test everything in the browser at any time and generate a runnable build directly. The barrier to entry is extremely low since you don’t need a local development setup.

The sound functions are another plus. With basic knowledge of digital synthesis ([Attack, Decay, Release, Sustain](https://en.wikipedia.org/wiki/Envelope_(music))), you can quickly create different sounds. Reading through the [Pulp forums](https://devforum.play.date/) helped me find workarounds for dynamic variables, such as using string concatenation. This allows for randomizing tiles or sounds.

In conclusion, Pulp is ideal for quickly and easily getting into Playdate development. It made accessing Playdate programming much easier for me.