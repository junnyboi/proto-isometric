# Biome Weather Carrier Prompts

**Author:** Manus AI
**Generation format:** 10-second, landscape, 720p carrier clips with embedded environmental audio
**Shipping format:** 8.0-second mono 48 kHz PCM WAV after deterministic extraction and loop preparation

## Shared generation constraints

Every carrier uses a static wide environment reference for the matching biome. The camera remains locked and the environment remains present throughout. Visual motion is limited to airborne material and subtle surface response. Audio contains one continuous weather texture from the first frame to the last, with stable energy, no hard onset, and no final impact. There is **no dialogue, voice, narration, music, melody, rhythm, animal call, UI sound, weapon sound, or unrelated impact**.

## Desert — Glasswind Front

> A static wide isometric-game environment showcase of a sun-bleached desert plateau with scattered sandstone and pale dunes. Fine sand streams consistently across the ground from left to right; occasional broader gust ribbons pass through without changing the camera or introducing objects. Generate only a continuous dry desert crosswind with fine granular sand hiss and two soft, diffuse gust swells. Keep energy stable at the beginning and end, avoid thunder and sharp impacts, and include no animals, voices, or music.

## Oasis Wetlands — Reedrain Veil

> A static wide isometric-game environment showcase of shallow wetlands, dark mud, reeds, and still water channels under a soft gray sky. Light rain continues across the whole shot, with small water dimples and gentle reed movement; no creature enters or leaves. Generate only steady light rainfall on reeds and shallow water, scattered soft droplets, and a restrained damp breeze. Keep the start and end equally active, avoid thunder, frogs, birds, large splashes, voices, and music.

## Frozen Tundra — Whiteout Drift

> A static wide isometric-game environment showcase of blue-white tundra, low snow ridges, and translucent ice shelves. Fine snow crosses the view continuously in a broad diagonal drift while subtle crystal grains skim the surface; framing and terrain remain unchanged. Generate only a soft airy blizzard wash, fine ice-crystal skitter, and restrained snow gusts with stable energy. Avoid tonal howls, dramatic ice cracks, voices, animals, impacts, and music.

## Lava Fields — Ashfall Breath

> A static wide isometric-game environment showcase of black basalt shelves, glowing seams, cooling lava, and sparse embers beneath a smoky sky. Ash drifts steadily through the frame while faint heat shimmer and isolated embers remain subtle; no eruption or creature appears. Generate only ash-laden wind, a low diffuse geothermal rumble, and sparse quiet ember crackle. Keep the texture continuous and loop-friendly, avoid explosions, boss roars, rhythmic pulses, voices, and music.

## Deterministic extraction targets

| Runtime file | Carrier source | Duration | Integrated loudness | True-peak ceiling |
|---|---|---:|---:|---:|
| `weather_desert_glasswind.wav` | Glasswind Front | 8.000 s | −34 LUFS | −6 dBFS |
| `weather_wetland_reedrain.wav` | Reedrain Veil | 8.000 s | −34 LUFS | −6 dBFS |
| `weather_frozen_whiteout.wav` | Whiteout Drift | 8.000 s | −34 LUFS | −6 dBFS |
| `weather_volcanic_ashfall.wav` | Ashfall Breath | 8.000 s | −34 LUFS | −6 dBFS |
