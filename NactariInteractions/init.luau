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

export type CommandOption = {
    name: string,
    type: number,
    description: string,
    required: boolean?,
}

export type CommandBuilder = {
    Name: string,
    Description: string,
    Type: number,
    Options: { CommandOption },
    Callback: ((self:CommandBuilder, Packet:any) -> ())?,

    SetDescription: (self:CommandBuilder, desc:string) -> CommandBuilder,
    AddParameter: (self:CommandBuilder, name:string, paramType:number, desc:string, required:boolean?) -> CommandBuilder,
    AddCallback: (self:CommandBuilder, fn:(self:CommandBuilder, Packet:any) -> ()) -> CommandBuilder
}

export type Interactable<bot> = {
    RespondInteraction: (self:bot, Packet:any, Response:any) -> bot,
    CreateCommand: (self:bot, Name:string, CommandType:number) -> CommandBuilder,

    Enums: {
        InteractionTypes: {
            PING: string,
            APPLICATION_COMMAND: string,
            MESSAGE_COMPONENT: string,
            APPLICATION_COMMAND_AUTOCOMPLETE: string,
            MODAL_SUBMIT: string,
        },

        CommandTypes: {
            CHAT_INPUT: number,
            USER: number,
            MESSAGE: number,
            PRIMARY_ENTRY_POINT: number,
        },

        ParamTypes: {
            SUB_COMMAND: number,
            SUB_COMMAND_GROUP: number,
            STRING: number,
            INTEGER: number,
            BOOLEAN: number,
            USER: number,
            CHANNEL: number,
            ROLE: number,
            MENTIONABLE: number,
            NUMBER: number,
            ATTACHMENT: number,
        },
    },
}


local InteratableEnums = {}

for i, _ in pairs(InteractionType) do
    InteratableEnums[i] = i
end

local CommandTypes = {
    CHAT_INPUT = 1,
    USER = 2,
    MESSAGE = 3,
    PRIMARY_ENTRY_POINT = 4,
}

local ParamTypes = {
    SUB_COMMAND = 1,
    SUB_COMMAND_GROUP = 2,
    STRING = 3,
    INTEGER = 4,
    BOOLEAN = 5,
    USER = 6,
    CHANNEL = 7,
    ROLE = 8,
    MENTIONABLE = 9,
    NUMBER = 10,
    ATTACHMENT = 11,
}

local CommandBuilder = {}
CommandBuilder.__index = CommandBuilder

function CommandBuilder.new(Name:string, Type:number)
    return setmetatable({
        Name = Name,
        Description = "",
        Type = Type,
        Options = {},
        Callback = nil,
    }, CommandBuilder)
end

function CommandBuilder:SetDescription(desc:string)
    self.Description = desc
    return self
end

function CommandBuilder:AddParameter(Name:string, ParamType:number, Description:string, Required:boolean?)
    table.insert(self.Options, {
        name = Name,
        type = ParamType,
        description = Description or "",
        required = Required or false,
    })
    return self
end

function CommandBuilder:AddCallback(fn)
    self.Callback = fn
    return self
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

function ExposedMethods:CreateCommand(Name:string, CommandType:number)
    self._RegisteredCommands = self._RegisteredCommands or {}

    local New = CommandBuilder.new(Name, CommandType)
    self._RegisteredCommands[Name] = New

    return New
end

local function SyncCommands(self)
    local AppID = self.AppID
    if not AppID then
        warn("[NACTARI] Cannot sync commands: missing ApplicationID")
        return
    end

    local Existing = self:SendContext("Get", `applications/{AppID}/commands`)
    if not Existing then Existing = {} end

    local ToKeep = {}
    for name in pairs(self._RegisteredCommands or {}) do
        ToKeep[name] = true
    end
    
    for _, oldCmd in ipairs(Existing) do
        if not ToKeep[oldCmd.name] then
            self:SendContext("Delete", `applications/{AppID}/commands/{oldCmd.id}`)
        end
    end

    for name, cmd in pairs(self._RegisteredCommands or {}) do
        local Payload = {
            name = name,
            type = cmd.Type,
            description = cmd.Description or "",
            options = cmd.Options,
        }

        self:SendContext("Post", `applications/{AppID}/commands`, Payload)
    end

    print("[NACTARI] Command sync complete")
end

table.insert(CreationBoot, function(self)
    if not self.UsedLibraries then
        error("MISSING NACTARI DEPENDANTS")
    end

    self:On("Start", function()
        for _, dep in ipairs(UsedLibraries) do
            self:HasLibrary(dep)
        end
    end):Catch(function(err)
        warn(err)
    end)

    self.Enums = self.Enums or {}

    self.Enums.InteractionTypes = InteratableEnums
    self.Enums.CommandTypes = CommandTypes
    self.Enums.ParamTypes = ParamTypes

    self:On("interaction_create", function(Packet:any)
        local Type = Packet.type

        if Type == InteractionType.PING then
            self:RespondInteraction(Packet, { type = 1 })
            return Packet
        end

        if Type == InteractionType.APPLICATION_COMMAND then
            local name = Packet.data.name
            local CmdObj = self._RegisteredCommands and self._RegisteredCommands[name]

            if CmdObj and CmdObj.Callback then
                CmdObj.Callback(self, Packet)
            end

            return Packet
        end

        local Key = Routes[Type]
        if not Key then
            return Packet
        end

        local Handler = self:Grab(Key)
        if Handler then
            Handler:Run(Packet)
        end

        return Packet
    end)

    self:On("Started", function()
        SyncCommands(self)
    end)
end)

return true
