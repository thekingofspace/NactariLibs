local task = require("@lune/task")
local net = require("@lune/net")
local serde = require("@lune/serde")

local GatewayURL = "wss://gateway.discord.gg/?v=10&encoding=json"
local EndPoint = "https://discord.com/api/v10"

exposedbots =  exposedbots or {}

CreationBoot = CreationBoot or {}

ExposedMethods = ExposedMethods or {}

local StandardPack = {
    op = 2;
    d = {
        token = "TOKEN HERE";
        intents = 0;
        properties = {
            os = "linux";
            browser = "noctari_prime";
            device = "noctari_prime";
        },
        shard = {0, 1};
    }
}
local Chain = {}
Chain.__index = Chain

local function newNode()
    return {
        callback = nil,
        catch = nil,
        halt = false,
        throw = nil,
        next = nil,
        root = nil,
    }
end

function Chain.new(fn)
    local node = newNode()
    node.callback = fn
    node.root = node
    return setmetatable(node, Chain)
end

function Chain:AndThen(fn)
    local n = newNode()
    n.callback = fn
    n.root = self.root
    self.next = n
    return setmetatable(n, Chain)
end

function Chain:Catch(fn)
    local n = newNode()
    n.catch = fn
    n.root = self.root
    self.next = n
    return setmetatable(n, Chain)
end

function Chain:Halt()
    local n = newNode()
    n.halt = true
    n.root = self.root
    self.next = n
    return setmetatable(n, Chain)
end

function Chain:Throw(fn)
    local n = newNode()
    n.throw = fn
    n.root = self.root
    self.next = n
    return setmetatable(n, Chain)
end

function Chain:ToEnd(fn)
    self.root.toend = fn
    return self
end

local function run(node, ...)
    local state = {
        node = node,
        last = { ... },
        halted = false,
    }

    while state.node do
        local current = state.node

        if current.halt then
            state.halted = true
            break
        end

        if current.throw then
            local ok, cont = pcall(current.throw, table.unpack(state.last))
            if not ok or not cont then
                state.halted = true
                break
            end
        end

        if current.callback then
            local ok, out = pcall(function(...)
                return { current.callback(...) }
            end, table.unpack(state.last))

            if not ok then
                local seek = current.next
                while seek do
                    if seek.catch then
                        local cok, cres = pcall(function()
                            return { seek.catch(out, table.unpack(state.last)) }
                        end)

                        if cok then
                            state.last = (#cres > 0) and cres or state.last
                            state.node = seek.next
                            continue
                        end

                        out = cres
                    end
                    seek = seek.next
                end

                break
            end

            if out and #out > 0 then
                state.last = out
            end
        end

        state.node = current.next
        continue
    end

    if not state.halted and node.root.toend then
        local ok, out = pcall(function()
            return { node.root.toend(table.unpack(state.last)) }
        end)
        if ok and out and #out > 0 then
            state.last = out
        end
    end

    return table.unpack(state.last)
end

function Chain:Run(...)
    return run(self, ...)
end

function Chain:Destroy()
    self.next = nil
    self.callback = nil
    self.catch = nil
    self.throw = nil
    self.root = nil
end

local module = {}

local BotMethods = {}
BotMethods.__index = BotMethods

export type Chain = {
    AndThen: (self: Chain, fn: (...any) -> ...any) -> Chain,
    Catch: (self: Chain, fn: (err: any, ...any) -> ...any) -> Chain,
    Await:(self:Chain) -> ...any;
    Halt:(self:Chain) -> Chain;
    Throw:(self:Chain, fn: (err: any, ...any) -> boolean) -> Chain;
    ToEnd:(self:Chain, fn: (...any) -> ...any) -> Chain;
    Run:(self:Chain, ...any) -> nil;
}

export type Private = {
    __ConnectedEvents: {};
    __RST: number;
    __HeartCount: number;
    __Gateway: net.WebSocket;
    __Started: boolean;
    __Tasks:{any};
    __ProccessorTask:any;

    __SessionID: string?;
    __GatewayURL: string?;
    __Resume:(self:Private) -> any;
    __Identify:(self:Private) -> any;
    __SpawnChain:(self:Private, ...any) -> any;
    __ShardList:{DiscordBot};
    __ChainsToRun:{Chain};
    __ActiveChainThreads:{};
    __RecommendedShards:number;
    __SessionLimits:number;
    __MaxConcurrency:number;
    __Yielded:boolean;

    ShardID: number;
    ShardCount: number;
}

export type DiscordBot = {
    Intents: number;
    Token: string;
    AppID: number;

    ShardID: number;
    ShardCount: number;

    On:(self:DiscordBot, Event:string, Callback:(Packet:any, Event:string?) -> nil) -> Chain;
    Start:(self:DiscordBot) -> DiscordBot;
    Stop:(self:DiscordBot, Reason:string?) -> DiscordBot;

    SendSocket:(self:DiscordBot, Packet:any) -> DiscordBot;
    SendContext:(self:DiscordBot, Method:string, Path:string, Body:any?, Headers:{[string]:any}?) -> any;

    Fracture:(self:DiscordBot, ShardID:number, ShardCount:number) -> DiscordBot;
    GetShards:(self:DiscordBot) -> { DiscordBot };
    Grab:(self:DiscordBot, Event:string) -> Chain?;
}

function BotMethods.__Identify(self)
    local Packet = table.clone(StandardPack)
    Packet.d.token = self.Token
    Packet.d.intents = self.Intents
    Packet.d.shard = { self.ShardID, self.ShardCount }

    self.__Gateway:send(serde.encode("json", Packet))
end

function BotMethods.Fracture(self:DiscordBot & Private, ShardID:number, ShardCount:number)
    local NewBot = module.New(self.Intents, self.Token, ShardID, ShardCount)

    for name, callback in pairs(self.__ConnectedEvents) do
        NewBot.__ConnectedEvents[name] = callback
    end

    NewBot.AppID = self.AppID
    table.insert(self.__ShardList, NewBot)

    return NewBot
end

function BotMethods.On(self, Event, Callback)
    local ev = Event:lower()
    
    if self.__ConnectedEvents[ev] then
        return self.__ConnectedEvents[ev]:AndThen(Callback)
    else
        local chain = Chain.new(Callback)
        self.__ConnectedEvents[ev] = chain

        return chain
    end
end

function BotMethods.SendSocket(self, Packet)
    if self.__Started and self.__Gateway then
        self.__Gateway:send(serde.encode("json", Packet))

        if self:Grab("socket_send") then
            self:__SpawnChain(self:Grab("socket_send"))
        end
    end
    return self
end

function BotMethods.Grab(self, Event:string): Chain?
    return self.__ConnectedEvents[Event:lower()]
end

function BotMethods.SendContext(self, Method, Path, Body, Headers)
    local Packet = {
        url = `{EndPoint}/{Path}`;
        method = Method:upper();
        headers = {
            ["Authorization"] = `Bot {self.Token}`;
            ["Content-Type"] = "application/json";
        }
    }

    if Headers then
        for k, v in pairs(Headers) do
            Packet.headers[k] = v
        end
    end

    if Body then
        Packet.body = typeof(Body) == "table"
            and serde.encode("json", Body)
            or Body
    end

    local ReturnPack = net.request(Packet)
    if ReturnPack.statusCode > 400 then
        error(`[ERROR CODE {ReturnPack.statusCode}]: {ReturnPack.statusMessage}, \n\n {ReturnPack.body}`)
    end

    if not ReturnPack.body then return nil end

    local ok, decoded = pcall(function()
        return serde.decode("json", ReturnPack.body)
    end)

    if self:Grab("rest_send") then
        self:__SpawnChain(self:Grab("rest_send"), ok and decoded or ReturnPack.body)
    end

    return ok and decoded or ReturnPack.body
end


function BotMethods.__Resume(self)
    self.__Gateway:send(serde.encode("json", {
        op = 6,
        d = {
            token = self.Token,
            session_id = self.__SessionID,
            seq = self.__RST
        }
    }))

    local chain = self:Grab("resume")
    if chain then
        self:__SpawnChain(chain)
    end
end

function BotMethods.Start(self:DiscordBot & Private)
    if self.__Started then return end

    if self:Grab("Start") then
        self:__SpawnChain(self:Grab("start"))
    end

    self.__Started = true

    local gatewayInfo = net.request({
        url = EndPoint .. "/gateway/bot",
        method = "GET",
        headers = { ["Authorization"] = "Bot " .. self.Token }
    })

    if gatewayInfo.statusCode > 400 then
        error("[Gateway Error] Failed /gateway/bot → " .. tostring(gatewayInfo.body))
    end

    local info = serde.decode("json", gatewayInfo.body)

    self.__GatewayURL = info.url .. "?v=10&encoding=json"
    self.__RecommendedShards = info.shards
    self.__SessionLimits = info.session_start_limit
    self.__MaxConcurrency = info.session_start_limit.max_concurrency

    if self.ShardCount % self.__RecommendedShards ~= 0 then
        self.ShardCount = self.__RecommendedShards
    end

    local url = self.__GatewayURL or GatewayURL
    local Gateway = net.socket(url)
    self.__Gateway = Gateway

    if self.__SessionID ~= nil and self.__RST ~= nil then
        self:__Resume()
    else
        self:__Identify()
    end

    local Hello = serde.decode("json", Gateway:next())
    self.__HeartCount = Hello.d.heartbeat_interval / 1000

    table.insert(self.__Tasks, task.spawn(function()
        while self.__Started and self.__Gateway do
            local raw = self.__Gateway:next()
            if not raw then continue end

            local Packet = serde.decode("json", raw)
            self.__RST = Packet.s or self.__RST or 0

            task.spawn(function()
                if Packet.close == 4010 then

                    local updated = net.request({
                        url = EndPoint .. "/gateway/bot",
                        method = "GET",
                        headers = { ["Authorization"] = "Bot " .. self.Token }
                    })

                    local newInfo = serde.decode("json", updated.body)
                    self.ShardCount = newInfo.shards

                    self:__Identify()
                    return
                end

                if Packet.op == 7 then
                    self:__Resume()
                    return
                end

                if Packet.op == 9 then

                    if Packet.d == true then
                        self:__Resume()
                    else
                        self:__Identify()
                    end

                    return
                end

                if Packet.op == 0 and Packet.t then
                    if Packet.t == "READY" then
                        self.__SessionID = Packet.d.session_id

                        if Packet.d.resume_gateway_url then
                            self.__GatewayURL = Packet.d.resume_gateway_url .. "?v=10&encoding=json"
                        end
                    end

                    local ev = Packet.t:lower()
                    local chain = self:Grab(ev)

                    if chain then
                        self:__SpawnChain(chain, Packet.d, ev)
                    elseif self:Grab("Undefined") then
                        self:__SpawnChain(self:Grab("Undefined"), Packet.d, ev)
                    end

                    local stepChain = self:Grab("signal_step")
                    if stepChain then
                        self:__SpawnChain(self:Grab("signal_step"))
                    end
                end
            end)
        end
    end))

    table.insert(self.__Tasks, task.spawn(function()
        while self.__Started and self.__Gateway do
            task.wait(self.__HeartCount)

            if not self.__Gateway then break end

            self.__Gateway:send(serde.encode("json", {
                op = 1;
                d = self.__RST or 0;
            }))

            local chain = self:Grab("Heartbeat")
            if chain then
                self:__SpawnChain(chain, os.time())
            end
        end
    end))

    local InitialPacket = self:SendContext("GET", "applications/@me")
    self.AppID = InitialPacket.id
    InitialPacket = nil
    self.__Yielded = false
    self.__ProccessorTask = task.spawn(function()
        while true do

            local item = table.remove(self.__ChainsToRun, 1)
            if item then
                local thread = task.spawn(function()
                    item[1]:Run(unpack(item[2]))
                end)

                self.__ActiveChainThreads[thread] = true

                task.spawn(function()
                    while coroutine.status(thread) ~= "dead" do
                        task.wait()
                    end
                    self.__ActiveChainThreads[thread] = nil
                end)
            end

            if #self.__ChainsToRun == 0 then
                self.__Yielded = true
                coroutine.yield()
            end
        end
    end)

    if self:Grab("Started") then
        self:__SpawnChain(self:Grab("started"))
    end
    
    return self
end

function BotMethods.__SpawnChain(self:DiscordBot & Private, Chain, ...)
    table.insert(self.__ChainsToRun, {Chain, {...}}::any)

    if self.__Yielded == true and self.__ProccessorTask then
        coroutine.resume(self.__ProccessorTask)
    end
end

function BotMethods.Stop(self:DiscordBot & Private, Reason:string?)
    if self:Grab("Stop") then
        (self:Grab("Stop")::any):Run(Reason)
    end

    for _, t in ipairs(self.__Tasks) do
        coroutine.close(t)
    end
    table.clear(self.__Tasks)

    if self.__Gateway then
        self.__Gateway:close(4000)
    end

    self.__Gateway = nil::any

    if self.__Yielded ~= true then
        while #self.__ChainsToRun ~= 0 do
            task.wait()
        end
    end

    coroutine.close(self.__ProccessorTask)

    self.__ProccessorTask = nil

    self.__Started = false

    if self:Grab("Stopped") then
        (self:Grab("Stopped")::any):Run(Reason)
    end
end

function BotMethods.GetShards(self)
    return self.__ShardList
end

function module.FromGlobal(Token:string):DiscordBot?
    if exposedbots[Token] then
        return exposedbots[Token]
    end

    return
end

local Methods = {
    __newindex = rawset;

    __index = function(self, Key)
        if BotMethods[Key] then
            return BotMethods[Key]
        end

        if ExposedMethods[Key] then
            return ExposedMethods[Key] 
        end

        return rawget(self, Key)
    end
}

function module.New(Intents:number, Token:string, ShardID:number?, ShardCount:number?):DiscordBot
    local self = setmetatable({
        Intents = Intents;
        Token = Token;

        ShardID = ShardID or 0;
        ShardCount = ShardCount or 1;

        __Tasks = {};
        __ConnectedEvents = {};
        __Started = false;

        __SessionID = nil;
        __GatewayURL = nil;
        __RST = 0;
        __ChainsToRun = {};
        __ActiveChainThreads = {};
        __Yielded = false;

        __ShardList = {};
    }, Methods)

    for I, item in ipairs(CreationBoot) do
        item(self)
    end

    exposedbots[Token] = self

    return self
end

return module
