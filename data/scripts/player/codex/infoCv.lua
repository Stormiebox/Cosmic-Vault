function infoCv_injectToCodex()
    Player():invokeFunction('data/scripts/player/ui/cosmiccodex.lua', 'addCategory', 'cv_cat', 'Cosmic Vault'%_t, 'data/textures/icons/crate.png')

    Player():invokeFunction('data/scripts/player/ui/cosmiccodex.lua', 'addChapter', 'cv_cat', 'cv_cat_c0', 'API Framework'%_t)
    
    Player():invokeFunction('data/scripts/player/ui/cosmiccodex.lua', 'addArticle', 'cv_cat_c0', 'cv_cat_a0', 'What is Cosmic Vault?'%_t, 'Cosmic Vault is the central API framework that powers the entire Cosmic Mod Series. It is primarily a modder\'s resource, providing a massive library of high-performance tools to build complex mechanics without tanking server TPS or causing multiplayer desyncs.\n\nWhile you won\'t see many direct gameplay features from Cosmic Vault itself, it is the beating heart that makes Cosmic War, Cosmic Overhaul, and Cosmic Ascendancy possible.'%_t, '')
    
    Player():invokeFunction('data/scripts/player/ui/cosmiccodex.lua', 'addArticle', 'cv_cat_c0', 'cv_cat_a1', 'For Server Admins'%_t, 'Cosmic Vault includes several background protection mechanics natively:\n\n- Highlander Shim Injection: Ensures all Cosmic mods can seamlessly share vanilla script hooks without breaking other mods.\n- Async Task Scheduler: Prevents the server from freezing during massive sector loops by yielding execution across multiple ticks.\n- Deterministic Generation: Synchronizes procedural generation arrays to eliminate the physics and desync crashes caused by standard math.random().'%_t, '')
    
    Player():invokeFunction('data/scripts/player/ui/cosmiccodex.lua', 'addArticle', 'cv_cat_c0', 'cv_cat_a2', 'For Mod Developers'%_t, 'If you are a modder looking to hook into the Cosmic series, you can safely leverage the Vault\'s APIs.\n\nRead the full MODDER_GUIDE.md located in the Cosmic Vault mod directory for documentation on:\n- Player Settings Storage\n- Faction Index Registry\n- Cinematic UI Components\n- The Async Scheduler\n- Complex Entity Data Serialization\n- Arsenal Generation\n- Dynamic Invasion Scaling (cosmicvaultscaling.lua)\n- Market Economies and Diplomatic Reputation Wrappers'%_t, '')

    -- Shared Utility APIs
    Player():invokeFunction('data/scripts/player/ui/cosmiccodex.lua', 'addChapter', 'cv_cat', 'cv_cat_c1', 'Shared Utility APIs'%_t)
    Player():invokeFunction('data/scripts/player/ui/cosmiccodex.lua', 'addArticle', 'cv_cat_c1', 'cv_cat_a3', 'Galactic News & Dialogue API'%_t, 'Provides a unified framework for broadcasting global news events and managing complex, state-aware dialogue trees for NPCs without overriding vanilla dialogue files.'%_t, '')
    Player():invokeFunction('data/scripts/player/ui/cosmiccodex.lua', 'addArticle', 'cv_cat_c1', 'cv_cat_a4', 'Player Settings & Config API'%_t, 'A robust wrapper for saving client UI preferences and Mod Configuration Menu (MCM) settings safely without causing file I/O locks.'%_t, '')
    Player():invokeFunction('data/scripts/player/ui/cosmiccodex.lua', 'addArticle', 'cv_cat_c1', 'cv_cat_a5', 'Faction Index & Traits API'%_t, 'Tracks dynamic traits (Warmonger, Pacifist, etc) and identifies destroyed or dead empires across the galaxy safely.'%_t, '')
    Player():invokeFunction('data/scripts/player/ui/cosmiccodex.lua', 'addArticle', 'cv_cat_c1', 'cv_cat_a6', 'Territory & Anomalies API'%_t, 'Allows mods to seamlessly expand borders, override sector ownership, and spawn persistent spatial anomalies and data caches.'%_t, '')
    Player():invokeFunction('data/scripts/player/ui/cosmiccodex.lua', 'addArticle', 'cv_cat_c1', 'cv_cat_a7', 'Task Scheduler & Data Serialization'%_t, 'Provides standard coroutine wrappers to slice heavy tasks over multiple server ticks, alongside deep serializers to safely save complex nested Lua tables into entity data.'%_t, '')

    -- Vanilla+ Modding APIs
    Player():invokeFunction('data/scripts/player/ui/cosmiccodex.lua', 'addChapter', 'cv_cat', 'cv_cat_c2', 'Vanilla+ Modding APIs'%_t)
    Player():invokeFunction('data/scripts/player/ui/cosmiccodex.lua', 'addArticle', 'cv_cat_c2', 'cv_cat_a8', 'Arsenal & Goods API'%_t, 'Hooks to dynamically alter weapon properties, generate custom turrets, and inject new trade goods into the galaxy seamlessly.'%_t, '')
    Player():invokeFunction('data/scripts/player/ui/cosmiccodex.lua', 'addArticle', 'cv_cat_c2', 'cv_cat_a9', 'Economy & Mission API'%_t, 'Wrappers to inflict famine, trigger economic booms, and safely generate custom missions on the bulletin board.'%_t, '')
    Player():invokeFunction('data/scripts/player/ui/cosmiccodex.lua', 'addArticle', 'cv_cat_c2', 'cv_cat_a10', 'Encounter & Dynamic Scaling API'%_t, 'Standardized tools to spawn fleets that dynamically scale to match the player\'s current firepower and defensive rating.'%_t, '')
    Player():invokeFunction('data/scripts/player/ui/cosmiccodex.lua', 'addArticle', 'cv_cat_c2', 'cv_cat_a11', 'Buffs & Combat (DoT) API'%_t, 'Engine wrappers to apply permanent or temporary stat multipliers, weather immunities, and Damage-over-Time effects (like Dark Matter).'%_t, '')
    Player():invokeFunction('data/scripts/player/ui/cosmiccodex.lua', 'addArticle', 'cv_cat_c2', 'cv_cat_a12', 'Blueprint & Station Interaction API'%_t, 'Hooks to force factory production multipliers, alter station services, and spawn custom entities via templates.'%_t, '')

    -- Synergies & Security
    Player():invokeFunction('data/scripts/player/ui/cosmiccodex.lua', 'addChapter', 'cv_cat', 'cv_cat_c3', 'Synergies & Security'%_t)
    Player():invokeFunction('data/scripts/player/ui/cosmiccodex.lua', 'addArticle', 'cv_cat_c3', 'cv_cat_a13', 'Cosmic Series Synergy'%_t, 'Cosmic Vault acts as the communication bridge between Overhaul, Chronicles, War, and Ascendancy, allowing them to share state (like War Heat affecting Famine, or Faction Traits altering Dialogue) without explicitly depending on each other.'%_t, '')
    Player():invokeFunction('data/scripts/player/ui/cosmiccodex.lua', 'addArticle', 'cv_cat_c3', 'cv_cat_a14', 'Network Safety & Anti-Cheat'%_t, 'Vault completely replaces vanilla\'s math.random() calls with deterministic engine-safe variants to prevent multiplayer desyncs. Furthermore, it implements strict Callable Validation to block malicious clients from spoofing remote UI calls.'%_t, '')
    Player():invokeFunction('data/scripts/player/ui/cosmiccodex.lua', 'addArticle', 'cv_cat_c3', 'cv_cat_a15', 'Vanilla Bug Fixes'%_t, 'Includes engine-level fixes, such as patching the long-standing bug where Scout Missions would completely ignore Faction Headquarters sectors due to missing dialogue templates.'%_t, '')

end
