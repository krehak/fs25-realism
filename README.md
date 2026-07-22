# Realism — Farming Simulator 25

A script-only realism mod that strips away arcade conveniences and forces you to live with the consequences of farm life. No new vehicles, no new buildings, no textures — just gameplay changes that make *Farming Simulator 25* feel like real work.

## Download & install

1.  Download `FS25_Realism.zip` from the [**latest release**](https://github.com/krehak/fs25-realism/releases/latest).
2.  Put the zip in your FS25 mods folder:
    -   **Windows:** `Documents\My Games\FarmingSimulator2025\mods\`
    -   **macOS:** `~/Library/Application Support/FarmingSimulator2025/mods/`
3.  Enable **Realism** in the mod list when you start or load a save.

Singleplayer and multiplayer are both supported. In multiplayer, every player needs the mod installed.

## Features

-   **Realism intro (new games)** — on the first load of a brand-new save, a short intro dialog explains the rules you signed up for. You build your farm from there, the hard way.

-   **No teleporting** — `Tab` / `Shift+Tab` no longer switch between vehicles, you can't jump into a vehicle picked from the map unless you're standing next to it, and the map's "Visit" / "Go To" for fields and buildings won't teleport you. Walk up and press `E` as normal. Plan your routes and park sensibly.

-   **Seasonal greenhouses** — greenhouse output scales with the time of year and the weather instead of running at a constant rate:
    -   Summer 100%, Spring / Fall 75%, Winter 50%
    -   Weather on top: sunny +20%, rain −10%, snow −30%, hail −40%

    Plan your winter cash flow accordingly.

-   **Inflation** — every year a rate between **1.5% and 5.5%** is set and held for that whole year, compounding across years. It applies to *both* buying and selling: inputs, fuel and machinery get pricier, but crops and goods are worth more too — so you can invest by storing crops and selling them later at the higher, inflated price. The current year's rate is announced on screen.

-   **Store-only production** — production buildings can no longer auto-sell or auto-distribute. Every output is forced to "store" mode and piles up in the building's storage; to turn it into money you drive a trailer over, load it, and haul it to a sell point or another production yourself.

-   **Bulk trade bonuses** — moving goods in volume pays off, like a real wholesale deal:
    -   **Selling:** +1% at 25,000 L, ramping to **+10%** at 100,000 L or more.
    -   **Buying** (fertilizer, lime, seeds, herbicide, fuel): −1% at 1,000 L, ramping to **−8%** at 10,000 L or more.

    Bonuses accumulate per station and fill type over one continuous deal.

-   **Balancer (locked realism settings)** — realism-critical settings can't be softened. Economy difficulty is forced to Normal (no Easy), and traffic, seasonal growth, snow, crop destruction, periodical plowing, required lime, weeds and disasters are all forced on — change them in the menu and they revert within seconds. AI helpers also never auto-buy fuel, seeds, fertilizer or manure/slurry; you refill their vehicles yourself. **Field stones** are the exception: they're turned *off* by default when you start a new game, but you're free to switch them back on and they'll stay on.

-   **AI crop damage** — hired workers no longer get a free pass over your crops. An AI vehicle running the wrong (non row-crop) tyres flattens crops and leaves tracks just like you do — so tyre choice matters for helpers too.

-   **Chainsaw stump removal** — no more permanent stumps littering your forest. After felling a tree, just hold the running chainsaw into the leftover stump — anywhere on it, no need to line up a green cut ring — and it's ground away. No expensive stump grinder needed.

-   **Log weight in multiplayer** — the game only knows a log's mass on the server, so forestry info mods hide the weight from everyone who isn't the host. Realism syncs each wood species' density from the server to all clients and shows a **Mass** line in the log info box for joined players too — no more guessing how heavy a log is.

More realism features will be added in future updates, each as a self-contained module.

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
