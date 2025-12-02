local UsedLibraries = {
    { "Nactari", "1.0.0" },
    { "NactariDependants", "1.0.0" },
}

local InteractionType = {
    PING = 1,
    APPLICATION_COMMAND = 2,
    MESSAGE_COMPONENT = 3,
    APPLICATION_COMMAND_AUTOCOMPLETE = 4,
    MODAL_SUBMIT = 5
}

local Routes = {
    [InteractionType.APPLICATION_COMMAND] = "APPLICATION_COMMAND",
    [InteractionType.MESSAGE_COMPONENT] = "MESSAGE_COMPONENT",
    [InteractionType.APPLICATION_COMMAND_AUTOCOMPLETE] = "APPLICATION_COMMAND_AUTOCOMPLETE",
    [InteractionType.MODAL_SUBMIT] = "MODAL_SUBMIT",
}

export type Interactable<bot> = {
    RespondInteraction:(self:bot, Packet:any, Response:any) -> bot;

    Enums:{
        InteractionTypes:{
            PING:string;
            APPLICATION_COMMAND:string;
            MESSAGE_COMPONENT:string;
            APPLICATION_COMMAND_AUTOCOMPLETE:string;
            MODAL_SUBMIT:string
        }
    }
}


local InteratableEnums = {}

for i, _ in pairs(InteractionType) do
    InteratableEnums[i] = i
end

function ExposedMethods:RespondInteraction(Packet:any, Response:any)
    if not Packet or not Packet.id or not Packet.token then
        warn("Invalid interaction packet in RespondInteraction")
        return
    end

    return self:SendContext(
        "Post",
        `interactions/{Packet.id}/{Packet.token}/callback`,
        Response
    )
end

table.insert(CreationBoot, function(self)
    if not self.UsedLibraries then
        error("MISSING NACTARI DEPENDANTS")
    end

    self:On("Start", function()
        for _, dep in ipairs(UsedLibraries) do
            self:HasLibrary(dep)
        end
    end)
    :Catch(function(err)
        warn(err)
    end)

    self.Enums = self.Enums or {}

    self.Enums.InteractionTypes = InteratableEnums

    self:On("interaction_create", function(Packet:any)
        local Type = Packet.type

        if Type == InteractionType.PING then
            self:RespondInteraction(Packet, { type = 1 })
            return Packet
        end

        local Key = Routes[Type]
        if not Key then
            return Packet
        end

        local Handler = self:Grab(Key)

        if not Handler then
            return Packet
        end

        Handler:Run(Packet)

        return Packet
    end)

end)

return true
