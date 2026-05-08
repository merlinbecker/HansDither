---
publish_url: https://merlinbecker.itch.io/hans-dither/devlog/1499252/first-steps-in-pulp
publish_date: 2026-04-24
---

# Switching to the Playdate Lua SDK

My first version of [Hans-Dither](https://github.com/merlinbecker/HansDither), built with [Pulp](https://play.date/pulp/), turned out so well and was so much fun to work on. Pulp is definitely powerful, but it has its limits. One major constraint I noticed with the pixel editor is that I can’t freely paint individual tiles—I’d have to predefine patterns instead. This limitation quickly became apparent while testing the tool, restricting my ability to create and design freely.

At first, I thought I could continue using Pulp, but because of this constraint, I decided to switch to the [Playdate SDK](https://sdk.play.date/3.0.5/Inside%20Playdate.html) and Lua for Hans-Dither. While I’ll still use Pulp for other games I have planned, Hans-Dither will require moving beyond Pulp’s scripting capabilities.

My goal is to be able to paint down to the pixel level and edit various tiles directly on the Playdate. This way, I can pre-design spaces for other games I plan to build in Pulp and test how everything fits together on the actual device.

That’s why I’m now working with the Lua SDK. I even managed to set up the Playdate SDK with Lua on my Steam Deck. It took some effort, but now I can compile smoothly.

However, the Playdate Simulator wouldn’t start on the Steam Deck because the `webkit2gtk-4.1` library was missing. To install it, you’ll need to run the following commands:

```bash
sudo steamos-readonly disable
sudo pacman-key --init
sudo pacman-key --populate archlinux holo
sudo pacman -S webkit2gtk-4.1
```

After that, the Playdate Simulator runs, and you’re good to go. Keep in mind that you might need to repeat this installation after every SteamOS update.

I’m using VSCode with the [Playdate extension](https://marketplace.visualstudio.com/items?itemName=Orta.playdate), which allows me to open the simulator and program efficiently. Now, I’m ready to dive in!