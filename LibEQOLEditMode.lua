local MODULE_MAJOR, BASE_MAJOR, MINOR = "LibEQOLEditMode-1.0", "LibEQOL-1.0", 1
local LibStub = _G.LibStub
assert(LibStub, MODULE_MAJOR .. " requires LibStub")

-- Primary sublib name; BASE_MAJOR remains as an alias for existing callers.
local moduleLib, moduleMinor = LibStub:GetLibrary(MODULE_MAJOR, true)
local baseLib, baseMinor = LibStub:GetLibrary(BASE_MAJOR, true)
local lib = moduleLib or baseLib
local oldMinor = moduleMinor or baseMinor

if baseMinor and (not oldMinor or baseMinor > oldMinor) then
	lib, oldMinor = baseLib, baseMinor
end

if oldMinor and oldMinor >= MINOR then
	LibStub.libs[MODULE_MAJOR] = lib
	LibStub.minors[MODULE_MAJOR] = oldMinor
	LibStub.libs[BASE_MAJOR] = lib
	LibStub.minors[BASE_MAJOR] = oldMinor
	return
end

if not lib then
	lib = LibStub:NewLibrary(MODULE_MAJOR, MINOR)
else
	LibStub.libs[MODULE_MAJOR] = lib
	LibStub.minors[MODULE_MAJOR] = MINOR
end
LibStub.libs[BASE_MAJOR] = lib
LibStub.minors[BASE_MAJOR] = MINOR

-- Namespaces/state ----------------------------------------------------------------
lib.internal = lib.internal or {}
local Internal = lib.internal

local State = {
	selectionRegistry = lib.selectionRegistry or {},
	frameHandlers = lib.frameHandlers or {},
	defaultPositions = lib.defaultPositions or {},
	settingSheets = lib.settingSheets or {},
	buttonSpecs = lib.buttonSpecs or {},
	resetToggles = lib.resetToggles or {},
	collapseFlags = lib.collapseFlags or {},
	widgetPools = lib.widgetPools or {},
	overlayToggleFlags = lib.overlayToggleFlags or {},
	layoutSnapshot = Internal.layoutNameSnapshot,
}

lib.selectionRegistry = State.selectionRegistry
lib.frameHandlers = State.frameHandlers
lib.defaultPositions = State.defaultPositions
lib.settingSheets = State.settingSheets
lib.buttonSpecs = State.buttonSpecs
lib.resetToggles = State.resetToggles
lib.collapseFlags = State.collapseFlags
lib.widgetPools = State.widgetPools
lib.overlayToggleFlags = State.overlayToggleFlags

-- frequently used globals ----------------------------------------------------------
local CreateFrame = _G.CreateFrame
local CopyTable = _G.CopyTable
local Mixin = _G.Mixin
local InCombatLockdown = _G.InCombatLockdown
local IsShiftKeyDown = _G.IsShiftKeyDown
local CreateUnsecuredObjectPool = _G.CreateUnsecuredObjectPool
local hooksecurefunc = _G.hooksecurefunc
local securecallfunction = _G.securecallfunction
local UIParent = _G.UIParent
local EventRegistry = _G.EventRegistry
local GameTooltip = _G.GameTooltip
local GameTooltip_Hide = _G.GameTooltip_Hide
local ColorPickerFrame = _G.ColorPickerFrame
local SOUNDKIT = _G.SOUNDKIT
local Enum = _G.Enum
local EditModeManagerFrame = _G.EditModeManagerFrame
local GenerateClosure = _G.GenerateClosure
local MinimalSliderWithSteppersMixin = _G.MinimalSliderWithSteppersMixin
local CreateMinimalSliderFormatter = _G.CreateMinimalSliderFormatter
local GetBuildInfo = _G.GetBuildInfo
local PlaySound = _G.PlaySound
local math = _G.math
local tostring = _G.tostring
local type = _G.type
local pairs = _G.pairs
local ipairs = _G.ipairs
local select = _G.select
local next = _G.next
local table = _G.table
local UIErrorsFrame = _G.UIErrorsFrame

local C_EditMode = _G.C_EditMode
local C_EditMode_GetLayouts = C_EditMode and C_EditMode.GetLayouts
local C_EditMode_ConvertLayoutInfoToString = C_EditMode and C_EditMode.ConvertLayoutInfoToString
local C_SpecializationInfo = _G.C_SpecializationInfo
local GetSpecialization = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization

-- layout names are lazily resolved so we do not need early API availability
local layoutNames = lib.layoutNames
	or setmetatable({ "Modern", "Classic" }, {
		__index = function(t, key)
			if key <= 2 then
				return rawget(t, key)
			end
			local layouts = C_EditMode_GetLayouts and C_EditMode_GetLayouts()
			layouts = layouts and layouts.layouts
			if not layouts then
				return nil
			end
			local idx = key - 2
			return layouts[idx] and layouts[idx].layoutName
		end,
	})
lib.layoutNames = layoutNames

-- Setting types: we keep Blizzard enums but extend for custom widgets
lib.SettingType = lib.SettingType or CopyTable(Enum.EditModeSettingDisplayType)
lib.SettingType.Color = "Color"
lib.SettingType.CheckboxColor = "CheckboxColor"
lib.SettingType.DropdownColor = "DropdownColor"
lib.SettingType.MultiDropdown = "MultiDropdown"
lib.SettingType.Divider = "Divider"
lib.SettingType.Collapsible = "Collapsible"

-- Debug toggle lives on internal; defaults to false
Internal.debugEnabled = Internal.debugEnabled or false

-- Utilities -----------------------------------------------------------------------
local Util = {}

function Util:DebugTraceDialogChildren(label)
	if not Internal.debugEnabled then
		return
	end
	local dlg = Internal.dialog
	if not dlg or not dlg.Settings then
		print("[LibEQOL] Debug", label or "", "dialog/settings missing")
		return
	end
	local shown, total = 0, 0
	for _, child in ipairs({ dlg.Settings:GetChildren() }) do
		total = total + 1
		if child:IsShown() then
			shown = shown + 1
		end
	end
	print(string.format("[LibEQOL] Debug %s: %d shown / %d total children", label or "", shown, total))
end
Internal.DebugTraceDialogChildren = Util.DebugTraceDialogChildren

function Util:SortMixedKeys(keys)
	table.sort(keys, function(a, b)
		local ta, tb = type(a), type(b)
		if ta == tb then
			if ta == "number" or ta == "string" then
				return a < b
			end
			return tostring(a) < tostring(b)
		end
		if ta == "number" then
			return true
		end
		if tb == "number" then
			return false
		end
		return tostring(a) < tostring(b)
	end)
	return keys
end

local function cloneOption(option, fallback)
	local cloned = {}
	if type(option) == "table" then
		for k, v in pairs(option) do
			cloned[k] = v
		end
	else
		cloned.value = option
	end
	if cloned.value == nil and fallback ~= nil then
		cloned.value = fallback
	end
	local defaultLabel = cloned.text or cloned.label or tostring(cloned.value or "")
	cloned.label = cloned.label or defaultLabel
	cloned.text = cloned.text or defaultLabel
	if cloned.value == nil then
		cloned.value = cloned.text
	end
	return cloned
end

function Util:NormalizeOptions(list)
	if type(list) ~= "table" then
		return {}
	end
	local normalized = {}
	if #list > 0 then
		for _, option in ipairs(list) do
			table.insert(normalized, cloneOption(option))
		end
	else
		local keys = {}
		for key in pairs(list) do
			table.insert(keys, key)
		end
		self:SortMixedKeys(keys)
		for _, key in ipairs(keys) do
			table.insert(normalized, cloneOption(list[key], key))
		end
	end
	return normalized
end

function Util:NormalizeSelection(value)
	local map = {}
	if type(value) == "table" then
		if #value > 0 then
			for _, entry in ipairs(value) do
				map[entry] = true
			end
		else
			for key, state in pairs(value) do
				if state then
					map[key] = true
				end
			end
		end
	elseif value ~= nil then
		map[value] = true
	end
	return map
end

function Util:CopySelectionMap(map)
	local copy = {}
	if type(map) ~= "table" then
		return copy
	end
	for key, state in pairs(map) do
		if state then
			copy[key] = true
		end
	end
	return copy
end

function Util:ApplyTooltip(widget, target, tooltip)
	target = target or widget
	if not (target and target.SetScript) then
		return
	end
	target:SetScript("OnEnter", nil)
	target:SetScript("OnLeave", nil)
	if not tooltip or tooltip == "" then
		return
	end
	target:EnableMouse(true)
	target:SetScript("OnEnter", function()
		GameTooltip:SetOwner(target, "ANCHOR_RIGHT")
		GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
		GameTooltip:Show()
	end)
	target:SetScript("OnLeave", GameTooltip_Hide)
end

local function resolveOptions(data, layoutName)
	if not data then
		return {}
	end
	if data.optionfunc then
		local ok, result = pcall(data.optionfunc, layoutName)
		if ok and type(result) == "table" then
			return Util:NormalizeOptions(result)
		end
	end
	if type(data.options) == "table" then
		return Util:NormalizeOptions(data.options)
	end
	if type(data.values) == "table" then
		return Util:NormalizeOptions(data.values)
	end
	return {}
end

local function evaluateVisibility(data)
	if not data then
		return true
	end
	local layoutName, layoutIndex = lib.activeLayoutName, lib:GetActiveLayoutIndex()
	if data.isShown then
		local ok, result = pcall(data.isShown, layoutName, layoutIndex)
		if ok and result == false then
			return false
		end
	elseif data.hidden then
		local ok, result = pcall(data.hidden, layoutName, layoutIndex)
		if ok and result == true then
			return false
		end
	end
	return true
end

local function updateLabelVisibility(selection, hidden)
	if not selection then
		return
	end
	selection.labelHidden = not not hidden
	if selection.Label then
		selection.Label:SetAlpha(hidden and 0 or 1)
	end
	if selection.Text then
		selection.Text:SetAlpha(hidden and 0 or 1)
	end
end

local function updateOverlayVisibility(selection, hidden)
	if not selection then
		return
	end
	selection.overlayHidden = not not hidden
	selection.overlayAlphas = selection.overlayAlphas or {}
	for _, region in ipairs({ selection:GetRegions() }) do
		if region.GetObjectType and region:GetObjectType() == "Texture" then
			if hidden then
				if selection.overlayAlphas[region] == nil then
					selection.overlayAlphas[region] = region:GetAlpha() or 1
				end
				region:SetAlpha(0)
			else
				local alpha = selection.overlayAlphas[region]
				region:SetAlpha(alpha ~= nil and alpha or 1)
			end
		end
	end
end

local function updateSelectionVisuals(selection, hidden)
	if hidden == nil and selection then
		hidden = selection.overlayHidden
	end
	updateLabelVisibility(selection, hidden)
	updateOverlayVisibility(selection, hidden)
end

-- Layout helpers ------------------------------------------------------------------
local Layout = {}
local LFG_EYE_TEXTURE = [[Interface\LFGFrame\LFG-Eye]]
local LFG_EYE_FRAME_OPEN = 0
local LFG_EYE_FRAME_CLOSED = 4
local LFG_EYE_FRAME_WIDTH = 64
local LFG_EYE_FRAME_HEIGHT = 64
local LFG_EYE_TEXTURE_WIDTH = 512
local LFG_EYE_TEXTURE_HEIGHT = 256

local function setEyeFrame(tex, frameIndex)
	if not tex or not frameIndex then
		return
	end
	local cols = LFG_EYE_TEXTURE_WIDTH / LFG_EYE_FRAME_WIDTH
	local col = frameIndex % cols
	local row = math.floor(frameIndex / cols)

	local left = (col * LFG_EYE_FRAME_WIDTH) / LFG_EYE_TEXTURE_WIDTH
	local right = ((col + 1) * LFG_EYE_FRAME_WIDTH) / LFG_EYE_TEXTURE_WIDTH
	local top = (row * LFG_EYE_FRAME_HEIGHT) / LFG_EYE_TEXTURE_HEIGHT
	local bottom = ((row + 1) * LFG_EYE_FRAME_HEIGHT) / LFG_EYE_TEXTURE_HEIGHT

	tex:SetTexCoord(left, right, top, bottom)
end

local function updateEyeButton(eyeButton, hidden)
	if not eyeButton then
		return
	end
	local tex = eyeButton:GetNormalTexture()
	if tex then
		tex:SetTexture(LFG_EYE_TEXTURE)
		setEyeFrame(tex, hidden and LFG_EYE_FRAME_CLOSED or LFG_EYE_FRAME_OPEN)
		tex:SetDesaturated(false)
	end
end

local function snapshotLayoutNames(layoutInfo)
	if not (layoutInfo and layoutInfo.layouts) then
		return {}
	end
	local snapshot = {}
	for index, info in ipairs(layoutInfo.layouts) do
		if info and info.layoutName then
			snapshot[index] = info.layoutName
		end
	end
	return snapshot
end

local function updateActiveLayoutFromAPI()
	if not C_EditMode or not C_EditMode.GetLayouts then
		return
	end
	local layouts = C_EditMode.GetLayouts()
	if layouts and layouts.activeLayout then
		lib.activeLayoutIndex = layouts.activeLayout
		lib.activeLayoutName = layoutNames[layouts.activeLayout]
	end
	State.layoutSnapshot = snapshotLayoutNames(layouts)
	Internal.layoutNameSnapshot = State.layoutSnapshot
end

if not lib.activeLayoutName and C_EditMode and C_EditMode.GetLayouts then
	local layouts = C_EditMode.GetLayouts()
	if layouts and layouts.activeLayout then
		lib.activeLayoutIndex = layouts.activeLayout
		lib.activeLayoutName = layoutNames[layouts.activeLayout]
	end
	State.layoutSnapshot = snapshotLayoutNames(layouts)
	Internal.layoutNameSnapshot = State.layoutSnapshot
end

function Layout:HandleLayoutsChanged(_, layoutInfo)
	local layoutIndex = layoutInfo and layoutInfo.activeLayout
	if not layoutIndex then
		updateActiveLayoutFromAPI()
	end
	layoutIndex = layoutIndex or lib.activeLayoutIndex
	local layoutName = layoutIndex and layoutNames[layoutIndex] or layoutNames[lib.activeLayoutIndex]

	local newSnapshot = snapshotLayoutNames(layoutInfo)
	local oldSnapshot = State.layoutSnapshot or {}
	for index, newName in pairs(newSnapshot) do
		local oldName = oldSnapshot[index]
		if oldName and newName and oldName ~= newName then
			for _, callback in next, lib.eventHandlersLayoutRenamed do
				securecallfunction(callback, oldName, newName, index)
			end
		end
	end
	State.layoutSnapshot = newSnapshot
	Internal.layoutNameSnapshot = State.layoutSnapshot

	if layoutName and layoutIndex and (layoutName ~= lib.activeLayoutName or layoutIndex ~= lib.activeLayoutIndex) then
		lib.activeLayoutName = layoutName
		lib.activeLayoutIndex = layoutIndex
		for _, callback in next, lib.eventHandlersLayout do
			securecallfunction(callback, layoutName, layoutIndex)
		end
	end
end

function Layout:HandleSpecChanged()
	if C_EditMode and C_EditMode.GetLayouts then
		local layouts = C_EditMode.GetLayouts()
		self:HandleLayoutsChanged(nil, layouts)
	end
	for _, callback in next, lib.eventHandlersSpec do
		local specID = GetSpecialization and GetSpecialization()
		securecallfunction(callback, specID)
	end
end

function Layout:HandleLayoutDeleted(deletedLayoutIndex)
	for _, callback in next, lib.eventHandlersLayoutDeleted do
		securecallfunction(callback, deletedLayoutIndex)
	end
end

function Layout:HandleLayoutAdded(addedLayoutIndex, activateNewLayout, isLayoutImported)
	local layoutType
	if C_EditMode_GetLayouts then
		local info = C_EditMode_GetLayouts()
		local entry = info and info.layouts and info.layouts[addedLayoutIndex - 2]
		if entry and entry.layoutType then
			layoutType = entry.layoutType
		end
	end
	for _, callback in next, lib.eventHandlersLayoutAdded do
		securecallfunction(callback, addedLayoutIndex, activateNewLayout, isLayoutImported, layoutType)
	end

	-- Detect duplicates by serializing and comparing layout info
	if C_EditMode_GetLayouts and C_EditMode_ConvertLayoutInfoToString then
		local layoutInfo = C_EditMode_GetLayouts()
		if layoutInfo and layoutInfo.layouts then
			local customIndex = addedLayoutIndex - 2
			local newLayout = layoutInfo.layouts[customIndex]
			if newLayout then
				local newString = C_EditMode_ConvertLayoutInfoToString(newLayout)
				local newName = newLayout.layoutName
				if newString and newString ~= "" then
					local dupes = {}
					for idx, info in ipairs(layoutInfo.layouts) do
						if idx ~= customIndex then
							local str = C_EditMode_ConvertLayoutInfoToString(info)
							if str == newString or (newName and info.layoutName == newName) then
								table.insert(dupes, idx + 2) -- convert to UI indices
							end
						end
					end
					if #dupes > 0 then
						for _, callback in next, lib.eventHandlersLayoutDuplicate do
							securecallfunction(callback, addedLayoutIndex, dupes, isLayoutImported, layoutType)
						end
					end
				end
			end
		end
	end
end

-- Pools ----------------------------------------------------------------------------
local Pools = {}

function Pools:Create(kind, creator, resetter)
	local pool = CreateUnsecuredObjectPool(creator, resetter)
	local acquire = pool.Acquire
	pool.Acquire = function(poolObj, parent)
		local obj, new = acquire(poolObj)
		if parent then
			obj:SetParent(parent)
		end
		return obj, new
	end
	State.widgetPools[kind] = pool
	return pool
end

function Pools:Get(kind)
	return State.widgetPools[kind]
end

function Pools:ReleaseAll()
	for _, pool in next, State.widgetPools do
		pool:ReleaseAll()
	end
	if Internal.dialog and Internal.dialog.Settings then
		for _, child in ipairs({ Internal.dialog.Settings:GetChildren() }) do
			if child ~= Internal.dialog.Settings.ResetButton and child ~= Internal.dialog.Settings.Divider then
				child.ignoreInLayout = true
				if child.Hide then
					child:Hide()
				end
				if child.SetParent then
					child:SetParent(nil)
				end
			end
		end
	end
	Util:DebugTraceDialogChildren("ReleaseAllPools")
end

-- compatibility shims for callers that expect lib.internal pool helpers
function Internal:CreatePool(kind, creator, resetter)
	return Pools:Create(kind, creator, resetter)
end
function Internal:GetPool(kind)
	return Pools:Get(kind)
end
function Internal:ReleaseAllPools()
	return Pools:ReleaseAll()
end

-- Collapse state -------------------------------------------------------------------
local Collapse = {}

function Collapse:Get(frame, groupId)
	local layout = lib.activeLayoutName or "Default"
	local byFrame = State.collapseFlags[frame]
	local byLayout = byFrame and byFrame[layout]
	return byLayout and byLayout[groupId]
end

function Collapse:Set(frame, groupId, collapsed)
	local layout = lib.activeLayoutName or "Default"
	State.collapseFlags[frame] = State.collapseFlags[frame] or {}
	State.collapseFlags[frame][layout] = State.collapseFlags[frame][layout] or {}
	State.collapseFlags[frame][layout][groupId] = not not collapsed
end

-- compatibility helpers for legacy internal calls
function Internal:GetCollapseState(frame, groupId)
	return Collapse:Get(frame, groupId)
end
function Internal:SetCollapseState(frame, groupId, collapsed)
	return Collapse:Set(frame, groupId, collapsed)
end

-- Widget factory -------------------------------------------------------------------
local Widgets = {}
local SUMMARY_CHAR_LIMIT = 80

local function buildCheckbox()
	local mixin = {}

	function mixin:Setup(data)
		self.setting = data
		self.Label:SetText(data.name)
		local value = data.get(lib.activeLayoutName, lib:GetActiveLayoutIndex())
		if value == nil then
			value = data.default
		end
		self.checked = value
		self.Button:SetChecked(not not value)
		Util:ApplyTooltip(self, self, data.tooltip)
	end

	function mixin:OnCheckButtonClick()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		self.checked = not self.checked
		self.setting.set(lib.activeLayoutName, not not self.checked, lib:GetActiveLayoutIndex())
		Internal:RefreshSettings()
	end

	function mixin:SetEnabled(enabled)
		self.Button:SetEnabled(enabled)
		self.Label:SetFontObject(enabled and "GameFontHighlightMedium" or "GameFontDisable")
	end

	return function()
		local frame = CreateFrame("Frame", nil, UIParent, "EditModeSettingCheckboxTemplate")
		return Mixin(frame, mixin)
	end, function(_, frame)
		frame:Hide()
		frame.layoutIndex = nil
	end
end

local function dropdownGet(data)
	local val = data.value ~= nil and data.value or data.text
	return data.get(lib.activeLayoutName, lib:GetActiveLayoutIndex()) == val
end

local function dropdownSet(data)
	local val = data.value ~= nil and data.value or data.text
	data.set(lib.activeLayoutName, val, lib:GetActiveLayoutIndex())
	Internal:RefreshSettings()
end

local function buildDropdown()
	local mixin = {}

	function mixin:Setup(data)
		self.setting = data
		self.Label:SetText(data.name)
		self.ignoreInLayout = nil

		if data.generator then
			self.Dropdown:SetupMenu(function(owner, rootDescription)
				pcall(data.generator, owner, rootDescription, data)
			end)
		elseif data.values then
			self.Dropdown:SetupMenu(function(_, rootDescription)
				if data.height then
					rootDescription:SetScrollMode(data.height)
				end
				for _, value in next, data.values do
					if value.isRadio then
						rootDescription:CreateRadio(value.text, dropdownGet, dropdownSet, {
							get = data.get,
							set = data.set,
							value = value.text,
						})
					else
						rootDescription:CreateCheckbox(value.text, dropdownGet, dropdownSet, {
							get = data.get,
							set = data.set,
							value = value.text,
						})
					end
				end
			end)
		end

		Util:ApplyTooltip(self, self.Dropdown, data.tooltip)
	end

	function mixin:SetEnabled(enabled)
		self.Dropdown:SetEnabled(enabled)
		self.Label:SetFontObject(enabled and "GameFontHighlightMedium" or "GameFontDisable")
	end

	return function()
		local frame = CreateFrame("Frame", nil, UIParent, "ResizeLayoutFrame")
		frame.fixedHeight = 32
		Mixin(frame, mixin)

		local label = frame:CreateFontString(nil, nil, "GameFontHighlightMedium")
		label:SetPoint("LEFT")
		label:SetWidth(100)
		label:SetJustifyH("LEFT")
		frame.Label = label

		local dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
		dropdown:SetPoint("LEFT", label, "RIGHT", 5, 0)
		dropdown:SetSize(200, 30)
		frame.Dropdown = dropdown

		return frame
	end, function(_, frame)
		frame:Hide()
		frame.layoutIndex = nil
	end
end

local function buildMultiDropdown()
	local mixin = {}

	function mixin:Setup(data)
		self.setting = data
		self.ignoreInLayout = nil
		self.summaryAnchored = nil
		self.summaryMeasure = nil
		self.hideSummary = data.hideSummary or data.noSummary or data.summary == false

		self.Label:SetText(data.name)
		self.Dropdown:SetDefaultText(CUSTOM)

		local targetHeight = self.hideSummary and 32 or 48
		self.fixedHeight = targetHeight
		self:SetHeight(targetHeight)
		if self.hideSummary and self.Summary then
			self.Summary:Hide()
		end

		self.Dropdown:SetupMenu(function(_, rootDescription)
			if data.height then
				rootDescription:SetScrollMode(data.height)
			end
			for _, option in ipairs(resolveOptions(data, lib.activeLayoutName)) do
				if option.value ~= nil then
					local label = option.label or option.text or tostring(option.value)
					rootDescription:CreateCheckbox(label, function()
						return self:IsSelected(option.value)
					end, function()
						self:ToggleOption(option.value)
					end, option)
				end
			end
		end)

		self:RefreshSummary()

		Util:ApplyTooltip(self, self.Dropdown, data.tooltip)
	end

	function mixin:GetSelectionMap()
		local selection = self.setting
			and self.setting.get
			and self.setting.get(lib.activeLayoutName, lib:GetActiveLayoutIndex())
		if selection == nil and self.setting then
			selection = self.setting.default
		end
		return Util:NormalizeSelection(selection)
	end

	function mixin:IsSelected(value)
		if value == nil then
			return false
		end
		if self.setting and self.setting.isSelected then
			return not not self.setting.isSelected(lib.activeLayoutName, value, lib:GetActiveLayoutIndex())
		end
		local map = self:GetSelectionMap()
		return map[value] == true
	end

	function mixin:SetSelected(value, shouldSelect)
		if not self.setting then
			return
		end
		if self.setting.setSelected then
			self.setting.setSelected(lib.activeLayoutName, value, shouldSelect, lib:GetActiveLayoutIndex())
		elseif self.setting.set then
			local map = self:GetSelectionMap()
			map[value] = shouldSelect and true or nil
			self.setting.set(lib.activeLayoutName, map, lib:GetActiveLayoutIndex())
		end
		Internal:RefreshSettings()
	end

	function mixin:ToggleOption(value)
		self:SetSelected(value, not self:IsSelected(value))
		self:RefreshSummary()
	end

	function mixin:EnsureSummaryAnchors()
		if self.summaryAnchored or not (self.Summary and self.Dropdown) or self.hideSummary then
			return
		end
		self.summaryAnchored = true
		self.Summary:ClearAllPoints()
		self.Summary:SetPoint("TOPLEFT", self.Dropdown, "BOTTOMLEFT", 0, -2)
		self.Summary:SetPoint("TOPRIGHT", self.Dropdown, "BOTTOMRIGHT", 0, -2)
		self.Summary:SetWidth(self.Dropdown:GetWidth())
	end

	function mixin:GetSummaryWidthLimit()
		if self.Dropdown then
			return self.Dropdown:GetWidth()
		end
		if self.Summary then
			return self.Summary:GetWidth()
		end
	end

	function mixin:GetSummaryMeasureFontString()
		if self.summaryMeasure and self.summaryMeasure:IsObjectType("FontString") then
			return self.summaryMeasure
		end
		if not self.Summary then
			return nil
		end
		local fs = self.Summary:GetParent():CreateFontString(nil, "OVERLAY")
		if not fs then
			return nil
		end
		fs:SetFontObject(self.Summary:GetFontObject())
		fs:Hide()
		fs:SetWordWrap(false)
		fs:SetNonSpaceWrap(false)
		fs:SetSpacing(0)
		self.summaryMeasure = fs
		return fs
	end

	function mixin:WouldExceedSummaryWidth(text, widthLimit)
		if not text or text == "" then
			return false
		end
		if not widthLimit then
			return #text > SUMMARY_CHAR_LIMIT
		end
		local measure = self:GetSummaryMeasureFontString()
		if not measure then
			return #text > SUMMARY_CHAR_LIMIT
		end
		measure:SetFontObject(self.Summary:GetFontObject())
		measure:SetText(text)
		local getWidth = measure.GetUnboundedStringWidth or measure.GetStringWidth
		return getWidth(measure) > widthLimit
	end

	function mixin:FormatSummaryText(texts)
		if #texts == 0 then
			return "–"
		end
		local widthLimit = self:GetSummaryWidthLimit()
		local summary = ""
		local overflow = 0
		for index, text in ipairs(texts) do
			local candidate = (summary == "") and text or (summary .. ", " .. text)
			if widthLimit and summary ~= "" and self:WouldExceedSummaryWidth(candidate, widthLimit) then
				overflow = #texts - index + 1
				break
			elseif widthLimit and summary == "" and self:WouldExceedSummaryWidth(candidate, widthLimit) then
				summary = text
				overflow = #texts - index
				break
			else
				summary = candidate
			end
		end
		if overflow > 0 then
			local overflowText = (" … (+%d)"):format(overflow)
			local candidate = summary .. overflowText
			if widthLimit and self:WouldExceedSummaryWidth(candidate, widthLimit) then
				candidate = summary .. " …"
			end
			summary = candidate
		end
		if not widthLimit and #summary > SUMMARY_CHAR_LIMIT then
			summary = summary:sub(1, SUMMARY_CHAR_LIMIT) .. " …"
		end
		return summary
	end

	function mixin:RefreshSummary()
		if self.hideSummary or not self.Summary then
			return
		end
		self:EnsureSummaryAnchors()
		local texts = {}
		for _, opt in ipairs(resolveOptions(self.setting, lib.activeLayoutName)) do
			if opt.value ~= nil and self:IsSelected(opt.value) then
				table.insert(texts, opt.text or tostring(opt.value))
			end
		end
		local summary = self:FormatSummaryText(texts)
		self.Summary:SetText(summary)
		local enabled = not self.Dropdown or self.Dropdown:IsEnabled()
		self.Summary:SetFontObject(enabled and "GameFontHighlightSmall" or "GameFontDisableSmall")
	end

	function mixin:SetEnabled(enabled)
		self.Dropdown:SetEnabled(enabled)
		self.Label:SetFontObject(enabled and "GameFontHighlightMedium" or "GameFontDisable")
		if self.Summary then
			self.Summary:SetFontObject(enabled and "GameFontHighlightSmall" or "GameFontDisableSmall")
		end
	end

	return function()
		local frame = CreateFrame("Frame", nil, UIParent, "ResizeLayoutFrame")
		frame.fixedHeight = 48
		frame:SetHeight(48)
		Mixin(frame, mixin)

		local label = frame:CreateFontString(nil, nil, "GameFontHighlightMedium")
		label:SetPoint("LEFT")
		label:SetWidth(100)
		label:SetJustifyH("LEFT")
		frame.Label = label

		local dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
		dropdown:SetPoint("LEFT", label, "RIGHT", 5, 0)
		dropdown:SetSize(200, 30)
		frame.Dropdown = dropdown

		local summary = frame:CreateFontString(nil, nil, "GameFontHighlightSmall")
		summary:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
		summary:SetPoint("TOPRIGHT", dropdown, "BOTTOMRIGHT", 0, -2)
		summary:SetJustifyH("LEFT")
		summary:SetText("–")
		frame.Summary = summary

		return frame
	end, function(_, frame)
		frame:Hide()
		frame.layoutIndex = nil
		frame.summaryAnchored = nil
		frame.summaryMeasure = nil
	end
end

local function normalizeColor(value)
	if type(value) == "table" then
		return value.r or value[1] or 1, value.g or value[2] or 1, value.b or value[3] or 1, value.a or value[4]
	elseif type(value) == "number" then
		return value, value, value
	end
	return 1, 1, 1
end

local function buildColor()
	local mixin = {}

	function mixin:Setup(data)
		self.setting = data
		self.Label:SetText(data.name)
		self.ignoreInLayout = nil
		local r, g, b, a = normalizeColor(data.get(lib.activeLayoutName, lib:GetActiveLayoutIndex()) or data.default)
		self.hasOpacity = not not (data.hasOpacity or a)
		self:SetColor(r, g, b, a)
	end

	function mixin:SetColor(r, g, b, a)
		self.r, self.g, self.b, self.a = r, g, b, a
		self.Swatch:SetColorTexture(r, g, b, 1)
	end

	function mixin:OnClick()
		local prev = { r = self.r or 1, g = self.g or 1, b = self.b or 1, a = self.a }
		ColorPickerFrame:SetupColorPickerAndShow({
			r = prev.r,
			g = prev.g,
			b = prev.b,
			opacity = prev.a,
			hasOpacity = self.hasOpacity,
			swatchFunc = function()
				local r, g, b = ColorPickerFrame:GetColorRGB()
				local a = self.hasOpacity
					and (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or prev.a)
				self:SetColor(r, g, b, a)
				self.setting.set(lib.activeLayoutName, { r = r, g = g, b = b, a = a }, lib:GetActiveLayoutIndex())
				Internal:RefreshSettings()
			end,
			opacityFunc = function()
				if not self.hasOpacity then
					return
				end
				local r, g, b = ColorPickerFrame:GetColorRGB()
				local a = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or prev.a
				self:SetColor(r, g, b, a)
				self.setting.set(lib.activeLayoutName, { r = r, g = g, b = b, a = a }, lib:GetActiveLayoutIndex())
				Internal:RefreshSettings()
			end,
			cancelFunc = function()
				self:SetColor(prev.r, prev.g, prev.b, prev.a)
				self.setting.set(
					lib.activeLayoutName,
					{ r = prev.r, g = prev.g, b = prev.b, a = prev.a },
					lib:GetActiveLayoutIndex()
				)
				Internal:RefreshSettings()
			end,
		})
	end

	function mixin:SetEnabled(enabled)
		if enabled then
			self.Button:Enable()
			self.Swatch:SetVertexColor(1, 1, 1, 1)
			self.Label:SetFontObject("GameFontHighlightMedium")
		else
			self.Button:Disable()
			self.Swatch:SetVertexColor(0.4, 0.4, 0.4, 1)
			self.Label:SetFontObject("GameFontDisable")
		end
	end

	return function()
		local frame = CreateFrame("Frame", nil, UIParent, "ResizeLayoutFrame")
		frame.fixedHeight = 32
		Mixin(frame, mixin)

		local label = frame:CreateFontString(nil, nil, "GameFontHighlightMedium")
		label:SetPoint("LEFT")
		label:SetWidth(100)
		label:SetJustifyH("LEFT")
		frame.Label = label

		local button = CreateFrame("Button", nil, frame)
		button:SetSize(36, 22)
		button:SetPoint("LEFT", label, "RIGHT", 8, 0)

		local border = button:CreateTexture(nil, "BACKGROUND")
		border:SetColorTexture(0.7, 0.7, 0.7, 1)
		border:SetAllPoints()

		local swatch = button:CreateTexture(nil, "ARTWORK")
		swatch:SetPoint("TOPLEFT", 2, -2)
		swatch:SetPoint("BOTTOMRIGHT", -2, 2)
		swatch:SetColorTexture(1, 1, 1, 1)
		frame.Swatch = swatch

		button:SetScript("OnClick", function()
			frame:OnClick()
		end)
		frame.Button = button

		return frame
	end, function(_, frame)
		frame:Hide()
		frame.layoutIndex = nil
	end
end

local function buildCheckboxColor()
	local mixin = {}

	function mixin:Setup(data)
		self.setting = data
		self.Label:SetText(data.name)
		self.ignoreInLayout = nil

		local value = data.get and data.get(lib.activeLayoutName, lib:GetActiveLayoutIndex())
		if value == nil then
			value = data.default
		end
		self.checked = not not value
		self.Check:SetChecked(self.checked)

		local colorVal
		if data.colorGet then
			colorVal = data.colorGet(lib.activeLayoutName, lib:GetActiveLayoutIndex())
		end
		if not colorVal then
			colorVal = data.colorDefault or { 1, 1, 1, 1 }
		end
		local r, g, b, a = normalizeColor(colorVal)
		self.hasOpacity = not not (data.hasOpacity or a)
		self:SetColor(r, g, b, a)
		self:UpdateColorEnabled()

		Util:ApplyTooltip(self, self, data.tooltip)
	end

	function mixin:UpdateColorEnabled()
		local enabled = self.checked
		if enabled then
			self.Button:Enable()
			self.Swatch:SetVertexColor(1, 1, 1, 1)
		else
			self.Button:Disable()
			self.Swatch:SetVertexColor(0.4, 0.4, 0.4, 1)
		end
	end

	function mixin:SetColor(r, g, b, a)
		self.r, self.g, self.b, self.a = r, g, b, a
		self.Swatch:SetColorTexture(r, g, b, 1)
	end

	function mixin:OnCheckboxClick()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		self.checked = not self.checked
		if self.setting.set then
			self.setting.set(lib.activeLayoutName, self.checked, lib:GetActiveLayoutIndex())
		end
		self:UpdateColorEnabled()
		Internal:RefreshSettings()
	end

	function mixin:OnColorClick()
		local prev = { r = self.r or 1, g = self.g or 1, b = self.b or 1, a = self.a }
		local apply = self.setting.colorSet or self.setting.setColor
		if not apply then
			return
		end
		ColorPickerFrame:SetupColorPickerAndShow({
			r = prev.r,
			g = prev.g,
			b = prev.b,
			opacity = prev.a,
			hasOpacity = self.hasOpacity,
			swatchFunc = function()
				local r, g, b = ColorPickerFrame:GetColorRGB()
				local a = self.hasOpacity
					and (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or prev.a)
				self:SetColor(r, g, b, a)
				apply(lib.activeLayoutName, { r = r, g = g, b = b, a = a }, lib:GetActiveLayoutIndex())
				Internal:RefreshSettings()
			end,
			opacityFunc = function()
				if not self.hasOpacity then
					return
				end
				local r, g, b = ColorPickerFrame:GetColorRGB()
				local a = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or prev.a
				self:SetColor(r, g, b, a)
				apply(lib.activeLayoutName, { r = r, g = g, b = b, a = a }, lib:GetActiveLayoutIndex())
				Internal:RefreshSettings()
			end,
			cancelFunc = function()
				self:SetColor(prev.r, prev.g, prev.b, prev.a)
				apply(
					lib.activeLayoutName,
					{ r = prev.r, g = prev.g, b = prev.b, a = prev.a },
					lib:GetActiveLayoutIndex()
				)
				Internal:RefreshSettings()
			end,
		})
	end

	function mixin:SetEnabled(enabled)
		self.Check:SetEnabled(enabled)
		if not enabled then
			self.Button:Disable()
			self.Swatch:SetVertexColor(0.2, 0.2, 0.2, 1)
			self.Label:SetFontObject("GameFontDisable")
		else
			self:UpdateColorEnabled()
			self.Label:SetFontObject("GameFontHighlightMedium")
		end
	end

	return function()
		local frame = CreateFrame("Frame", nil, UIParent, "ResizeLayoutFrame")
		frame.fixedHeight = 32
		Mixin(frame, mixin)

		local check = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
		check:SetPoint("LEFT", -5, 0)
		check:SetScript("OnClick", function(btn)
			btn:GetParent():OnCheckboxClick()
		end)
		frame.Check = check

		local label = frame:CreateFontString(nil, nil, "GameFontHighlightMedium")
		label:SetPoint("LEFT", check, "RIGHT", 2, 0)
		label:SetWidth(175)
		label:SetJustifyH("LEFT")
		frame.Label = label

		local button = CreateFrame("Button", nil, frame)
		button:SetSize(36, 22)
		button:SetPoint("LEFT", label, "RIGHT", 4, 0)

		local border = button:CreateTexture(nil, "BACKGROUND")
		border:SetColorTexture(0.7, 0.7, 0.7, 1)
		border:SetAllPoints()

		local swatch = button:CreateTexture(nil, "ARTWORK")
		swatch:SetPoint("TOPLEFT", 2, -2)
		swatch:SetPoint("BOTTOMRIGHT", -2, 2)
		swatch:SetColorTexture(1, 1, 1, 1)
		frame.Swatch = swatch

		button:SetScript("OnClick", function()
			frame:OnColorClick()
		end)
		frame.Button = button

		return frame
	end, function(_, frame)
		frame:Hide()
		frame.layoutIndex = nil
	end
end

local function buildDropdownColor()
	local mixin = {}

	function mixin:Setup(data)
		self.setting = data
		self.Label:SetText(data.name)
		self.ignoreInLayout = nil

		local function createEntries(rootDescription)
			if data.height then
				rootDescription:SetScrollMode(data.height)
			end
			local function getCurrent()
				return data.get(lib.activeLayoutName, lib:GetActiveLayoutIndex())
			end
			local function makeSetter(value)
				return function()
					data.set(lib.activeLayoutName, value, lib:GetActiveLayoutIndex())
					Internal:RefreshSettings()
				end
			end
			if data.values then
				for _, value in next, data.values do
					if value.isRadio then
						rootDescription:CreateRadio(value.text, function()
							return getCurrent() == value.text
						end, makeSetter(value.text))
					else
						rootDescription:CreateCheckbox(value.text, function()
							return getCurrent() == value.text
						end, makeSetter(value.text))
					end
				end
			end
		end

		if data.generator then
			self.Dropdown:SetupMenu(function(owner, rootDescription)
				pcall(data.generator, owner, rootDescription, data)
			end)
		elseif data.values then
			self.Dropdown:SetupMenu(function(_, rootDescription)
				createEntries(rootDescription)
			end)
		end

		local colorVal
		if data.colorGet then
			colorVal = data.colorGet(lib.activeLayoutName, lib:GetActiveLayoutIndex())
		end
		if not colorVal then
			colorVal = data.colorDefault or { 1, 1, 1, 1 }
		end
		local r, g, b, a = normalizeColor(colorVal)
		self.hasOpacity = not not (data.hasOpacity or a)
		self:SetColor(r, g, b, a)

		Util:ApplyTooltip(self, self, data.tooltip)
	end

	function mixin:SetColor(r, g, b, a)
		self.r, self.g, self.b, self.a = r, g, b, a
		self.Swatch:SetColorTexture(r, g, b, 1)
	end

	function mixin:OnColorClick()
		local prev = { r = self.r or 1, g = self.g or 1, b = self.b or 1, a = self.a }
		local apply = self.setting.colorSet or self.setting.setColor
		if not apply then
			return
		end
		ColorPickerFrame:SetupColorPickerAndShow({
			r = prev.r,
			g = prev.g,
			b = prev.b,
			opacity = prev.a,
			hasOpacity = self.hasOpacity,
			swatchFunc = function()
				local r, g, b = ColorPickerFrame:GetColorRGB()
				local a = self.hasOpacity
					and (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or prev.a)
				self:SetColor(r, g, b, a)
				apply(lib.activeLayoutName, { r = r, g = g, b = b, a = a }, lib:GetActiveLayoutIndex())
				Internal:RefreshSettings()
			end,
			opacityFunc = function()
				if not self.hasOpacity then
					return
				end
				local r, g, b = ColorPickerFrame:GetColorRGB()
				local a = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or prev.a
				self:SetColor(r, g, b, a)
				apply(lib.activeLayoutName, { r = r, g = g, b = b, a = a }, lib:GetActiveLayoutIndex())
				Internal:RefreshSettings()
			end,
			cancelFunc = function()
				self:SetColor(prev.r, prev.g, prev.b, prev.a)
				apply(
					lib.activeLayoutName,
					{ r = prev.r, g = prev.g, b = prev.b, a = prev.a },
					lib:GetActiveLayoutIndex()
				)
				Internal:RefreshSettings()
			end,
		})
	end

	function mixin:SetEnabled(enabled)
		self.Dropdown:SetEnabled(enabled)
		if enabled then
			self.Button:Enable()
			self.Swatch:SetVertexColor(1, 1, 1, 1)
			self.Label:SetFontObject("GameFontHighlightMedium")
		else
			self.Button:Disable()
			self.Swatch:SetVertexColor(0.4, 0.4, 0.4, 1)
			self.Label:SetFontObject("GameFontDisable")
		end
	end

	return function()
		local frame = CreateFrame("Frame", nil, UIParent, "ResizeLayoutFrame")
		frame.fixedHeight = 32
		Mixin(frame, mixin)

		local label = frame:CreateFontString(nil, nil, "GameFontHighlightMedium")
		label:SetPoint("LEFT")
		label:SetWidth(100)
		label:SetJustifyH("LEFT")
		frame.Label = label

		local dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
		dropdown:SetPoint("LEFT", label, "RIGHT", 5, 0)
		dropdown:SetSize(200, 30)
		frame.Dropdown = dropdown

		local button = CreateFrame("Button", nil, frame)
		button:SetSize(36, 22)
		button:SetPoint("LEFT", dropdown, "RIGHT", 6, 0)

		local border = button:CreateTexture(nil, "BACKGROUND")
		border:SetColorTexture(0.7, 0.7, 0.7, 1)
		border:SetAllPoints()

		local swatch = button:CreateTexture(nil, "ARTWORK")
		swatch:SetPoint("TOPLEFT", 2, -2)
		swatch:SetPoint("BOTTOMRIGHT", -2, 2)
		swatch:SetColorTexture(1, 1, 1, 1)
		frame.Swatch = swatch

		button:SetScript("OnClick", function()
			frame:OnColorClick()
		end)
		frame.Button = button

		return frame
	end, function(_, frame)
		frame:Hide()
		frame.layoutIndex = nil
	end
end

local function buildSlider()
	local mixin = {}

	function mixin:Setup(data)
		self.setting = data
		self.Label:SetText(data.name)
		self.ignoreInLayout = nil
		self.initInProgress = true
		self.formatters = {}
		self.formatters[MinimalSliderWithSteppersMixin.Label.Right] =
			CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right, data.formatter)

		local minV = tonumber(data.minValue) or 0
		local maxV = tonumber(data.maxValue) or 1
		if maxV < minV then
			minV, maxV = maxV, minV
		end

		local stepSize = tonumber(data.valueStep) or 1
		if stepSize <= 0 then
			local span = maxV - minV
			stepSize = span > 0 and (span / 100) or 1
		end
		local steps = (maxV - minV) / stepSize
		if steps < 1 then
			steps = 1
		end

		local current = tonumber(data.get(lib.activeLayoutName, lib:GetActiveLayoutIndex()))
			or tonumber(data.default)
			or minV
		if current < minV then
			current = minV
		end
		if current > maxV then
			current = maxV
		end
		self.currentValue = current
		self.Slider:Init(current, minV, maxV, steps, self.formatters)

		if self.Input then
			if data.allowInput then
				self.Input:Show()
				self.Input:SetNumeric(false)
				self.Input:SetText(tostring(current or ""))
				if self.Slider.RightText then
					self.Slider.RightText:Hide()
				end
			else
				self.Input:Hide()
				if self.Slider.RightText then
					self.Slider.RightText:Show()
				end
			end
		end

		self.initInProgress = false
		Util:ApplyTooltip(self, self, data.tooltip)
	end

	function mixin:OnSliderValueChanged(value)
		if not self.initInProgress then
			self.setting.set(lib.activeLayoutName, value, lib:GetActiveLayoutIndex())
			self.currentValue = value
			if self.Input and self.Input:IsShown() then
				self.Input:SetText(tostring(value))
				if self.Slider.RightText then
					self.Slider.RightText:Hide()
				end
			end
			Internal:RefreshSettings()
		end
	end

	function mixin:SetEnabled(enabled)
		self.Slider:SetEnabled(enabled)
		self.Label:SetFontObject(enabled and "GameFontHighlight" or "GameFontDisable")
		if self.Input then
			if enabled then
				self.Input:Enable()
			else
				self.Input:Disable()
			end
		end
	end

	return function()
		local frame = CreateFrame("Frame", nil, UIParent, "EditModeSettingSliderTemplate")
		Mixin(frame, mixin)

		frame:SetHeight(32)
		frame.Slider:SetWidth(200)
		frame.Slider.MinText:Hide()
		frame.Slider.MaxText:Hide()
		frame.Label:SetPoint("LEFT")

		local input = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
		input:SetAutoFocus(false)
		input:SetSize(34, 20)
		input:SetJustifyH("CENTER")
		input:SetPoint("LEFT", frame.Slider, "RIGHT", 10, 0)
		input:Hide()
		frame.Input = input

		local function commitInput(box)
			if not box:IsEnabled() then
				return
			end
			local owner = box:GetParent()
			local data = owner.setting
			if not data then
				return
			end
			local minV = tonumber(data.minValue) or 0
			local maxV = tonumber(data.maxValue) or 1
			if maxV < minV then
				minV, maxV = maxV, minV
			end
			local step = tonumber(data.valueStep) or 0
			if step <= 0 then
				step = 0
			end
			local val = tonumber(box:GetText())
			if not val then
				box:SetText(tostring(owner.currentValue or ""))
				return
			end
			if val < minV then
				val = minV
			end
			if val > maxV then
				val = maxV
			end
			if step and step > 0 then
				val = minV + math.floor((val - minV) / step + 0.5) * step
				if val < minV then
					val = minV
				end
				if val > maxV then
					val = maxV
				end
			end
			owner.Input:SetText(val)
			owner.currentValue = val
			owner.Slider:SetValue(val)
			owner.setting.set(lib.activeLayoutName, val, lib:GetActiveLayoutIndex())
			Internal:RefreshSettings()
			box:ClearFocus()
		end

		input:SetScript("OnEnterPressed", commitInput)
		input:SetScript("OnEscapePressed", function(box)
			if box:GetParent() and box:GetParent().currentValue then
				box:SetText(tostring(box:GetParent().currentValue))
			end
			box:ClearFocus()
		end)
		input:SetScript("OnEditFocusLost", function(box)
			if box:HasFocus() then
				return
			end
			if box:GetText() ~= "" then
				commitInput(box)
			end
		end)

		frame:OnLoad()
		return frame
	end, function(_, frame)
		frame:Hide()
		frame.layoutIndex = nil
	end
end

local function buildDivider()
	return function()
		local frame = CreateFrame("Frame", nil, UIParent)
		frame.fixedHeight = 16
		frame:SetSize(330, 16)
		local tex = frame:CreateTexture(nil, "ARTWORK")
		tex:SetAllPoints()
		tex:SetTexture([[Interface\FriendsFrame\UI-FriendsFrame-OnlineDivider]])
		frame.Divider = tex
		function frame:Setup(data)
			self.setting = data
		end
		return frame
	end, function(_, frame)
		frame:Hide()
		frame.layoutIndex = nil
		frame.ignoreInLayout = nil
	end
end

local function buildCollapsible()
	return function()
		local button = CreateFrame("Button", nil, UIParent, "UIMenuButtonStretchTemplate")
		button.fixedHeight = 24
		button:SetSize(330, 24)
		local hl = button:GetHighlightTexture()
		if hl then
			hl:SetAlpha(0)
		end

		local label = button:CreateFontString(nil, nil, "GameFontNormal")
		label:SetPoint("LEFT", 10, 0)
		label:SetJustifyH("LEFT")
		label:SetWidth(270)
		button.Label = label

		local collapseIcon = button:CreateTexture(nil, "ARTWORK")
		collapseIcon:SetSize(16, 16)
		collapseIcon:SetPoint("RIGHT", -6, 0)
		button.CollapseIcon = collapseIcon

		local function updateIcon(collapsed)
			if collapsed then
				button.CollapseIcon:SetTexture([[Interface\Buttons\UI-PlusButton-Up]])
			else
				button.CollapseIcon:SetTexture([[Interface\Buttons\UI-MinusButton-Up]])
			end
		end

		function button:Setup(data, selection)
			self.setting = data
			self.selection = selection
			self.Label:SetText(data.name or "")

			local selectionParent = selection and selection.parent
			if not selectionParent and Internal.dialog and Internal.dialog.selection then
				selectionParent = Internal.dialog.selection.parent
			end

			local collapsed = not not data.defaultCollapsed
			local stored
			if selectionParent then
				stored = Collapse:Get(selectionParent, data.id or data.name)
			end
			if stored ~= nil then
				collapsed = not not stored
			end
			if data.getCollapsed then
				local ok, val = pcall(data.getCollapsed, lib.activeLayoutName, lib:GetActiveLayoutIndex())
				if ok and val ~= nil then
					collapsed = not not val
				end
			end
			if selectionParent and stored == nil and data.defaultCollapsed ~= nil then
				Collapse:Set(selectionParent, data.id or data.name, collapsed)
			end

			self.collapsed = collapsed
			updateIcon(collapsed)

			self:SetScript("OnClick", function()
				local newState = not self.collapsed
				self.collapsed = newState
				updateIcon(newState)
				if data.setCollapsed then
					data.setCollapsed(lib.activeLayoutName, newState, lib:GetActiveLayoutIndex())
				elseif selectionParent then
					Collapse:Set(selectionParent, data.id or data.name, newState)
				end
				Internal:RefreshSettings()
				Internal:RefreshSettingValues()
			end)
		end

		function button:SetEnabled(enabled)
			if enabled then
				self:Enable()
				self.Label:SetFontObject("GameFontNormal")
			else
				self:Disable()
				self.Label:SetFontObject("GameFontDisable")
			end
		end

		return button
	end, function(_, frame)
		frame:Hide()
		frame.layoutIndex = nil
		frame.ignoreInLayout = nil
		frame.selection = nil
		frame.setting = nil
		frame.collapsed = nil
		frame:SetScript("OnClick", nil)
	end
end

local function buildButton()
	return function()
		return CreateFrame("Button", nil, UIParent, "EditModeSystemSettingsDialogExtraButtonTemplate")
	end, function(_, frame)
		frame:Hide()
		frame.layoutIndex = nil
	end
end

-- Slider pool is used by checkbox+color / dropdown+color etc
local builders = {
	[lib.SettingType.Checkbox] = buildCheckbox,
	[lib.SettingType.Dropdown] = buildDropdown,
	[lib.SettingType.MultiDropdown] = buildMultiDropdown,
	[lib.SettingType.Slider] = buildSlider,
	[lib.SettingType.Color] = buildColor,
	[lib.SettingType.CheckboxColor] = buildCheckboxColor,
	[lib.SettingType.DropdownColor] = buildDropdownColor,
	[lib.SettingType.Divider] = buildDivider,
	[lib.SettingType.Collapsible] = buildCollapsible,
	button = buildButton,
}

for kind, maker in pairs(builders) do
	local creator, resetter = maker()
	Pools:Create(kind, creator, resetter)
end

-- Dialog ---------------------------------------------------------------------------
local Dialog = {}

local function saveDialogPosition(dialog)
	if not dialog then
		return
	end
	local point, _, relativePoint, x, y = dialog:GetPoint(1)
	if not point then
		return
	end
	Internal.dialogSavedPoint = {
		point = point,
		relativePoint = relativePoint or point,
		x = x or 0,
		y = y or 0,
	}
end

local function applyDialogPosition(dialog)
	if not dialog then
		return
	end
	dialog:ClearAllPoints()
	local pos = Internal.dialogSavedPoint
	if pos then
		dialog:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x or 0, pos.y or 0)
	else
		dialog:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -250, 250)
	end
end

local function setResetVisibility(buttonsFrame, visible)
	if not buttonsFrame then
		return
	end
	if visible then
		buttonsFrame.ignoreInLayout = nil
		buttonsFrame:Show()
	else
		buttonsFrame.ignoreInLayout = true
		buttonsFrame:Hide()
	end
end

function Dialog:Update(selection)
	self.selection = selection
	self.Title:SetText(selection.parent.editModeName or selection.parent:GetName())
	local allowOverlayToggle = State.overlayToggleFlags[selection.parent] == true
	if self.HideLabelButton then
		if allowOverlayToggle then
			self.HideLabelButton:Show()
			updateSelectionVisuals(selection, selection.overlayHidden)
			updateEyeButton(self.HideLabelButton, selection.overlayHidden)
		else
			self.HideLabelButton:Hide()
			updateSelectionVisuals(selection, false)
		end
	end
	self:UpdateSettings()
	self:UpdateButtons()
	if not self:IsShown() then
		applyDialogPosition(self)
	end
	self:Show()
	self:Layout()
end

function Dialog:UpdateSettings()
	Pools:ReleaseAll()
	local settings, num = Internal:GetFrameSettings(self.selection.parent)
	local collapsedById = {}
	if num > 0 then
		for _, data in next, settings do
			if data.kind == lib.SettingType.Collapsible then
				local selectionParent = self.selection and self.selection.parent
				if not selectionParent and Internal.dialog and Internal.dialog.selection then
					selectionParent = Internal.dialog.selection.parent
				end
				local collapsed = Collapse:Get(selectionParent, data.id or data.name)
				if collapsed == nil and data.defaultCollapsed ~= nil then
					collapsed = not not data.defaultCollapsed
				end
				if data.getCollapsed then
					local ok, val = pcall(data.getCollapsed, lib.activeLayoutName, lib:GetActiveLayoutIndex())
					if ok and val ~= nil then
						collapsed = not not val
					end
				end
				collapsedById[data.id or data.name] = not not collapsed
			end
		end

		for index, data in next, settings do
			local pool = Pools:Get(data.kind)
			if pool then
				local setting = pool:Acquire(self.Settings)
				setting.layoutIndex = index
				setting:Setup(data, self.selection)
				local visible = evaluateVisibility(data)
				if data.parentId and collapsedById[data.parentId] then
					visible = false
				end
				if setting.SetEnabled then
					local enabled = true
					if data.isEnabled then
						local ok, result = pcall(data.isEnabled, lib.activeLayoutName, lib:GetActiveLayoutIndex())
						enabled = ok and result ~= false
					elseif data.disabled then
						local ok, result = pcall(data.disabled, lib.activeLayoutName, lib:GetActiveLayoutIndex())
						enabled = not (ok and result == true)
					end
					setting:SetEnabled(enabled)
				end
				if visible then
					setting.ignoreInLayout = nil
					setting:Show()
				else
					setting.ignoreInLayout = true
					setting:Hide()
				end
			end
		end
	end

	self.Settings.ResetButton.layoutIndex = num + 1
	self.Settings.Divider.layoutIndex = num + 2
	self.Settings.ResetButton:SetEnabled(num > 0)
	if self.Settings and self.Settings.Layout then
		self.Settings:Layout()
	end
end

function Dialog:UpdateButtons()
	local buttonPool = Pools:Get("button")
	if buttonPool then
		buttonPool:ReleaseAll()
	end
	local anyVisible = false
	local buttons, num = Internal:GetFrameButtons(self.selection.parent)
	if num > 0 then
		for index, data in next, buttons do
			local button = buttonPool and buttonPool:Acquire(self.Buttons)
			if not button then
				break
			end
			button.layoutIndex = index
			button:SetText(data.text)
			if button.SetOnClickHandler then
				button:SetOnClickHandler(data.click)
			else
				button:SetScript("OnClick", data.click)
			end
			button:Show()
			anyVisible = true
		end
	end

	local showReset = true
	if State.resetToggles[self.selection.parent] == false then
		showReset = false
	end
	if showReset and buttonPool then
		local resetPosition = buttonPool:Acquire(self.Buttons)
		resetPosition.layoutIndex = num + 1
		resetPosition:SetText(HUD_EDIT_MODE_RESET_POSITION)
		resetPosition:SetOnClickHandler(GenerateClosure(self.ResetPosition, self))
		resetPosition:Show()
		anyVisible = true
	end

	if anyVisible then
		setResetVisibility(self.Buttons, true)
		if self.Settings and self.Settings.Divider then
			self.Settings.Divider.ignoreInLayout = nil
			self.Settings.Divider:Show()
		end
	else
		setResetVisibility(self.Buttons, false)
		if self.Settings and self.Settings.Divider then
			self.Settings.Divider.ignoreInLayout = true
			self.Settings.Divider:Hide()
		end
	end
end

function Dialog:ResetSettings()
	local settings, num = Internal:GetFrameSettings(self.selection.parent)
	if num > 0 then
		for _, data in next, settings do
			local handledDefault = false
			if data.kind == lib.SettingType.MultiDropdown and data.default ~= nil then
				local selection = Util:CopySelectionMap(Util:NormalizeSelection(data.default))
				if data.set then
					data.set(lib.activeLayoutName, selection, lib:GetActiveLayoutIndex())
				elseif data.setSelected then
					for _, option in ipairs(resolveOptions(data, lib.activeLayoutName)) do
						if option.value ~= nil then
							data.setSelected(
								lib.activeLayoutName,
								option.value,
								selection[option.value] and true or false,
								lib:GetActiveLayoutIndex()
							)
						end
					end
				end
				handledDefault = true
			end
			if not handledDefault and data.default ~= nil and data.set then
				data.set(lib.activeLayoutName, data.default, lib:GetActiveLayoutIndex())
			end
			if data.kind == lib.SettingType.CheckboxColor then
				local apply = data.colorSet or data.setColor
				if apply and data.colorDefault ~= nil then
					apply(lib.activeLayoutName, data.colorDefault or { 1, 1, 1, 1 }, lib:GetActiveLayoutIndex())
				end
			end
		end
		self:Update(self.selection)
	end
end

function Dialog:ResetPosition()
	local parent = self.selection.parent
	local pos = lib:GetFrameDefaultPosition(parent) or { point = "CENTER", x = 0, y = 0 }
	parent:ClearAllPoints()
	parent:SetPoint(pos.point, pos.x, pos.y)
	Internal:TriggerCallback(parent, pos.point, pos.x, pos.y)
end

function Internal:CreateDialog()
	local dialog = Mixin(CreateFrame("Frame", nil, UIParent, "ResizeLayoutFrame"), Dialog)
	dialog:SetSize(300, 350)
	dialog:SetFrameStrata("DIALOG")
	dialog:SetFrameLevel(200)
	dialog:Hide()
	dialog.widthPadding = 40
	dialog.heightPadding = 40

	dialog:EnableMouse(true)
	dialog:SetMovable(true)
	dialog:SetClampedToScreen(true)
	dialog:SetDontSavePosition(true)
	dialog:RegisterForDrag("LeftButton")
	dialog:SetScript("OnDragStart", function()
		dialog:StartMoving()
	end)
	dialog:SetScript("OnDragStop", function()
		dialog:StopMovingOrSizing()
		saveDialogPosition(dialog)
	end)

	local dialogTitle = dialog:CreateFontString(nil, nil, "GameFontHighlightLarge")
	dialogTitle:SetPoint("TOP", 0, -15)
	dialog.Title = dialogTitle

	local dialogBorder = CreateFrame("Frame", nil, dialog, "DialogBorderTranslucentTemplate")
	dialogBorder.ignoreInLayout = true
	dialog.Border = dialogBorder

	local dialogClose = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
	dialogClose:SetPoint("TOPRIGHT")
	dialogClose.ignoreInLayout = true
	dialog.Close = dialogClose

	local hideLabelButton = CreateFrame("Button", nil, dialog)
	hideLabelButton:SetSize(32, 32)
	hideLabelButton:SetPoint("RIGHT", dialogClose, "LEFT", -4, 0)
	hideLabelButton:SetNormalTexture(LFG_EYE_TEXTURE)
	local dialogEyeTex = hideLabelButton:GetNormalTexture()
	if dialogEyeTex then
		setEyeFrame(dialogEyeTex, LFG_EYE_FRAME_OPEN)
	end
	hideLabelButton:SetHighlightTexture([[Interface\Buttons\ButtonHilight-Square]])
	if hideLabelButton:GetHighlightTexture() then
		hideLabelButton:GetHighlightTexture():SetAlpha(0)
	end
	hideLabelButton:SetScript("OnClick", function()
		local selection = dialog.selection
		if not selection then
			return
		end
		if State.overlayToggleFlags[selection.parent] == false then
			return
		end
		local hidden = not selection.overlayHidden
		updateSelectionVisuals(selection, hidden)
		updateEyeButton(hideLabelButton, hidden)
		dialog:Layout()
	end)
	hideLabelButton:SetScript("OnEnter", function()
		if not GameTooltip then
			return
		end
		GameTooltip:SetOwner(hideLabelButton, "ANCHOR_RIGHT")
		local state = dialog.selection and dialog.selection.overlayHidden and HUD_EDIT_MODE_SHOW or HUD_EDIT_MODE_HIDE
		GameTooltip:SetText((state or "Toggle") .. " highlight")
		GameTooltip:Show()
	end)
	hideLabelButton:SetScript("OnLeave", GameTooltip_Hide)
	dialog.HideLabelButton = hideLabelButton

	local dialogSettings = CreateFrame("Frame", nil, dialog, "VerticalLayoutFrame")
	dialogSettings:SetPoint("TOP", dialogTitle, "BOTTOM", 0, -12)
	dialogSettings.spacing = 2
	dialog.Settings = dialogSettings

	local resetSettingsButton = CreateFrame("Button", nil, dialogSettings, "EditModeSystemSettingsDialogButtonTemplate")
	resetSettingsButton:SetText(RESET_TO_DEFAULT)
	resetSettingsButton:SetOnClickHandler(GenerateClosure(dialog.ResetSettings, dialog))
	dialogSettings.ResetButton = resetSettingsButton

	local divider = dialogSettings:CreateTexture(nil, "ARTWORK")
	divider:SetSize(330, 16)
	divider:SetTexture([[Interface\FriendsFrame\UI-FriendsFrame-OnlineDivider]])
	dialogSettings.Divider = divider

	local dialogButtons = CreateFrame("Frame", nil, dialog, "VerticalLayoutFrame")
	dialogButtons:SetPoint("TOP", dialogSettings, "BOTTOM", 0, -12)
	dialogButtons.spacing = 2
	dialog.Buttons = dialogButtons

	return dialog
end

-- Selection and movement -----------------------------------------------------------
local Selection = {}

local function isInCombat()
	return InCombatLockdown and InCombatLockdown()
end

local function deriveAnchorAndOffset(frame)
	-- Finds the nearest anchor on each axis (left/right/center, top/bottom/center) and
	-- returns a Blizzard anchor string plus offsets relative to the parent.
	local parent = frame:GetParent()
	if not parent then
		return
	end

	local scale = frame:GetScale()
	if not scale then
		return
	end

	local left = frame:GetLeft() * scale
	local right = frame:GetRight() * scale
	local top = frame:GetTop() * scale
	local bottom = frame:GetBottom() * scale
	local parentWidth, parentHeight = parent:GetSize()

	-- Distance helpers
	local cx = (left + right) * 0.5 - parentWidth * 0.5
	local cy = (bottom + top) * 0.5 - parentHeight * 0.5
	local dx = { label = "LEFT", dist = left, offset = left }
	local cxEntry = { label = "", dist = math.abs(cx), offset = cx }
	local rx = { label = "RIGHT", dist = parentWidth - right, offset = right - parentWidth }

	local dy = { label = "BOTTOM", dist = bottom, offset = bottom }
	local cyEntry = { label = "", dist = math.abs(cy), offset = cy }
	local ty = { label = "TOP", dist = parentHeight - top, offset = top - parentHeight }

	local function pickAxis(neg, center, pos)
		local candidate = neg
		if pos.dist < candidate.dist then
			candidate = pos
		end
		if center.dist <= candidate.dist then
			candidate = center
		end
		return candidate.label, candidate.offset
	end

	local xLabel, xOffset = pickAxis(dx, cxEntry, rx)
	local yLabel, yOffset = pickAxis(dy, cyEntry, ty)

	local point = (yLabel ~= "" and yLabel or "") .. (xLabel ~= "" and xLabel or "")
	if point == "" then
		point = "CENTER"
	end

	return point, xOffset / scale, yOffset / scale
end

local function adjustPosition(frame, dx, dy)
	local scale = frame:GetScale() or 1
	local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
	if not point then
		point, relativePoint, x, y = "CENTER", "CENTER", 0, 0
	end
	x = (x or 0) + dx / scale
	y = (y or 0) + dy / scale
	frame:ClearAllPoints()
	frame:SetPoint(point, relativeTo or UIParent, relativePoint or point, x, y)
	Internal:TriggerCallback(frame, point, x, y)
end

local function resetSelectionIndicators()
	if Internal.dialog then
		Internal.dialog:Hide()
	end
	for frame, selection in next, State.selectionRegistry do
		if selection.isSelected then
			frame:SetMovable(false)
		end
		local keepHidden = selection.overlayHidden
		if not lib.isEditing then
			keepHidden = false
		end
		updateSelectionVisuals(selection, keepHidden)
		if not lib.isEditing then
			selection:Hide()
			selection.isSelected = false
		else
			selection:ShowHighlighted()
		end
	end
	if Internal.dialog and Internal.dialog.HideLabelButton then
		updateEyeButton(Internal.dialog.HideLabelButton, false)
	end
end

local function beginSelectionDrag(self)
	if isInCombat() then
		return
	end
	self.parent:StartMoving()
end

local function finishSelectionDrag(self)
	local parent = self.parent
	parent:StopMovingOrSizing()
	if isInCombat() then
		return
	end
	local point, x, y = deriveAnchorAndOffset(parent)
	if not point then
		return
	end
	parent:ClearAllPoints()
	parent:SetPoint(point, x, y)
	Internal:TriggerCallback(parent, point, x, y)
end

local function handleSelectionMouseDown(self)
	if isInCombat() then
		return
	end
	resetSelectionIndicators()
	if EditModeManagerFrame and EditModeManagerFrame.ClearSelectedSystem then
		EditModeManagerFrame:ClearSelectedSystem()
	end
	if not self.isSelected then
		self.parent:SetMovable(true)
		self:ShowSelected(true)
		self.isSelected = true
		if Internal.dialog then
			Internal.dialog:Update(self)
		end
	end
end

local function onEditModeEnter()
	updateActiveLayoutFromAPI()
	lib.isEditing = true
	resetSelectionIndicators()
	for _, callback in next, lib.eventHandlersEnter do
		securecallfunction(callback)
	end
end

local function onEditModeExit()
	lib.isEditing = false
	resetSelectionIndicators()
	for _, callback in next, lib.eventHandlersExit do
		securecallfunction(callback)
	end
end

-- API callbacks --------------------------------------------------------------------
lib.eventHandlersEnter = lib.eventHandlersEnter or {}
lib.eventHandlersExit = lib.eventHandlersExit or {}
lib.eventHandlersLayout = lib.eventHandlersLayout or {}
lib.eventHandlersLayoutAdded = lib.eventHandlersLayoutAdded or {}
lib.eventHandlersLayoutDeleted = lib.eventHandlersLayoutDeleted or {}
lib.eventHandlersLayoutRenamed = lib.eventHandlersLayoutRenamed or {}
lib.eventHandlersSpec = lib.eventHandlersSpec or {}
lib.eventHandlersLayoutDuplicate = lib.eventHandlersLayoutDuplicate or {}

-- API ------------------------------------------------------------------------------
function lib:AddFrame(frame, callback, default)
	local selection = CreateFrame("Frame", nil, frame, "EditModeSystemSelectionTemplate")
	selection:SetAllPoints()
	selection:SetScript("OnMouseDown", handleSelectionMouseDown)
	selection:SetScript("OnDragStart", beginSelectionDrag)
	selection:SetScript("OnDragStop", finishSelectionDrag)
	selection:SetScript("OnKeyDown", function(selectionFrame, key)
		if not selectionFrame.isSelected or isInCombat() then
			return
		end
		local step = IsShiftKeyDown() and 10 or 1
		if key == "UP" then
			if selectionFrame.SetPropagateKeyboardInput then
				selectionFrame:SetPropagateKeyboardInput(false)
			end
			adjustPosition(selectionFrame.parent, 0, step)
		elseif key == "DOWN" then
			if selectionFrame.SetPropagateKeyboardInput then
				selectionFrame:SetPropagateKeyboardInput(false)
			end
			adjustPosition(selectionFrame.parent, 0, -step)
		elseif key == "LEFT" then
			if selectionFrame.SetPropagateKeyboardInput then
				selectionFrame:SetPropagateKeyboardInput(false)
			end
			adjustPosition(selectionFrame.parent, -step, 0)
		elseif key == "RIGHT" then
			if selectionFrame.SetPropagateKeyboardInput then
				selectionFrame:SetPropagateKeyboardInput(false)
			end
			adjustPosition(selectionFrame.parent, step, 0)
		else
			if selectionFrame.SetPropagateKeyboardInput then
				selectionFrame:SetPropagateKeyboardInput(true)
			end
		end
	end)
	selection:SetScript("OnKeyUp", function(selectionFrame)
		if selectionFrame.SetPropagateKeyboardInput then
			selectionFrame:SetPropagateKeyboardInput(true)
		end
	end)
	selection:EnableKeyboard(true)
	if selection.SetPropagateKeyboardInput then
		selection:SetPropagateKeyboardInput(true)
	end
	selection:Hide()

	selection.labelHidden = false
	selection.overlayHidden = false
	if select(4, GetBuildInfo()) >= 110200 then
		selection.systemBaseName = frame.editModeName or frame:GetName()
		selection.system = {}
		selection.system.GetSystemName = function()
			if selection.labelHidden then
				return ""
			end
			return selection.systemBaseName
		end
	else
		selection.Label:SetText(frame.editModeName or frame:GetName())
	end

	State.selectionRegistry[frame] = selection
	State.frameHandlers[frame] = callback
	State.defaultPositions[frame] = default
	if default then
		local toggle = default.enableOverlayToggle
			or default.overlayToggleEnabled
			or (default.enableOverlayToggle == false and false)
			or (default.overlayToggleEnabled == false and false)
		if toggle ~= nil then
			State.overlayToggleFlags[frame] = not not toggle
		end
	end

	if not Internal.dialog then
		Internal.dialog = Internal:CreateDialog()
		Internal.dialog:HookScript("OnHide", function()
			resetSelectionIndicators()
		end)
		applyDialogPosition(Internal.dialog)

		local combatWatcher = CreateFrame("Frame")
		combatWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
		combatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
		combatWatcher:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
		combatWatcher:SetScript("OnEvent", function(_, event)
			if event == "PLAYER_REGEN_DISABLED" then
				resetSelectionIndicators()
			elseif event == "PLAYER_REGEN_ENABLED" and lib.isEditing then
				resetSelectionIndicators()
			elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
				Layout:HandleSpecChanged()
			end
		end)

		EventRegistry:RegisterFrameEventAndCallback("EDIT_MODE_LAYOUTS_UPDATED", function(_, layoutInfo)
			Layout:HandleLayoutsChanged(nil, layoutInfo)
		end)
		EventRegistry:RegisterCallback("EditMode.SavedLayouts", function()
			if C_EditMode and C_EditMode.GetLayouts then
				Layout:HandleLayoutsChanged(nil, C_EditMode.GetLayouts())
			end
		end)

		EditModeManagerFrame:HookScript("OnShow", onEditModeEnter)
		EditModeManagerFrame:HookScript("OnHide", onEditModeExit)

		hooksecurefunc(EditModeManagerFrame, "SelectSystem", function()
			resetSelectionIndicators()
		end)
		if C_EditMode then
			if C_EditMode.OnLayoutDeleted then
				hooksecurefunc(C_EditMode, "OnLayoutDeleted", function(deletedLayoutIndex)
					Layout:HandleLayoutDeleted(deletedLayoutIndex)
				end)
			end
			if C_EditMode.OnLayoutAdded then
				hooksecurefunc(
					C_EditMode,
					"OnLayoutAdded",
					function(addedLayoutIndex, activateNewLayout, isLayoutImported)
						Layout:HandleLayoutAdded(addedLayoutIndex, activateNewLayout, isLayoutImported)
					end
				)
			end
		end
	end
end

function lib:AddFrameSettings(frame, settings)
	if not State.selectionRegistry[frame] then
		error("frame must be registered")
	end
	State.settingSheets[frame] = settings
end

function lib:AddFrameSettingsButton(frame, data)
	if not State.buttonSpecs[frame] then
		State.buttonSpecs[frame] = {}
	end
	table.insert(State.buttonSpecs[frame], data)
end

function lib:SetFrameResetVisible(frame, showReset)
	State.resetToggles[frame] = not not showReset
end

function lib:SetFrameOverlayToggleEnabled(frame, enabled)
	State.overlayToggleFlags[frame] = not not enabled
	if enabled == false and State.selectionRegistry[frame] then
		State.selectionRegistry[frame].overlayHidden = false
	end
end

function lib:RegisterCallback(event, callback)
	assert(event and type(event) == "string", "event must be a string")
	assert(callback and type(callback) == "function", "callback must be a function")
	if event == "enter" then
		table.insert(lib.eventHandlersEnter, callback)
	elseif event == "exit" then
		table.insert(lib.eventHandlersExit, callback)
	elseif event == "layout" then
		table.insert(lib.eventHandlersLayout, callback)
	elseif event == "layoutadded" then
		table.insert(lib.eventHandlersLayoutAdded, callback)
	elseif event == "layoutdeleted" then
		table.insert(lib.eventHandlersLayoutDeleted, callback)
	elseif event == "layoutrenamed" then
		table.insert(lib.eventHandlersLayoutRenamed, callback)
	elseif event == "spec" then
		table.insert(lib.eventHandlersSpec, callback)
	elseif event == "layoutduplicate" then
		table.insert(lib.eventHandlersLayoutDuplicate, callback)
	else
		error('invalid callback event "' .. event .. '"')
	end
end

function lib:GetActiveLayoutName()
	return lib.activeLayoutName
end

function lib:GetActiveLayoutIndex()
	if not lib.activeLayoutIndex then
		updateActiveLayoutFromAPI()
	end
	return lib.activeLayoutIndex
end

function lib:IsInEditMode()
	return not not lib.isEditing
end

function lib:GetFrameDefaultPosition(frame)
	return State.defaultPositions[frame]
end

-- internal entry points ------------------------------------------------------------
function Internal:TriggerCallback(frame, ...)
	if State.frameHandlers[frame] then
		securecallfunction(State.frameHandlers[frame], frame, lib.activeLayoutName, ...)
	end
end

function Internal:GetFrameSettings(frame)
	if State.settingSheets[frame] then
		return State.settingSheets[frame], #State.settingSheets[frame]
	else
		return nil, 0
	end
end

function Internal:GetFrameButtons(frame)
	if State.buttonSpecs[frame] then
		return State.buttonSpecs[frame], #State.buttonSpecs[frame]
	else
		return nil, 0
	end
end

function Internal:RefreshSettings()
	if not (Internal.dialog and Internal.dialog:IsShown()) then
		return
	end
	local parent = Internal.dialog.Settings
	if not parent then
		return
	end
	local selectionParent = Internal.dialog.selection and Internal.dialog.selection.parent
	for _, child in ipairs({ parent:GetChildren() }) do
		if child.SetEnabled and child.setting then
			local data = child.setting
			local enabled = true
			if data.isEnabled then
				local ok, result = pcall(data.isEnabled, lib.activeLayoutName, lib:GetActiveLayoutIndex())
				enabled = ok and result ~= false
			elseif data.disabled then
				local ok, result = pcall(data.disabled, lib.activeLayoutName, lib:GetActiveLayoutIndex())
				enabled = not (ok and result == true)
			end
			child:SetEnabled(enabled)

			local collapsedParent = (data.kind ~= lib.SettingType.Collapsible)
				and data.parentId
				and Collapse:Get(selectionParent, data.parentId)
			local visible = evaluateVisibility(data) and not collapsedParent
			child.ignoreInLayout = not visible
			if visible then
				child:Show()
			else
				child:Hide()
			end
		end
	end
	if parent.Layout then
		parent:Layout()
	end
	if Internal.dialog and Internal.dialog.Layout then
		Internal.dialog:Layout()
	end
end

function Internal:RefreshSettingValues()
	if not (Internal.dialog and Internal.dialog:IsShown()) then
		return
	end
	local parent = Internal.dialog.Settings
	if not parent then
		return
	end
	local selection = Internal.dialog.selection
	if not selection then
		return
	end
	local selectionParent = selection.parent
	local settings, num = Internal:GetFrameSettings(selection.parent)
	if not settings or num == 0 then
		return
	end
	for _, child in ipairs({ parent:GetChildren() }) do
		local data
		if child.layoutIndex and settings[child.layoutIndex] then
			data = settings[child.layoutIndex]
		elseif child.setting then
			data = child.setting
		end
		if data and child.Setup then
			child:Setup(data, selection)
			child.setting = data
			if child.SetEnabled then
				local enabled = true
				if data.isEnabled then
					local ok, result = pcall(data.isEnabled, lib.activeLayoutName, lib:GetActiveLayoutIndex())
					enabled = ok and result ~= false
				elseif data.disabled then
					local ok, result = pcall(data.disabled, lib.activeLayoutName, lib:GetActiveLayoutIndex())
					enabled = not (ok and result == true)
				end
				child:SetEnabled(enabled)
			end
			local collapsed = (data.kind ~= lib.SettingType.Collapsible)
				and Collapse:Get(selectionParent, data.parentId)
			local visible = evaluateVisibility(data) and not collapsed
			if visible then
				child.ignoreInLayout = nil
				child:Show()
			else
				child.ignoreInLayout = true
				child:Hide()
			end
		end
	end
	if parent.Layout then
		parent:Layout()
	end
	if Internal.dialog and Internal.dialog.Layout then
		Internal.dialog:Layout()
	end
end
