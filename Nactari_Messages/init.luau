local ChannelTypes = {
	[0]  = "GUILD_TEXT",
	[1]  = "DM",
	[2]  = "GUILD_VOICE",
	[3]  = "GROUP_DM",
	[4]  = "GUILD_CATEGORY",
	[5]  = "GUILD_ANNOUNCEMENT",
	[10] = "ANNOUNCEMENT_THREAD",
	[11] = "PUBLIC_THREAD",
	[12] = "PRIVATE_THREAD",
	[13] = "GUILD_STAGE_VOICE",
	[14] = "GUILD_DIRECTORY",
	[15] = "GUILD_FORUM",
	[16] = "GUILD_MEDIA"
}

local UsedLibraries = {
	{ "Nactari", "1.0.0" },
	{ "NactariDependants", "1.0.0" },
}

local ChannelEnumStrings = {
	GUILD_TEXT = "GUILD_TEXT",
	DM = "DM",
	GUILD_VOICE = "GUILD_VOICE",
	GROUP_DM = "GROUP_DM",
	GUILD_CATEGORY = "GUILD_CATEGORY",
	GUILD_ANNOUNCEMENT = "GUILD_ANNOUNCEMENT",
	ANNOUNCEMENT_THREAD = "ANNOUNCEMENT_THREAD",
	PUBLIC_THREAD = "PUBLIC_THREAD",
	PRIVATE_THREAD = "PRIVATE_THREAD",
	GUILD_STAGE_VOICE = "GUILD_STAGE_VOICE",
	GUILD_DIRECTORY = "GUILD_DIRECTORY",
	GUILD_FORUM = "GUILD_FORUM",
	GUILD_MEDIA = "GUILD_MEDIA",
}

local EmbedBuilder = {}
EmbedBuilder.__index = EmbedBuilder

export type EmbedBuilder = {
	SetTitle: (self: EmbedBuilder, title: string) -> EmbedBuilder,
	SetDescription: (self: EmbedBuilder, description: string) -> EmbedBuilder,
	SetColor: (self: EmbedBuilder, color: number) -> EmbedBuilder,
	SetAuthor: (self: EmbedBuilder, name: string, iconUrl: string?, url: string?) -> EmbedBuilder,
	SetFooter: (self: EmbedBuilder, text: string, iconUrl: string?) -> EmbedBuilder,
	SetImage: (self: EmbedBuilder, url: string) -> EmbedBuilder,
	SetThumbnail: (self: EmbedBuilder, url: string) -> EmbedBuilder,
	SetTimestamp: (self: EmbedBuilder, timestamp: string?) -> EmbedBuilder,
	SetUrl: (self: EmbedBuilder, url: string) -> EmbedBuilder,
	AddField: (self: EmbedBuilder, name: string, value: string, inline: boolean?) -> EmbedBuilder,
	Build: (self: EmbedBuilder) -> {[string]: any}
}

function EmbedBuilder.new(): EmbedBuilder
	local self = setmetatable({}, EmbedBuilder)
	self._data = {
		fields = {}
	}
	return self
end

function EmbedBuilder:SetTitle(title: string): EmbedBuilder
	self._data.title = title
	return self
end

function EmbedBuilder:SetDescription(description: string): EmbedBuilder
	self._data.description = description
	return self
end

function EmbedBuilder:SetColor(color: number): EmbedBuilder
	self._data.color = color
	return self
end

function EmbedBuilder:SetAuthor(name: string, iconUrl: string?, url: string?): EmbedBuilder
	self._data.author = {
		name = name,
		icon_url = iconUrl,
		url = url
	}
	return self
end

function EmbedBuilder:SetFooter(text: string, iconUrl: string?): EmbedBuilder
	self._data.footer = {
		text = text,
		icon_url = iconUrl
	}
	return self
end

function EmbedBuilder:SetImage(url: string): EmbedBuilder
	self._data.image = {
		url = url
	}
	return self
end

function EmbedBuilder:SetThumbnail(url: string): EmbedBuilder
	self._data.thumbnail = {
		url = url
	}
	return self
end

function EmbedBuilder:SetTimestamp(timestamp: string?): EmbedBuilder
	self._data.timestamp = timestamp or os.date("!%Y-%m-%dT%H:%M:%S.000Z")
	return self
end

function EmbedBuilder:SetUrl(url: string): EmbedBuilder
	self._data.url = url
	return self
end

function EmbedBuilder:AddField(name: string, value: string, inline: boolean?): EmbedBuilder
	table.insert(self._data.fields, {
		name = name,
		value = value,
		inline = inline or false
	})
	return self
end

function EmbedBuilder:Build(): {[string]: any}
	return self._data
end

local Message = {}
Message.__index = Message

export type Message = {
	SetContent: (self: Message, content: string) -> Message,
	AddEmbed: (self: Message, embed: EmbedBuilder | {[string]: any}) -> Message,
	SetEmbeds: (self: Message, embeds: {{[string]: any}}) -> Message,
	SetTTS: (self: Message, tts: boolean) -> Message,
	AddComponent: (self: Message, component: {[string]: any}) -> Message,
	SetComponents: (self: Message, components: {{[string]: any}}) -> Message,
	SetAllowedMentions: (self: Message, mentions: {[string]: any}) -> Message,
	SetReference: (self: Message, messageId: string, channelId: string?, guildId: string?) -> Message,
	AddAttachment: (self: Message, attachment: {[string]: any}) -> Message,
	MakeEphemeral: (self: Message, ephemeral: boolean?) -> Message,
	Build: (self: Message) -> {[string]: any}
}

function Message.new(): Message
	local self = setmetatable({}, Message)
	self._data = {
		embeds = {},
		components = {},
		attachments = {}
	}
	return self
end

function Message:SetContent(content: string): Message
	self._data.content = content
	return self
end

function Message:AddEmbed(embed: EmbedBuilder | {[string]: any}): Message
	local embedData = if type(embed) == "table" and embed.Build then embed:Build() else embed
	table.insert(self._data.embeds, embedData)
	return self
end

function Message:SetEmbeds(embeds: {{[string]: any}}): Message
	self._data.embeds = embeds
	return self
end

function Message:SetTTS(tts: boolean): Message
	self._data.tts = tts
	return self
end

function Message:AddComponent(component: {[string]: any}): Message
	table.insert(self._data.components, component)
	return self
end

function Message:SetComponents(components: {{[string]: any}}): Message
	self._data.components = components
	return self
end

function Message:SetAllowedMentions(mentions: {[string]: any}): Message
	self._data.allowed_mentions = mentions
	return self
end

function Message:SetReference(messageId: string, channelId: string?, guildId: string?): Message
	self._data.message_reference = {
		message_id = messageId,
		channel_id = channelId,
		guild_id = guildId
	}
	return self
end

function Message:AddAttachment(attachment: {[string]: any}): Message
	table.insert(self._data.attachments, attachment)
	return self
end

function Message:MakeEphemeral(ephemeral: boolean?): Message
	if ephemeral == nil then ephemeral = true end
	self._data.flags = if ephemeral then 64 else nil
	return self
end

function Message:Build(): {[string]: any}
	return self._data
end

export type Messagable<bot> = {
	SendMessage: (self: bot, channelId: string, message: Message | {[string]: any}) -> any,
	DeleteMessage: (self: bot, channelId: string, messageId: string) -> any,
	EditMessage: (self: bot, channelId: string, messageId: string, message: Message | {[string]: any}) -> any,
	CreateEmbed: (self: bot) -> EmbedBuilder,
	CreateMessage: (self: bot) -> Message,

	Enums: {
		ChannelTypes: {
			GUILD_TEXT: string,
			DM: string,
			GUILD_VOICE: string,
			GROUP_DM: string,
			GUILD_CATEGORY: string,
			GUILD_ANNOUNCEMENT: string,
			ANNOUNCEMENT_THREAD: string,
			PUBLIC_THREAD: string,
			PRIVATE_THREAD: string,
			GUILD_STAGE_VOICE: string,
			GUILD_DIRECTORY: string,
			GUILD_FORUM: string,
			GUILD_MEDIA: string,
		}
	}
}

function ExposedMethods:GetChannelType(num)
	return ChannelTypes[num] or "UNKNOWN"
end

function ExposedMethods:CreateEmbed(): EmbedBuilder
	return EmbedBuilder.new()
end

function ExposedMethods:CreateMessage(): Message
	return Message.new()
end

function ExposedMethods:SendMessage(channelId: string, message: Message | {[string]: any})
	local payload = if type(message) == "table" and message.Build then message:Build() else message
	return self:SendContext("Post", `channels/{channelId}/messages`, payload)
end

function ExposedMethods:DeleteMessage(channelId: string, messageId: string)
	return self:SendContext("Delete", `channels/{channelId}/messages/{messageId}`)
end

function ExposedMethods:EditMessage(channelId: string, messageId: string, message: Message | {[string]: any})
	local payload = if type(message) == "table" and message.Build then message:Build() else message
	return self:SendContext("Patch", `channels/{channelId}/messages/{messageId}`, payload)
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
	self.Enums.ChannelTypes = ChannelEnumStrings

	self:On("message_create", function(Packet: any)
		local ChannelID = Packet.channel_id
		local Chan = self:SendContext("Get", `channels/{ChannelID}`)
		local TypeString = self:GetChannelType(Chan.type)
		
		if self:Grab(TypeString) then
			self:Grab(TypeString):Run(Packet)
		end
	end)
end)

return true