local Intents = {}

Intents.Flags = {
    GUILDS                  = bit32.lshift(1, 0),
    GUILD_MEMBERS           = bit32.lshift(1, 1),
    GUILD_MODERATION        = bit32.lshift(1, 2),
    GUILD_EMOJIS            = bit32.lshift(1, 3),
    GUILD_INTEGRATIONS      = bit32.lshift(1, 4),
    GUILD_WEBHOOKS          = bit32.lshift(1, 5),
    GUILD_INVITES           = bit32.lshift(1, 6),
    GUILD_VOICE_STATES      = bit32.lshift(1, 7),
    GUILD_PRESENCES         = bit32.lshift(1, 8),
    GUILD_MESSAGES          = bit32.lshift(1, 9),
    GUILD_MESSAGE_REACTIONS = bit32.lshift(1, 10),
    GUILD_MESSAGE_TYPING    = bit32.lshift(1, 11),
    DIRECT_MESSAGES         = bit32.lshift(1, 12),
    DIRECT_MESSAGE_REACTIONS= bit32.lshift(1, 13),
    DIRECT_MESSAGE_TYPING   = bit32.lshift(1, 14),
}

function Intents.Combine(...: number)
    local final = 0
    for _, flag in ipairs({...}) do
        final += flag
    end
    return final
end

return Intents
