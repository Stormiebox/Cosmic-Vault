return {
    image = "data/textures/icons/cosmicvault/MCM_Cosmic_Vault.png",
    pages = {
        {
            title = "General",
            options = {
                {
                    key = "debugEnabled",
                    type = "bool",
                    title = "Enable Cosmic Debug Logs",
                    description = "Master toggle for Cosmic series debug logging output.",
                    default = false,
                },
                {
                    key = "debugPrefix",
                    type = "string",
                    title = "Debug Prefix",
                    description = "Prefix used for Cosmic series debug messages.",
                    default = "[Cosmic]",
                    maxLength = 32,
                },
            },
        },
        {
            title = "Diagnostics",
            options = {
                {
                    key = "diagnosticsEnabled",
                    type = "bool",
                    title = "Enable Diagnostics",
                    description = "Enables additional diagnostics helpers for Cosmic series mods.",
                    default = true,
                },
                {
                    key = "diagnosticsInterval",
                    type = "number",
                    title = "Diagnostics Interval (s)",
                    description = "How often background diagnostics snapshots run when used by dependent mods.",
                    default = 300,
                    min = 10,
                    max = 3600,
                },
            },
        },
        {
            title = "Framework",
            options = {
                {
                    key = "enableFrameworkStrictMode",
                    type = "bool",
                    title = "Enable Framework Strict Mode",
                    description = "Enforces stricter validation in shared Cosmic Vault framework utilities.",
                    default = true,
                },
                {
                    key = "enableCompatLayer",
                    type = "bool",
                    title = "Enable Compatibility Layer",
                    description = "Enables helper compatibility wrappers for current and future Cosmic series mods.",
                    default = true,
                },
            },
        },
    },
}
