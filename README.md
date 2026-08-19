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

-   **No teleporting** — `Tab` / `Shift+Tab` no longer switch between vehicles, you can't jump into a vehicle picked from the map unless you're standing next to it, and the map's "Visit" / "Go To" won't teleport you to a field, a building or an **NPC**. Walk up and press `E` as normal. Plan your routes and park sensibly.

-   **Seasonal greenhouses** — greenhouse output scales with the time of year and the weather instead of running at a constant rate:
    -   Summer 100%, Spring / Fall 75%, Winter 50%
    -   Weather on top: sunny +20%, rain −10%, snow −30%, hail −40%

    Plan your winter cash flow accordingly.

-   **Inflation** — every year a rate between **1.5% and 5.5%** is set and held for that whole year, compounding across years. It applies to *both* buying and selling: inputs, fuel and machinery get pricier, but crops and goods are worth more too — so you can invest by storing crops and selling them later at the higher, inflated price. The current year's rate is announced on screen.

-   **Supply and demand** — a market driven by *rates*, the way a real one works. Every market good has a **demand rate** (how much money's worth the world absorbs each in-game month) and your farms feed it a **supply rate**. The price chases the ratio, losing a fixed **10 points every time supply doubles** past demand:

    | supply vs demand | price |
    | --- | --- |
    | at or under demand | **100%** |
    | 2× | 90% |
    | 4× | 80% |
    | 8× | 70% |
    | 16×+ | floor **55%** |

    A constant cost per doubling keeps the curve gentle right where farms actually live, instead of falling off a cliff the moment you tip past balance.

    **Selling less than the market wants is just normal trade, priced at 100%.** The premium above 100% isn't paid for being *small* — it's paid for being *absent*. A product only starts climbing after **three months with no sale at all**, then rises ~2 points a month to the 120% cap, and a single delivery drops it straight back to 100%:

    | | milk price |
    | --- | --- |
    | 5,000 L sold every month, forever | **100%** |
    | 50,000 L sold every month | 100% |
    | 200,000 L sold every month | 88% |
    | stop selling — after 3 months | 100.3% |
    | after 6 months | 104% |
    | after 12 months | 114% |
    | one delivery of 5,000 L after all that | **back to 100%** |

    So a smallholder shipping a trickle every month gets the normal price and never a bonus; the premium belongs to the product nobody is producing.

    Because both sides are rates, **selling the same amount every month does not let the price recover between deliveries** — a steady stream of lettuce holds lettuce down for as long as it keeps coming. It only climbs back when the flow slows or stops, and even then it takes months.

    **The market covers three product families and nothing else.** The goal is to blunt the handful of earners that scale without effort, not to price the whole economy — so each family's market is sized by how much *work* its money costs:

    | family | market | memory | why |
    | --- | --- | --- | --- |
    | **greenhouse produce** | 35,000/month | 3 months | plant once, add water, collect pallets forever — the easiest money in the game, so the tightest of the three |
    | **wood products** | 50,000/month | 3 months | real work: fell, delimb, haul, cut, chip |
    | **animal produce** | 100,000/month | 2 months | a herd is the most demanding thing on a farm — the most generous market |

    Wood products means **planks, long planks, beams and wood chips**. **Raw logs are not included** — they're worth little per litre and moving them is already the job. Animal produce means **milk, eggs, wool, honey and the dairy made from them** (butter, cheese, and so on).

    | | price |
    | --- | --- |
    | up to 9 greenhouses of one crop, sold monthly | **100%** |
    | 12 greenhouses | ~98% |
    | 18 greenhouses | ~92% |
    | **30 greenhouses** | **~84%** |
    | 60 greenhouses | ~74% |
    | planks/chips worth 50,000 a month | ~99% |
    | planks/chips worth 100,000 a month | ~89% |
    | planks/chips worth 400,000 a month | ~69% |
    | 200 cows → butter, sold monthly | **100%** |
    | animal produce worth 200,000 a month | ~88% |
    | animal produce worth 800,000 a month | ~68% |

    **Every individual product has its own market** — lettuce doesn't compete with tomatoes, planks don't compete with chips. Splitting production across several products keeps all of them near 100%. The feature punishes *monoculture*, not scale.

    **Field crops are not affected at all.** A silo holds grain indefinitely at no cost, so there's no glut to model — you just store it until you want the money. Wheat, barley, canola, maize and the rest always trade at exactly the price the game sets. So does every other good: bricks, bread, cans, flour, sugar, fabric. Untracked products never move in either direction, so the **scarcity premium is confined to those same three families** too.

    Greenhouse produce is detected from the greenhouse buildings actually on your map, so modded greenhouses and their fruit are covered without a list. Wood and animal produce are matched by name; anything a mod adds can be pulled in with a one-line `<products>` entry naming its class.

    **Hoarding doesn't beat the market.** The price drops as the load comes off the trailer, so sitting on a product until it drifts up to the scarcity premium and then dumping a year's stock into that high price doesn't work — the first litres fetch the premium, the rest don't.

    Everything is measured in in-game **months**, so the market feels identical whether a month is one day or ten. In multiplayer the whole server shares **one market** — the host owns it and syncs prices to everyone. You're notified when a product **you trade** gets flooded and when it recovers into demand again; goods you've never touched stay silent, so a map full of produce won't bury you in messages. Market state is saved with your savegame (`realismSupplyDemand.xml`). Tuning lives under `<supplyDemand>` in [`realism.xml`](#server-settings):

    ```xml
    <supplyDemand enabled="true"
                  minIndex="0.55" maxIndex="1.2"
                  oversupplyPointsPerDoubling="0.1"
                  scarcityOnsetMonths="3" scarcityPointsPerMonth="0.02"
                  priceDropHalfLifeMonths="0.5" priceRiseHalfLifeMonths="2"
                  notifications="true"
                  greenhouseDemandPerMonth="35000" greenhouseMemoryMonths="3"
                  woodDemandPerMonth="50000" woodMemoryMonths="3"
                  animalProductsDemandPerMonth="100000" animalProductsMemoryMonths="2">
        <products>
            <fillType name="LETTUCE" class="greenhouse" demandPerMonth="25000"/>
            <fillType name="ALPACAWOOL" class="animalProducts"/>
        </products>
        <excludedFillTypes/>
        <includedFillTypes/>
    </supplyDemand>
    ```

    Each family's **`…DemandPerMonth` is where it starts being nerfed** — sell more than that in one in-game month and the price falls, a tenth off per doubling. Raise it and that family tolerates more before anything moves. Being ordinary settings, they're listed by `rlSettings supplyDemand` and changed live with `rlSet`, taking effect on the next tick. `<products>` overrides a single fill type's class or rates.

-   **Store-only production** — production buildings can no longer auto-sell or auto-distribute. Every output is forced to "store" mode and piles up in the building's storage; to turn it into money you drive a trailer over, load it, and haul it to a sell point or another production yourself.

    **Closed systems are exempt.** Products no vehicle can ever carry — the base game biogas plant's methane and electricity, or the internal fill types of modular mods like *PlanET Modular BGA*, where each module feeds the next — stay freely configurable, because locking them would deadlock the chain instead of creating hauling work. An output is exempt when it's in no vehicle fill type category, isn't a pallet, isn't traded on the price table, or the building has no storage for it. Overrides live under `<productionStoreOnly>` in [`realism.xml`](#server-settings):

    ```xml
    <productionStoreOnly enabled="true">
        <closedSystemMods>
            <mod name="FS25_PlanET_BGA_Modular"/>
        </closedSystemMods>
        <closedSystemFillTypes>
            <fillType name="RAWMETHANE"/>
        </closedSystemFillTypes>
        <storeOnlyFillTypes>
            <fillType name="SOMETHING_AUTODETECT_GOT_WRONG"/>
        </storeOnlyFillTypes>
    </productionStoreOnly>
    ```

    Flip `ProductionStoreOnly.DEBUG` in the script and rebuild to have every production point's outputs and their verdict written to `log.txt` on load.

-   **Bulk buying discounts** — buying in volume pays off, like a real wholesale deal. Filling up on fertilizer, lime, seeds, herbicide or fuel in bulk earns **−1% at 5,000 L, ramping to −10% at 35,000 L** or more, accumulating per station and fill type over one continuous refill.

    There's deliberately **no bulk bonus for selling**. What a load is worth is decided entirely by supply and demand — a volume bonus on top would reward exactly the dumping that's supposed to depress the price.

-   **Balancer (locked realism settings)** — realism-critical settings can't be softened. Economy difficulty is forced to Normal (no Easy), and traffic, seasonal growth, snow, crop destruction, periodical plowing, required lime, weeds and disasters are all forced on — change them in the menu and they revert within seconds. AI helpers also never auto-buy fuel, seeds, fertilizer or manure/slurry; you refill their vehicles yourself. **Field stones** are the exception: they're turned *off* by default when you start a new game, but you're free to switch them back on and they'll stay on.

-   **AI crop damage** — hired workers no longer get a free pass over your crops. An AI vehicle running the wrong (non row-crop) tyres flattens crops and leaves tracks just like you do — so tyre choice matters for helpers too.

-   **Chainsaw stump removal** — no more permanent stumps littering your forest. After felling a tree, just hold the running chainsaw into the leftover stump — anywhere on it, no need to line up a green cut ring — and it's ground away. No expensive stump grinder needed.

-   **Log weight in multiplayer** — the game only knows a log's mass on the server, so forestry info mods hide the weight from everyone who isn't the host. Realism syncs each wood species' density from the server to all clients and shows a **Mass** line in the log info box for joined players too — no more guessing how heavy a log is.

-   **Honest wood chips** — chipping a log no longer creates wood out of thin air. In the base game a tree worth 20,000 L of wood goes into the chipper and **60,000 L** of chips come out; the volume is simply tripled. Here a log yields its own volume in chips, **1 : 1**, so chipping is worth doing for what it actually is — turning awkward branches into something a trailer can carry and a heating plant will buy — instead of tripling your timber on the way out of the forest. This one has no switch: it's a fix for a base-game bug that mints wood out of nothing, not a difficulty dial.

More realism features will be added in future updates, each as a self-contained module.

## Server settings

### In the game

Every setting is in the game's own **Settings** page, grouped under `Realism — …` headings alongside the settings you already know. Only the host or an admin can change them; everyone else sees the rows greyed out, and switching a feature off greys out the rows beneath it. Values are selectors rather than free text, because that's all that page offers — the file below still takes any value in range.

### In the file

The same values live in **one** file, written into **the savegame's own folder** and created with commented defaults the first time that save runs:

-   **Windows:** `Documents\My Games\FarmingSimulator2025\savegame<N>\realism.xml`
-   **macOS:** `~/Library/Application Support/FarmingSimulator2025/savegame<N>/realism.xml`

Settings belong to the farm, not to the machine — two saves are two different farms, usually two different maps and two different sets of house rules, so retuning one never touches the other. If you already tuned the old shared file under `modSettings/FS25_Realism/`, it's read once on the way in and your values carry over.

In **multiplayer the server's copy is the only one that counts**. Joining players are sent its values, and any later change reaches them immediately — nobody reconnects to pick up a new setting.

If you already tuned the old `supplyDemand.xml` or `productionStoreOnly.xml`, your values are read once and carried into `realism.xml` the first time this version runs. The old files are then ignored and can be deleted.

### What's configurable

| feature | switch | values |
| --- | --- | --- |
| `disableTeleport` | `enabled` | — one switch: Tab, map-enter and map Visit are the same rule |
| `seasonalGreenhouse` | `enabled` | `spring` / `summer` / `fall` / `winterMultiplier`, `sun` / `cloud` / `rain` / `snow` / `hailMultiplier` |
| `supplyDemand` | `enabled` | `minIndex`, `maxIndex`, `oversupplyPointsPerDoubling`, `scarcityOnsetMonths`, `scarcityPointsPerMonth`, `priceDropHalfLifeMonths`, `priceRiseHalfLifeMonths`, `notifications`, **`greenhouse`/`wood`/`animalProductsDemandPerMonth`** (where each family starts being nerfed) and `…MemoryMonths`, plus the per-product overrides |
| `productionStoreOnly` | `enabled` | the three exemption lists |
| `bulkTrade` | `enabled` | `minLiters`, `maxLiters`, `minDiscount`, `maxDiscount` |
| `balancer` | `enabled` | every lock separately: `forceTraffic`, `forceSnow`, `forceCropDestruction`, `forcePeriodicalPlowing`, `forceWeeds`, `forceLimeRequired`, `forceSeasonalGrowth`, `forceNormalEconomy`, `forceDisasters`, `blockHelperAutoBuy` |
| `stumpCutter` | `enabled` | — |
| `aiCropDamage` | `enabled` | — |

Everything else is a constant in its own script: teleport distances, the stump grind time, the bulk-buy session gap, closed-system auto-detection, the new-game field-stone default and the debug reports. They set what the feature *is* rather than how hard it is, so they are not server knobs.

**Four features have no switch, on purpose** — turning them off would make this a different mod: the intro, inflation, honest wood chips and multiplayer log mass.

### Changing settings live

Settings can be changed from the console without restarting — the dedicated server's web console, or the in-game console of the host or an admin (master user):

| command | what it does |
| --- | --- |
| `rlSettings [feature]` | list every option and its current value |
| `rlSet <feature> <key> <value>` | change it until the server restarts |
| `rlSetSave <feature> <key> <value>` | change it *and* write it to `realism.xml` |
| `rlSettingsSave` | write all current values to the file |
| `rlSettingsReload` | re-read the file and apply it |

So when a player gets wedged in the terrain:

```
rlSet disableTeleport enabled false     ... they walk out ...
rlSet disableTeleport enabled true
```

A change requested by a player who isn't an admin is ignored.

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
