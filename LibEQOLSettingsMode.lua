local MODULE_MAJOR, MINOR = "LibEQOLSettingsMode-1.0", 5000001
local LibStub = _G.LibStub
assert(LibStub, MODULE_MAJOR .. " requires LibStub")

local lib = LibStub:NewLibrary(MODULE_MAJOR, MINOR)
if not lib then
	return
end
lib.MINOR = MINOR

local Settings = _G.Settings
local SettingsPanel = _G.SettingsPanel
local SettingsInbound = _G.SettingsInbound
local SettingsCategoryListButtonMixin = _G.SettingsCategoryListButtonMixin
local SettingsCheckboxControlMixin = _G.SettingsCheckboxControlMixin
local SettingsDropdownControlMixin = _G.SettingsDropdownControlMixin
local SettingsSliderControlMixin = _G.SettingsSliderControlMixin

local function isSearchActive()
	return SettingsPanel and SettingsPanel.SearchBox and SettingsPanel.SearchBox:HasText()
end

local State = {
	rootCategory = nil,
	rootLayout = nil,
	newTagResolverDefault = nil,
	newTagResolvers = {},
	prefix = "LibEQOLSettings_",
	prefixSet = false,
	prefixWarned = false,
	rootName = "LibEQOL Settings",
	categories = {},
	elements = {},
	categoryTags = {},
	categoryPrefixes = {},
	settingPrefixes = {},
}

local function prefixNotifyTag(tag, setting)
	if type(tag) ~= "string" or tag == "" then
		return tag
	end

	-- If the tag is already prefixed, keep it
	for prefix in pairs(State.newTagResolvers) do
		if tag:find(prefix, 1, true) == 1 then
			return tag
		end
	end
	if State.prefixSet and tag:find(State.prefix, 1, true) == 1 then
		return tag
	end

	-- Prefer the setting's prefix, then the global prefix
	local settingVar = setting and setting.GetVariable and setting:GetVariable()
	local tagPrefix = (settingVar and State.settingPrefixes[settingVar])
		or State.settingPrefixes[tag]
		or (State.prefixSet and State.prefix)
	if tagPrefix and not tag:find(tagPrefix, 1, true) then
		return tagPrefix .. tag
	end

	return tag
end

local function attachNotify(setting, tag)
	if not (setting and setting.SetValueChangedCallback) then
		return
	end

	local notifyTag = tag or (setting.GetVariable and setting:GetVariable()) or setting.variable
	notifyTag = prefixNotifyTag(notifyTag, setting)
	if not notifyTag or notifyTag == "" then
		return
	end

	setting:SetValueChangedCallback(function(_, value)
		Settings.NotifyUpdate(notifyTag)
	end)
end

local function maybeAttachNotify(setting, data)
	if not (data and data.notify) then
		return
	end
	local notifyTag = (data.notify == true)
			and ((setting and setting.GetVariable and setting:GetVariable()) or (setting and setting.variable))
		or data.notify
	attachNotify(setting, notifyTag)
end

local function getResolverForPrefix(prefix)
	if prefix and State.newTagResolvers[prefix] then
		return State.newTagResolvers[prefix], prefix
	end
	if State.newTagResolverDefault then
		return State.newTagResolverDefault, prefix
	end
	return nil, prefix
end

local function getResolverForVariable(variable)
	if not variable then
		return nil
	end

	if State.settingPrefixes[variable] then
		return getResolverForPrefix(State.settingPrefixes[variable])
	end

	-- longest-prefix match
	local bestPrefix, bestLen
	for prefix in pairs(State.newTagResolvers) do
		if type(prefix) == "string" and variable:find(prefix, 1, true) == 1 then
			local len = #prefix
			if not bestLen or len > bestLen then
				bestPrefix, bestLen = prefix, len
			end
		end
	end

	if bestPrefix then
		return State.newTagResolvers[bestPrefix], bestPrefix
	end

	return State.newTagResolverDefault, nil
end

local function shouldShowNewTag(category)
	if not category then
		return false
	end
	local tag = category._LibEQOLNewTagID or State.categoryTags[category:GetID()]
	if not tag and not State.categoryTags[category:GetID()] then
		-- Unknown category (not registered via this lib); skip
		return false
	end
	local categoryID = category:GetID()
	local token = tag or categoryID
	local resolver = getResolverForPrefix(State.categoryPrefixes[categoryID])
	if not resolver then
		return false
	end
	local ok, result = pcall(resolver, token, tag, categoryID, State.categoryPrefixes[categoryID])
	return ok and result == true
end

local function hookNewTag()
	if State._hooked then
		return
	end
	State._hooked = true

	hooksecurefunc(SettingsCategoryListButtonMixin, "Init", function(self, initializer)
		local category = initializer.data.category
		if category and shouldShowNewTag(category) and self.NewFeature then
			self.NewFeature:SetShown(true)
		end
	end)

	local function tagControl(self)
		local setting = self.GetSetting and self:GetSetting()
		if not (setting and setting.variable) then
			return
		end
		local resolver = getResolverForVariable(setting.variable)
		if resolver and resolver(setting.variable) and self.NewFeature then
			self.NewFeature:SetShown(true)
		end
	end

	hooksecurefunc(SettingsCheckboxControlMixin, "Init", tagControl)
	hooksecurefunc(SettingsDropdownControlMixin, "Init", tagControl)
	hooksecurefunc(SettingsSliderControlMixin, "Init", tagControl)
end

function lib:SetNewTagResolver(resolver)
	error("SetNewTagResolver is deprecated. Use SetNewTagResolverForPrefix(prefix, resolver) instead.")
end

function lib:SetDefaultRootName(name)
	if type(name) == "string" and name ~= "" then
		State.rootName = name
	end
end

local function prefixTag(tag)
	if type(tag) ~= "string" then
		return tag
	end
	local p = State.prefixSet and State.prefix
	if p and not tag:find(p, 1, true) then
		return p .. tag
	end
	return tag
end

local function registerCategory(name, parent, sort, newTagID)
	newTagID = prefixTag(newTagID)
	if parent == nil then
		local cat, layout = Settings.RegisterVerticalLayoutCategory(name)
		Settings.RegisterAddOnCategory(cat)
		cat:SetShouldSortAlphabetically(sort ~= false)
		cat._LibEQOLNewTagID = newTagID
		State.categoryTags[cat:GetID()] = newTagID
		State.categoryPrefixes[cat:GetID()] = State.prefixSet and State.prefix
		return cat, layout
	end
	local cat, layout = Settings.RegisterVerticalLayoutSubcategory(parent, name)
	Settings.RegisterAddOnCategory(cat)
	cat:SetShouldSortAlphabetically(sort ~= false)
	cat._LibEQOLNewTagID = newTagID
	State.categoryTags[cat:GetID()] = newTagID
	State.categoryPrefixes[cat:GetID()] = State.prefixSet and State.prefix
	return cat, layout
end

local function applyParentInitializer(element, parentInitializer, parentCheck)
	if element and parentInitializer then
		element:SetParentInitializer(parentInitializer, parentCheck)
	end
end

local function refreshSettingsLayout()
	if SettingsInbound and SettingsInbound.RepairDisplay then
		SettingsInbound.RepairDisplay()
	elseif SettingsPanel and SettingsPanel.RepairDisplay then
		SettingsPanel:RepairDisplay()
	end
end

local function normalizeSectionPredicate(section)
	if section == nil then
		return nil
	end

	if type(section) == "function" then
		return section
	end

	if type(section) == "table" then
		if type(section.IsExpanded) == "function" then
			return function()
				return section:IsExpanded() ~= false
			end
		end

		local data = section.data or (section.GetData and section:GetData())
		if data and data.expanded ~= nil then
			return function()
				return data.expanded ~= false
			end
		end
	end
end

local function applyExpandablePredicate(initializer, data)
	if not (initializer and data) then
		return
	end

	local predicate = normalizeSectionPredicate(data.parentSection or data.section or data.expandWith)
	if predicate and initializer.AddShownPredicate then
		initializer:AddShownPredicate(function()
			if isSearchActive() then
				return true
			end
			return predicate()
		end)
	end
end

local function addSearchTags(initializer, searchtags, text)
	if searchtags == nil then
		if text then
			initializer:AddSearchTags(text)
		end
	elseif searchtags then
		if type(searchtags) == "table" then
			for _, tag in ipairs(searchtags) do
				initializer:AddSearchTags(tag)
			end
		else
			initializer:AddSearchTags(searchtags)
		end
	end
end

function lib:CreateRootCategory(name, sort, newTagID)
	local cat, layout = registerCategory(name or State.rootName, nil, sort, newTagID)
	State.rootCategory = cat
	State.rootLayout = layout
	return cat, layout
end

function lib:CreateCategory(parent, name, sort, newTagID)
	if not parent then
		parent = State.rootCategory or select(1, self:CreateRootCategory(State.rootName))
	end
	local cat, layout = registerCategory(name, parent, sort, newTagID)
	State.categories[name] = cat
	return cat, layout
end

local function registerSetting(cat, key, varType, name, default, getter, setter, data)
	local prefix = data and data.prefix
	local variable = data and data.variable

	if not (State.prefixSet or prefix or variable) then
		error(
			("LibEQOLSettingsMode: SetVariablePrefix(...) must be called before registering settings (missing before key '%s'). Alternatively pass data.prefix or data.variable."):format(
				tostring(key)
			)
		)
	end

	if not variable then
		prefix = prefix or State.prefix
		variable = (prefix or "") .. key
	end

	if prefix then
		State.settingPrefixes[variable] = prefix
	elseif State.prefixSet then
		State.settingPrefixes[variable] = State.prefix
	end

	return Settings.RegisterProxySetting(cat, variable, varType, name, default, getter, setter)
end

function lib:CreateCheckbox(cat, data)
	assert(cat and data and data.key, "category and data.key required")
	local setting = registerSetting(
		cat,
		data.key,
		Settings.VarType.Boolean,
		data.name or data.text or data.key,
		data.default ~= nil and data.default or false,
		data.get or function()
			return data.default
		end,
		data.set,
		data
	)
	local element = Settings.CreateCheckbox(cat, setting, data.desc)
	applyParentInitializer(element, data.parent, data.parentCheck)
	addSearchTags(element, data.searchtags, data.name or data.text)
	applyExpandablePredicate(element, data)
	State.elements[data.key] = element
	maybeAttachNotify(setting, data)
	return element, setting
end

function lib:CreateSlider(cat, data)
	assert(cat and data and data.key, "category and data.key required")
	local setting = registerSetting(
		cat,
		data.key,
		Settings.VarType.Number,
		data.name or data.text or data.key,
		data.default or data.min or 0,
		data.get,
		data.set,
		data
	)
	local options = Settings.CreateSliderOptions(data.min or 0, data.max or 1, data.step or 1)
	if data.formatter then
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, data.formatter)
	end
	local element = Settings.CreateSlider(cat, setting, options, data.desc)
	applyParentInitializer(element, data.parent, data.parentCheck)
	addSearchTags(element, data.searchtags, data.name or data.text)
	applyExpandablePredicate(element, data)
	State.elements[data.key] = element
	maybeAttachNotify(setting, data)
	return element, setting
end

function lib:CreateDropdown(cat, data)
	assert(cat and data and data.key, "category and data.key required")
	local defaultType = type(data.default)
	local varType = data.varType
	if not varType then
		if defaultType == "number" then
			varType = Settings.VarType.Number
		elseif defaultType == "boolean" then
			varType = Settings.VarType.Boolean
		else
			varType = Settings.VarType.String
		end
	end
	local setting = registerSetting(
		cat,
		data.key,
		varType,
		data.name or data.text or data.key,
		data.default,
		data.get,
		data.set,
		data
	)
	local function optionsFunc()
		local container = Settings.CreateControlTextContainer()
		local list = data.values
		if data.optionfunc then
			local ok, result = pcall(data.optionfunc)
			if ok and type(result) == "table" then
				list = result
			end
		end
		if type(list) == "table" then
			for key, value in pairs(list) do
				container:Add(key, value)
			end
		end
		return container:GetData()
	end
	local dropdown = Settings.CreateDropdown(cat, setting, optionsFunc, data.desc)
	applyParentInitializer(dropdown, data.parent, data.parentCheck)
	addSearchTags(dropdown, data.searchtags, data.name or data.text)
	applyExpandablePredicate(dropdown, data)
	State.elements[data.key] = dropdown
	maybeAttachNotify(setting, data)
	return dropdown, setting
end

function lib:CreateSoundDropdown(cat, data)
	assert(cat and data and data.key, "category and data.key required")
	local setting = registerSetting(
		cat,
		data.key,
		data.varType or Settings.VarType.String,
		data.name or data.text or data.key,
		data.default,
		data.get,
		data.set,
		data
	)
	local initializer = Settings.CreateElementInitializer("LibEQOL@project-abbreviated-hash@_SoundDropdownTemplate", {
		setting = setting,
		options = data.values or data.options,
		optionfunc = data.optionfunc,
		callback = data.callback,
		soundResolver = data.soundResolver,
		previewSoundFunc = data.previewSoundFunc,
		playbackChannel = data.playbackChannel,
		getPlaybackChannel = data.getPlaybackChannel,
		placeholderText = data.placeholderText,
		previewTooltip = data.previewTooltip,
		name = data.name or data.text or data.key,
		menuHeight = data.menuHeight,
		frameWidth = data.frameWidth,
		frameHeight = data.frameHeight,
		parentCheck = data.parentCheck,
	})
	initializer:SetSetting(setting)
	addSearchTags(initializer, data.searchtags, data.name or data.text)
	applyParentInitializer(initializer, data.parent, data.parentCheck)
	applyExpandablePredicate(initializer, data)
	Settings.RegisterInitializer(cat, initializer)
	State.elements[data.key] = initializer
	maybeAttachNotify(setting, data)
	return initializer, setting
end

function lib:CreateColorOverrides(cat, data)
	assert(cat and data and data.entries, "category and entries required")
	local initializer = Settings.CreateElementInitializer("LibEQOL@project-abbreviated-hash@_ColorOverridesPanelNoHead", {
		categoryID = cat:GetID(),
		entries = data.entries,
		getColor = data.getColor,
		setColor = data.setColor,
		getDefaultColor = data.getDefaultColor,
		parentCheck = data.parentCheck,
	})
	-- addSearchTags(initializer, data.searchtags, data.name or data.text)
	Settings.RegisterInitializer(cat, initializer)
	applyParentInitializer(initializer, data.parent, data.parentCheck)
	applyExpandablePredicate(initializer, data)
	State.elements[data.key or (data.name or "ColorOverrides")] = initializer
	maybeAttachNotify(initializer.GetSetting and initializer:GetSetting(), data)
	return initializer
end

function lib:CreateMultiDropdown(cat, data)
	assert(cat and data and data.key, "category and data.key required")
	local setting = registerSetting(
		cat,
		data.key,
		Settings.VarType.String,
		data.name or data.text or data.key,
		"",
		function()
			return ""
		end,
		function() end,
		data
	)
	local initializer = Settings.CreateElementInitializer("LibEQOL@project-abbreviated-hash@_MultiDropdownTemplate", {
		label = data.name or data.text or data.key,
		options = data.values,
		optionfunc = data.optionfunc,
		isSelectedFunc = data.isSelected,
		setSelectedFunc = data.setSelected,
		getSelection = data.getSelection or data.get,
		setSelection = data.setSelection or data.set,
		summaryFunc = data.summary,
	})
	initializer:SetSetting(setting)
	addSearchTags(initializer, data.searchtags, data.name or data.text)
	applyParentInitializer(initializer, data.parent, data.parentCheck)
	applyExpandablePredicate(initializer, data)
	Settings.RegisterInitializer(cat, initializer)
	State.elements[data.key] = initializer
	maybeAttachNotify(setting, data)
	return initializer, setting
end

function lib:CreateExpandableSection(cat, data)
	assert(cat and data and (data.name or data.text), "category and data.name required")

	local nameGetter = data.name or data.text or data.key or "Section"
	if type(nameGetter) == "string" then
		local cachedName = nameGetter
		nameGetter = function()
			return cachedName
		end
	end

	local resolvedName = nameGetter() or "Section"
	local initializer
	if type(CreateSettingsExpandableSectionInitializer) == "function" then
		initializer = CreateSettingsExpandableSectionInitializer(resolvedName)
	else
		initializer = Settings.CreateElementInitializer("SettingsExpandableSectionTemplate", { name = resolvedName })
	end

	initializer.data.nameGetter = nameGetter
	initializer.data.expanded = data.expanded ~= false

	function initializer:GetExtent()
		return data.extent or 25
	end

	function initializer:IsExpanded()
		return isSearchActive() or (self.data and self.data.expanded ~= false)
	end

	local origInitFrame = initializer.InitFrame
	function initializer:InitFrame(frame)
		self.data.name = self.data.nameGetter()
		origInitFrame(self, frame)

		local function applyVisuals(expanded)
			if frame.Button and frame.Button.Right then
				frame.Button.Right:SetAtlas(
					expanded and "Options_ListExpand_Right_Expanded" or "Options_ListExpand_Right",
					TextureKitConstants.UseAtlasSize
				)
			end

			if frame.Button and frame.Button.Text then
				local color = expanded and HIGHLIGHT_FONT_COLOR or DISABLED_FONT_COLOR
				frame.Button.Text:SetTextColor(color:GetRGB())
			end
		end

		function frame:OnExpandedChanged(expanded)
			applyVisuals(self:GetElementData():IsExpanded())
			refreshSettingsLayout()
		end

		function frame:CalculateHeight()
			local elementData = self:GetElementData()
			return elementData:GetExtent()
		end

		applyVisuals(self:IsExpanded())
	end

	addSearchTags(initializer, data.searchtags, resolvedName)
	Settings.RegisterInitializer(cat, initializer)
	State.elements[data.key or resolvedName] = initializer

	return initializer, function()
		return initializer:IsExpanded()
	end
end

local function normalizeNameData(text, extra)
	local data = {}
	if type(text) == "table" then
		for k, v in pairs(text) do
			data[k] = v
		end
	else
		data.name = text
	end

	if type(extra) == "table" then
		for k, v in pairs(extra) do
			data[k] = v
		end
	end

	data.name = data.name or data.text or text
	return data
end

function lib:CreateHeader(cat, text, extra)
	local data = normalizeNameData(text, extra)
	local name = data.name or data.text
	local init = Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", { name = name })
	addSearchTags(init, data.searchtags or name, name)
	applyParentInitializer(init, data.parent, data.parentCheck)
	applyExpandablePredicate(init, data)
	Settings.RegisterInitializer(cat, init)
	return init
end

function lib:CreateText(cat, text, extra)
	local data = normalizeNameData(text, extra)
	local name = data.name or data.text
	local init = Settings.CreateElementInitializer(
		"LibEQOL@project-abbreviated-hash@_SettingsListSectionHintTemplate",
		{ name = name }
	)
	addSearchTags(init, data.searchtags or name, name)
	applyParentInitializer(init, data.parent, data.parentCheck)
	applyExpandablePredicate(init, data)
	Settings.RegisterInitializer(cat, init)
	return init
end

function lib:CreateButton(cat, data)
	assert(cat and data and data.text, "category and data.text required")
	local btn =
		CreateSettingsButtonInitializer("", data.text, data.click or data.func, data.desc, data.searchtags or false)
	SettingsPanel:GetLayout(cat):AddInitializer(btn)
	applyParentInitializer(btn, data.parent, data.parentCheck)
	applyExpandablePredicate(btn, data)
	State.elements[data.key or data.text] = btn
	return btn
end

function lib:CreateKeybind(cat, data)
	assert(cat and data and data.bindingIndex, "category and data.bindingIndex required")
	local initializer =
		Settings.CreateElementInitializer("KeyBindingFrameBindingTemplate", { bindingIndex = data.bindingIndex })
	addSearchTags(initializer, data.searchtags, data.name or data.text)
	applyParentInitializer(initializer, data.parent, data.parentCheck)
	applyExpandablePredicate(initializer, data)
	Settings.RegisterInitializer(cat, initializer)
	State.elements[data.key or ("Binding_" .. tostring(data.bindingIndex))] = initializer
	return initializer
end

function lib:GetCategory(name)
	return State.categories[name]
end

function lib:GetElement(key)
	return State.elements[key]
end

function lib:SetVariablePrefix(prefix)
	if type(prefix) == "string" and prefix ~= "" then
		if State.prefixSet and prefix ~= State.prefix then
			error(
				("LibEQOLSettingsMode: prefix already set to '%s'; refusing to change to '%s'. Use data.prefix per control if you need multiple namespaces."):format(
					tostring(State.prefix),
					tostring(prefix)
				)
			)
		end
		State.prefix = prefix
		State.prefixSet = true
	end
end

function lib:AttachNotify(target, tag)
	attachNotify(target, tag)
end

function lib:GetVariablePrefix()
	return State.prefix
end
function lib:SetNewTagResolverForPrefix(prefix, resolver)
	if type(prefix) ~= "string" or prefix == "" then
		error("SetNewTagResolverForPrefix requires a non-empty prefix")
	end
	if resolver == nil then
		State.newTagResolvers[prefix] = nil
	else
		State.newTagResolvers[prefix] = resolver
	end
	hookNewTag()
end
