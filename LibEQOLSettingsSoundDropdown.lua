local MODULE_MAJOR = "LibEQOLSettingsMode-1.0"
local ok, lib = pcall(LibStub, MODULE_MAJOR)
if not ok or not lib then
	return
end

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

LibEQOL_SoundDropdownMixin = CreateFromMixins(SettingsListElementMixin)

local DEFAULT_FRAME_WIDTH = 300
local DEFAULT_FRAME_HEIGHT = 26
local DEFAULT_MENU_HEIGHT = 200
local DEFAULT_LABEL_OFFSET_LEFT = 37
local DEFAULT_LABEL_OFFSET_RIGHT = -85
local DEFAULT_PREVIEW_POINT = { "LEFT", nil, "CENTER", -74, 0 }

local DEFAULT_PLACEHOLDER = _G.NONE or "None"
local DEFAULT_PREVIEW_TOOLTIP = "Preview Sound"
local DEFAULT_LABEL = "Sound"

local function cloneOption(option)
	if type(option) ~= "table" then
		return { value = option, label = tostring(option) }
	end
	local clone = {}
	for key, value in pairs(option) do
		clone[key] = value
	end
	clone.value = clone.value or clone.text or clone.label
	clone.label = clone.label or clone.text or tostring(clone.value or "")
	return clone
end

local function normalizeOptions(list)
	if type(list) ~= "table" then
		return {}
	end
	local normalized = {}
	local usesIndex = #list > 0

	if usesIndex then
		for _, entry in ipairs(list) do
			if entry ~= nil then
				table.insert(normalized, cloneOption(entry))
			end
		end
	else
		for value, label in pairs(list) do
			if type(label) == "table" then
				local cloned = cloneOption(label)
				cloned.value = cloned.value or value
				table.insert(normalized, cloned)
			else
				table.insert(normalized, { value = value, label = tostring(label) })
			end
		end
	end

	table.sort(normalized, function(a, b)
		return tostring(a.label or a.value or "") < tostring(b.label or b.value or "")
	end)

	return normalized
end

local function applySingleAnchor(widget, anchor, defaultRelative)
	if not widget then
		return
	end
	widget:ClearAllPoints()

	if type(anchor) == "table" then
		local point = anchor.point or anchor[1]
		local relative = anchor.relativeTo or anchor[2] or defaultRelative
		local relativePoint = anchor.relativePoint or anchor[3] or (relative and "CENTER" or "LEFT")
		local x = anchor.x or anchor.offsetX or anchor[4] or 0
		local y = anchor.y or anchor.offsetY or anchor[5] or 0

		if point then
			widget:SetPoint(point, relative, relativePoint, x, y)
			return
		end
	end

	if defaultRelative then
		widget:SetPoint("LEFT", defaultRelative, "CENTER", -74, 0)
	else
		widget:SetPoint("LEFT", DEFAULT_LABEL_OFFSET_LEFT, 0)
	end
end

local function applyAnchors(widget, anchors, fallbackRelative)
	if type(anchors) == "table" and anchors[1] and type(anchors[1]) == "table" then
		widget:ClearAllPoints()
		for _, anchor in ipairs(anchors) do
			local point = anchor.point or anchor[1]
			local relative = anchor.relativeTo or anchor[2] or fallbackRelative
			local relativePoint = anchor.relativePoint or anchor[3] or (relative and "CENTER" or "LEFT")
			local x = anchor.x or anchor.offsetX or anchor[4] or 0
			local y = anchor.y or anchor.offsetY or anchor[5] or 0
			widget:SetPoint(point or "LEFT", relative, relativePoint, x, y)
		end
		return
	end
	applySingleAnchor(widget, anchors, fallbackRelative)
end

function LibEQOL_SoundDropdownMixin:OnLoad()
	SettingsListElementMixin.OnLoad(self)
	if self.NewFeature then
		self.NewFeature:SetShown(false)
	end
end

function LibEQOL_SoundDropdownMixin:Init(initializer)
	SettingsListElementMixin.Init(self, initializer)

	self.initializer = initializer
	local data = initializer.data or {}
	self.setting = initializer:GetSetting() or data.setting
	self.parentCheck = data.parentCheck
	self.options = data.options
	self.optionfunc = data.optionfunc
	self.callback = data.callback
	self.soundResolver = data.soundResolver
	self.previewSoundFunc = data.previewSoundFunc
	self.playbackChannel = data.playbackChannel
	self.getPlaybackChannel = data.getPlaybackChannel
	self.placeholderText = data.placeholderText or DEFAULT_PLACEHOLDER
	self.previewTooltip = data.previewTooltip or DEFAULT_PREVIEW_TOOLTIP
	self.labelText = data.name or data.label or DEFAULT_LABEL
	self.menuHeight = data.menuHeight or DEFAULT_MENU_HEIGHT
	self.frameWidth = data.frameWidth or DEFAULT_FRAME_WIDTH
	self.frameHeight = data.frameHeight or DEFAULT_FRAME_HEIGHT
	self.optionsChangedVersion = 0

	if not self.cbrHandles then
		self.cbrHandles = Settings.CreateCallbackHandleContainer()
	end

	self:SetSize(self.frameWidth, self.frameHeight)
	self:SetupLabel()
	self:SetupPreviewButton()
	self:SetupDropdown()
	self:UpdateDropdownText()
	self:RegisterSettingListener()
end

function LibEQOL_SoundDropdownMixin:GetSetting()
	if self.setting then
		return self.setting
	end
	if self.initializer and self.initializer.GetSetting then
		self.setting = self.initializer:GetSetting()
	end
	return self.setting
end

function LibEQOL_SoundDropdownMixin:SetupLabel()
	if not self.Text then
		return
	end
	self.Text:SetFontObject("GameFontNormal")
	self.Text:SetText(self.labelText)
	self.Text:ClearAllPoints()
	local textLeft = (self:GetIndent() or 0) + DEFAULT_LABEL_OFFSET_LEFT
	self.Text:SetPoint("LEFT", textLeft, 0)
	self.Text:SetPoint("RIGHT", self, "CENTER", DEFAULT_LABEL_OFFSET_RIGHT, 0)
end

function LibEQOL_SoundDropdownMixin:SetupPreviewButton()
	if self.previewButton then
		return
	end

	local button = CreateFrame("Button", nil, self)
	button:SetSize(self.frameHeight, self.frameHeight)
	applySingleAnchor(button, DEFAULT_PREVIEW_POINT, self)
	button:SetMotionScriptsWhileDisabled(true)

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexture(self.data and self.data.previewIconTexture or "Interface\\Common\\VoiceChat-Speaker")
	icon:SetVertexColor(0.8, 0.8, 0.8)

	button.Icon = icon
	button:SetScript("OnEnter", function(control)
		if not control:IsEnabled() then
			return
		end
		icon:SetVertexColor(1, 1, 1)
		if GameTooltip then
			GameTooltip:SetOwner(control, "ANCHOR_TOP")
			GameTooltip:SetText(self.previewTooltip)
			GameTooltip:Show()
		end
	end)
	button:SetScript("OnLeave", function()
		icon:SetVertexColor(0.8, 0.8, 0.8)
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	button:SetScript("OnClick", function()
		self:PreviewCurrentSound()
	end)

	self.previewButton = button
end

function LibEQOL_SoundDropdownMixin:PreviewCurrentSound()
	local setting = self:GetSetting()
	local value = setting and setting:GetValue()
	if self.previewSoundFunc then
		local ok = pcall(self.previewSoundFunc, value)
		if ok then
			return
		end
	end
	local sound = value
	if self.soundResolver then
		local ok, resolved = pcall(self.soundResolver, value)
		if ok and resolved then
			sound = resolved
		end
	end
	local channel = self.getPlaybackChannel and self.getPlaybackChannel(value) or self.playbackChannel
	if tonumber(sound) then
		PlaySound(tonumber(sound), channel)
	elseif type(sound) == "string" and sound ~= "" then
		if LSM then
			local mediaPath = LSM:Fetch("sound", sound, true)
			if mediaPath then
				PlaySoundFile(mediaPath, channel)
				return
			end
		end
		PlaySoundFile(sound, channel)
	end
end

function LibEQOL_SoundDropdownMixin:SetupDropdown()
	if not self.Dropdown then
		return
	end
	local function buildOptions()
		local list = self.options
		if self.optionfunc then
			local ok, result = pcall(self.optionfunc)
			if ok and type(result) == "table" then
				list = result
			end
		end
		local normalized = normalizeOptions(list)
		local container = Settings.CreateControlTextContainer()
		container:Add(0, self.placeholderText)
		for _, opt in ipairs(normalized) do
			if opt.value ~= nil then
				container:Add(opt.value, opt.label or tostring(opt.value))
			end
		end
		return container:GetData()
	end

	self.Dropdown:SetupMenu(function(_, rootDescription)
		rootDescription:SetTag("LIBEQOL_SOUND_VERSION", self.optionsChangedVersion)
		rootDescription:SetScrollMode(self.menuHeight)
		for _, entry in ipairs(buildOptions()) do
			local value, text = entry.value, entry.text
			rootDescription:CreateRadio(text, function()
				local setting = self:GetSetting()
				return setting and setting:GetValue() == value
			end, function()
				local setting = self:GetSetting()
				if setting then
					setting:SetValue(value)
					self:UpdateDropdownText()
					if self.callback then
						pcall(self.callback, value)
					end
				end
			end)
		end
	end)
end

function LibEQOL_SoundDropdownMixin:RegisterSettingListener()
	local setting = self:GetSetting()
	if not setting or not setting.connectCallbacks then
		return
	end
	self.cbrHandles:UnregisterAll()
	self.cbrHandles:RegisterCallback(setting, function()
		self:UpdateDropdownText()
	end)
end

function LibEQOL_SoundDropdownMixin:UpdateDropdownText()
	local setting = self:GetSetting()
	if not (setting and self.Dropdown) then
		return
	end
	local current = setting:GetValue()
	local label = self.placeholderText
	for _, opt in ipairs(normalizeOptions(self.options or {})) do
		if opt.value == current then
			label = opt.label or tostring(opt.value)
			break
		end
	end
	if label and label ~= "" then
		self.Dropdown:SetDefaultText(label)
	end
end
