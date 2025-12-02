local MODULE_MAJOR = "LibEQOLSettingsMode-1.0"
local _, lib = pcall(LibStub, MODULE_MAJOR)
if not lib then
	return
end

local addonName, addon = ...

LibEQOL_MultiDropdownMixin = CreateFromMixins(SettingsDropdownControlMixin)

local SUMMARY_CHAR_LIMIT = 80
local function SortMixedKeys(keys)
	table.sort(keys, function(a, b)
		local ta, tb = type(a), type(b)
		if ta == tb then
			if ta == "number" then return a < b end
			if ta == "string" then return a < b end
			return tostring(a) < tostring(b)
		end
		if ta == "number" then return true end
		if tb == "number" then return false end
		return tostring(a) < tostring(b)
	end)
	return keys
end

function LibEQOL_MultiDropdownMixin:OnLoad()
	-- erzeugt self.Control, self.Control.Dropdown, Tooltip-Verhalten etc.
	SettingsDropdownControlMixin.OnLoad(self)

	if self.Summary then
		self.Summary:SetText("")
		self.Summary:Hide()
		self.Summary = nil
	end

	self:EnsureSummaryAnchors()
end

function LibEQOL_MultiDropdownMixin:CloneOption(option)
	local cloned = {}
	if type(option) == "table" then
		for key, value in pairs(option) do
			cloned[key] = value
		end
	else
		cloned.value = option
	end

	if cloned.value == nil then cloned.value = cloned.text end
	if cloned.value == nil and cloned.label then cloned.value = cloned.label end

	local fallback = cloned.text or cloned.label or tostring(cloned.value or "")
	if cloned.value == nil then cloned.value = fallback end

	cloned.label = cloned.label or fallback
	cloned.text = cloned.text or fallback

	return cloned
end

function LibEQOL_MultiDropdownMixin:SetOptions(list)
	if type(list) ~= "table" then
		self.options = {}
		return
	end

	local usesIndexOrder = #list > 0
	local normalized = {}

	if usesIndexOrder then
		for _, option in ipairs(list) do
			table.insert(normalized, self:CloneOption(option))
		end
	else
		for key, option in pairs(list) do
			if type(option) == "table" then
				table.insert(normalized, self:CloneOption(option))
			else
				table.insert(normalized, self:CloneOption({ value = key, text = option }))
			end
		end
	end

	self.options = normalized
end

function LibEQOL_MultiDropdownMixin:GetOptions()
	if self.optionfunc then
		local result = self.optionfunc()
		if type(result) == "table" then
			self:SetOptions(result)
		else
			self.options = {}
		end
	end

	return self.options or {}
end

function LibEQOL_MultiDropdownMixin:Init(initializer)
	-- Unsere eigenen Daten zuerst setzen
	self.initializer = initializer

	local data = initializer:GetData()
	-- data = { var = "abc", label = "...", options = {...}, db = addon.db }

	self.var = data.var
	self.optionfunc = data.optionfunc
	self.isSelectedFunc = data.isSelectedFunc
	self.setSelectedFunc = data.setSelectedFunc
	self:SetOptions(data.options or {})
	self.db = addon.db
	self.subvar = data.subvar
	self.callback = data.callback

	if not self.db then error("LibEQOL_MultiDropdownMixin: data.db fehlt") end

	-- Jetzt Basis-Init, das InitDropdown + EvaluateState ruft (unsere überschriebenen Versionen)
	SettingsDropdownControlMixin.Init(self, initializer)

	-- Label ggf. anpassen
	if data.label then self.Text:SetText(data.label) end

	-- Summary initial anzeigen
	self:RefreshSummary()
end

-- --- Auswahlmodell: Tabelle in addon.db[var] ---

function LibEQOL_MultiDropdownMixin:GetSelectionTable()
	self.db = self.db or addon.db
	if type(self.db) ~= "table" then self.db = {} end

	local container = self.db[self.var]
	if type(container) ~= "table" then
		container = {}
		self.db[self.var] = container
	end

	if self.subvar then
		if type(container[self.subvar]) ~= "table" then container[self.subvar] = {} end
		container = container[self.subvar]
	end

	return container
end

function LibEQOL_MultiDropdownMixin:IsSelected(key)
	if self.isSelectedFunc then return self.isSelectedFunc(key) and true or false end
	return self:GetSelectionTable()[key] == true
end

function LibEQOL_MultiDropdownMixin:SetSelected(key, shouldSelect)
	if self.setSelectedFunc then
		self.setSelectedFunc(key, shouldSelect)
	else
		local selection = self:GetSelectionTable()
		if shouldSelect then
			selection[key] = true
		else
			selection[key] = nil
		end
	end

	self:SyncSetting()
end

function LibEQOL_MultiDropdownMixin:GetSelectionMap()
	if not self.setSelectedFunc then return self:GetSelectionTable() end

	local snapshot = {}
	for _, opt in ipairs(self:GetOptions()) do
		if opt.value ~= nil and self:IsSelected(opt.value) then snapshot[opt.value] = true end
	end
	return snapshot
end

function LibEQOL_MultiDropdownMixin:SyncSetting()
	local setting = self:GetSetting()
	if not setting then return end

	setting:SetValue(self:SerializeSelection(self:GetSelectionMap()))
end

function LibEQOL_MultiDropdownMixin:ToggleOption(key)
	local newState = not self:IsSelected(key)
	self:SetSelected(key, newState)
	self:RefreshSummary()
end

function LibEQOL_MultiDropdownMixin:SerializeSelection(tbl)
	local keys = {}
	for k, v in pairs(tbl) do
		if v then table.insert(keys, k) end
	end
	SortMixedKeys(keys)
	return table.concat(keys, ",")
end

function LibEQOL_MultiDropdownMixin:RefreshSummary()
	if not self.Summary then return end

	self:EnsureSummaryAnchors()

	local texts = {}
	for _, opt in ipairs(self:GetOptions()) do
		if opt.value ~= nil and self:IsSelected(opt.value) then table.insert(texts, opt.text or tostring(opt.value)) end
	end

	local summary = self:FormatSummaryText(texts)
	self.Summary:SetText(summary)
end

function LibEQOL_MultiDropdownMixin:EnsureSummaryAnchors()
	if self.summaryAnchored then return end

	if not (self.Summary and self.Control and self.Control.Dropdown) then return end

	self.summaryAnchored = true
	self.Summary:ClearAllPoints()
	self.Summary:SetPoint("TOPLEFT", self.Control.Dropdown, "BOTTOMLEFT", 0, -2)
	self.Summary:SetPoint("TOPRIGHT", self.Control.Dropdown, "BOTTOMRIGHT", 0, -2)
	self.Summary:SetWidth(self.Control.Dropdown:GetWidth())
end

function LibEQOL_MultiDropdownMixin:GetSummaryWidthLimit()
	if self.Control and self.Control.Dropdown then return self.Control.Dropdown:GetWidth() end

	if self.Summary then return self.Summary:GetWidth() end
end

function LibEQOL_MultiDropdownMixin:GetSummaryMeasureFontString()
	if self.summaryMeasure and self.summaryMeasure:IsObjectType("FontString") then return self.summaryMeasure end

	if not self.Summary then return nil end

	local fs = self.Summary:GetParent():CreateFontString(nil, "OVERLAY")
	if not fs then return nil end

	fs:SetFontObject(self.Summary:GetFontObject())
	fs:Hide()
	fs:SetWordWrap(false)
	fs:SetNonSpaceWrap(false)
	fs:SetSpacing(0)
	self.summaryMeasure = fs
	return fs
end

function LibEQOL_MultiDropdownMixin:WouldExceedSummaryWidth(text, widthLimit)
	if not text or text == "" then return false end

	if not widthLimit then return #text > SUMMARY_CHAR_LIMIT end

	local measure = self:GetSummaryMeasureFontString()
	if not measure then return #text > SUMMARY_CHAR_LIMIT end

	measure:SetFontObject(self.Summary:GetFontObject())
	measure:SetText(text)
	local getWidth = measure.GetUnboundedStringWidth or measure.GetStringWidth
	return getWidth(measure) > widthLimit
end

function LibEQOL_MultiDropdownMixin:FormatSummaryText(texts)
	if #texts == 0 then return "–" end

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
		if widthLimit and self:WouldExceedSummaryWidth(candidate, widthLimit) then candidate = summary .. " …" end
		summary = candidate
	end

	if not widthLimit and #summary > SUMMARY_CHAR_LIMIT then summary = summary:sub(1, SUMMARY_CHAR_LIMIT) .. " …" end

	return summary
end

-- Wir ersetzen komplett die Dropdown-Initialisierung des Basis-Mixins
function LibEQOL_MultiDropdownMixin:InitDropdown()
	local setting = self:GetSetting()
	local initializer = self:GetElementData()

	-- Wir bauen unsere eigene optionsFunc auf Basis self.options
	local function optionsFunc() return self:GetOptions() end

	-- Tooltip wie beim Original bauen
	local initTooltip = Settings.CreateOptionsInitTooltip(setting, initializer:GetName(), initializer:GetTooltip(), optionsFunc)

	-- Unsere Multi-Checkbox-Variante des Dropdown-Menüs
	self:SetupDropdownMenu(self.Control.Dropdown, setting, optionsFunc, initTooltip)

	-- Steppers brauchst du bei Multi-Select i.d.R. nicht
	if self.Control and self.Control.SetSteppersShown then self.Control:SetSteppersShown(false) end
end

-- OVERRIDE: kein Settings.InitDropdown mehr, wir bauen das Menü selbst
function LibEQOL_MultiDropdownMixin:SetupDropdownMenu(button, setting, optionsFunc, initTooltip)
	local dropdown = button or self.Control.Dropdown

	dropdown:SetDefaultText(CUSTOM)

	dropdown:SetupMenu(function(_, rootDescription)
		rootDescription:SetGridMode(MenuConstants.VerticalGridDirection)

		local opts = optionsFunc() or {}

		for _, opt in ipairs(opts) do
			if opt.value ~= nil then
				local label = opt.label or opt.text or tostring(opt.value)

				rootDescription:CreateCheckbox(label, function() return self:IsSelected(opt.value) end, function()
					self:ToggleOption(opt.value)
					if self.callback then self.callback(opt) end
				end, opt)
			end
		end
	end)

	if initTooltip then
		dropdown:SetTooltipFunc(initTooltip)
		dropdown:SetDefaultTooltipAnchors()
	end

	dropdown:SetScript("OnEnter", function()
		ButtonStateBehaviorMixin.OnEnter(dropdown)
		DefaultTooltipMixin.OnEnter(dropdown)
	end)

	dropdown:SetScript("OnLeave", function()
		ButtonStateBehaviorMixin.OnLeave(dropdown)
		DefaultTooltipMixin.OnLeave(dropdown)
	end)
end
