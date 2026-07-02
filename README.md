# Realism — Farming Simulator 25

A script-only realism mod that removes arcade conveniences to make *Farming Simulator 25* more authentic and harder.

## Download & install

1.  Download `FS25_Realism.zip` from the [**latest release**](https://github.com/krehak/fs25-realism/releases/latest).
2.  Put the zip in your FS25 mods folder:
    -   **Windows:** `Documents\My Games\FarmingSimulator2025\mods\`
    -   **macOS:** `~/Library/Application Support/FarmingSimulator2025/mods/`
3.  Enable **Realism** in the mod list when you start or load a save.

Singleplayer and multiplayer are both supported. In multiplayer, every player needs the mod installed.

## Features

-   **Realism start (new games)** — on the first load of a new save, an intro explains the mod and you begin the hard way: $15,000, no farm or equipment, one free car, and you claim your first field for free by walking onto it. Existing saves are untouched.
-   **No teleporting** — `Tab` no longer switches vehicles, you can't jump into a vehicle from the map unless you're next to it, and the map's "Visit" for fields/buildings won't teleport you. Walk or drive everywhere.
-   **Seasonal greenhouses** — greenhouse output depends on the season and weather: full in summer, half in winter, with a bonus on sunny days and a penalty in rain/snow.
-   **Inflation** — every year a random rate (1.5–5.5%) is set and compounds. It applies to buying *and* selling, so prices drift up over time and you can invest by storing crops to sell later at higher prices.
-   **Store-only production** — production buildings can't auto-sell or auto-distribute. Goods pile up in storage and you haul them yourself.
-   **Bulk trade bonuses** — sell a lot at once for up to +10% extra money; buy fuel/fertilizer/seeds in bulk for up to -8% off.
-   **Balancer** — locks realism settings on: economy difficulty stays Normal (no Easy), and traffic, seasonal growth, snow, crop destruction, plowing, field stones, lime, weeds and disasters are forced on. AI helpers also never auto-buy fuel/seeds/fertilizer/manure — you refill them yourself.
-   **AI crop damage** — hired workers flatten crops and leave tracks with the wrong tyres, just like the player; tyre choice matters for helpers too.
-   **Sleep schedule** — you can only sleep from 21:00 (no skipping the day) *unless* you're already tired. After 16 hours awake you get tired (warning, fade-to-black, yawn) and can then sleep any time; sleeping under 6 hours leaves you sleep-deprived and still tired until you get a proper rest.
-   **Chainsaw stump removal** — cut into a leftover stump with the chainsaw and it's removed; clean up felled woodland with no special equipment.

More features will be added in future updates.

## Compatibility

Works with most other mods — Realism only changes behavior and doesn't modify vehicles, maps, or fill types.

## Credits

-   Author: **Patrik Krehák**

---

<details>
<summary>For developers</summary>

The mod source lives in [`src/`](src/) (zipped to `FS25_Realism.zip` on release). Each feature is a self-contained script in `src/scripts/`, registered via `Realism.registerFeature(name, module)` and listed in `src/modDesc.xml` under `<extraSourceFiles>`. Tunable constants sit at the top of each script.

**Release:** push a four-segment tag and the GitHub Action builds `FS25_Realism.zip` from `src/` and publishes a release.

```sh
git tag v1.0.0.0
git push origin v1.0.0.0
```

Or run **Actions → Release → Run workflow** and enter the version. Format is `X.Y.Z.W` (FS25 requirement).

</details>
