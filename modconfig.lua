return {
    image = "data/textures/MCM_Cosmic_Vault.png",
    pages = {
        {
            title = "General",
            options = {
                {
                    key = "debugEnabled",
                    type = "bool",
                    title = "Enable Cosmic Debug Logs",
                    description = "Master toggle for Cosmic series debug logging output. (Default: true)",
                    default = true,
                },
                {
                    key = "debugPrefix",
                    type = "string",
                    title = "Debug Prefix",
                    description = "Prefix used for Cosmic series debug messages. (Default: '[Cosmic]' | Max Length: 32 chars)",
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
                    description = "Enables additional diagnostics helpers for Cosmic series mods. (Default: true)",
                    default = true,
                },
                {
                    key = "diagnosticsInterval",
                    type = "number",
                    title = "Diagnostics Interval (s)",
                    description = "How often background diagnostics snapshots run when used by dependent mods. (Default: 300s / 5m | Min: 10s | Max: 3600s / 1h)",
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
                    description = "Enforces stricter validation in shared Cosmic Vault framework utilities. (Default: true)",
                    default = true,
                },
                {
                    key = "enableCompatLayer",
                    type = "bool",
                    title = "Enable Compatibility Layer",
                    description = "Enables helper compatibility wrappers for current and future Cosmic series mods. (Default: true)",
                    default = true,
                },
            },
        },
    },
}
