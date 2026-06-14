function infoCv_injectToCodex()
    Player():invokeFunction('ui/cosmiccodex', 'addCategory', 'cv_cat', 'Cosmic Vault'%_t, 'data/textures/icons/crate.png')

    Player():invokeFunction('ui/cosmiccodex', 'addChapter', 'cv_cat', 'cv_cat_c0', 'API Framework'%_t)
    
    Player():invokeFunction('ui/cosmiccodex', 'addArticle', 'cv_cat_c0', 'cv_cat_a0', 'What is Cosmic Vault?'%_t, 'Cosmic Vault is the central API framework that powers the entire Cosmic Mod Series. It is primarily a modder\'s resource, providing a massive library of high-performance tools to build complex mechanics without tanking server TPS or causing multiplayer desyncs.\n\nWhile you won\'t see many direct gameplay features from Cosmic Vault itself, it is the beating heart that makes Cosmic War, Cosmic Overhaul, and Cosmic Ascendancy possible.'%_t, '')
    
    Player():invokeFunction('ui/cosmiccodex', 'addArticle', 'cv_cat_c0', 'cv_cat_a1', 'For Server Admins'%_t, 'Cosmic Vault includes several background protection mechanics natively:\n\n- Highlander Shim Injection: Ensures all Cosmic mods can seamlessly share vanilla script hooks without breaking other mods.\n- Async Task Scheduler: Prevents the server from freezing during massive sector loops by yielding execution across multiple ticks.\n- Deterministic Generation: Synchronizes procedural generation arrays to eliminate the physics and desync crashes caused by standard math.random().'%_t, '')
    
    Player():invokeFunction('ui/cosmiccodex', 'addArticle', 'cv_cat_c0', 'cv_cat_a2', 'For Mod Developers'%_t, 'If you are a modder looking to hook into the Cosmic series, you can safely leverage the Vault\'s APIs.\n\nRead the full MODDER_GUIDE.md located in the Cosmic Vault mod directory for documentation on:\n- Player Settings Storage\n- Faction Index Registry\n- Cinematic UI Components\n- The Async Scheduler\n- Complex Entity Data Serialization\n- Arsenal Generation\n- Dynamic Invasion Scaling (cosmicvaultscaling.lua)\n- Market Economies and Diplomatic Reputation Wrappers'%_t, '')
end
