local MODULE_MAJOR = "LibEQOLSettingsMode-1.0"
local _, lib = pcall(LibStub, MODULE_MAJOR)
if not lib then
	return
end

LibEQOL_MultiDropdownMixin = CreateFromMixins(SettingsDropdownControlMixin)

local SUMMARY_CHAR_LIMIT = 80

local function sortMixedKeys(keys)
	table.sort(keys, function(a, b)
		local ta, tb = type(a), type(b)
		if ta == tb then
			if ta == "number" then
				return a < b
			end
			if ta == "string" then
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

local function cloneOption(option)
	local cloned = {}
	if type(option) == "table" then
		for key, value in pairs(option) do
			cloned[key] = value
		end
	else
		cloned.value = option
	end

	if cloned.value == nil then
		cloned.value = cloned.text or cloned.label
	end

	local fallback = cloned.text or cloned.label or tostring(cloned.value or "")
	if cloned.value == nil then
		cloned.value = fallback
	end

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
			table.insert(normalized, cloneOption(option))
		end
	else
		for key, option in pairs(list) do
			if key ~= "_order" then
				if type(option) == "table" then
					table.insert(normalized, cloneOption(option))
				else
					table.insert(normalized, cloneOption({ value = key, text = option }))
				end
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

function LibEQOL_MultiDropdownMixin:OnLoad()
	SettingsDropdownControlMixin.OnLoad(self)
	if self.Summary then
		self.Summary:SetText("")
		self.Summary:Hide()
		self.Summary = nil
	end
	self:EnsureSummaryAnchors()
end

function LibEQOL_MultiDropdownMixin:Init(initializer)
	self.initializer = initializer
	local data = initializer:GetData() or {}

	self.labelText = data.label
	self.optionfunc = data.optionfunc
	self.isSelectedFunc = data.isSelectedFunc
	self.setSelectedFunc = data.setSelectedFunc
	self.summaryFunc = data.summaryFunc
	self:SetOptions(data.options or {})
	self.getSelection = data.getSelection
	self.setSelection = data.setSelection

	SettingsDropdownControlMixin.Init(self, initializer)

	if self.Text and data.label then
		self.Text:SetText(data.label)
	end

	self:RefreshSummary()
end

function LibEQOL_MultiDropdownMixin:IsSelected(value)
	if value == nil then
		return false
	end
	if self.isSelectedFunc then
		local ok, result = pcall(self.isSelectedFunc, value)
		if ok then
			return not not result
		end
	end
	if self.getSelection then
		local ok, selection = pcall(self.getSelection)
		if ok and type(selection) == "table" then
			return selection[value] == true
		end
	end
	return false
end

function LibEQOL_MultiDropdownMixin:SetSelected(value, shouldSelect)
	if value == nil then
		return
	end
	if self.setSelectedFunc then
		self.setSelectedFunc(value, shouldSelect)
	elseif self.getSelection and self.setSelection then
		local ok, selection = pcall(self.getSelection)
		if not ok or type(selection) ~= "table" then
			selection = {}
		end
		if shouldSelect then
			selection[value] = true
		else
			selection[value] = nil
		end
		self.setSelection(selection)
	end
	self:RefreshSummary()
end

function LibEQOL_MultiDropdownMixin:ToggleOption(value)
	self:SetSelected(value, not self:IsSelected(value))
end

function LibEQOL_MultiDropdownMixin:GetSummaryMap()
	if self.getSelection then
		local ok, selection = pcall(self.getSelection)
		if ok and type(selection) == "table" then
			return selection
		end
	end
	local map = {}
	for _, opt in ipairs(self:GetOptions()) do
		if opt.value ~= nil and self:IsSelected(opt.value) then
			map[opt.value] = true
		end
	end
	return map
end

function LibEQOL_MultiDropdownMixin:FormatSummary(map)
	if self.summaryFunc then
		local ok, result = pcall(self.summaryFunc, map)
		if ok and type(result) == "string" then
			return result
		end
	end
	local texts = {}
	for _, opt in ipairs(self:GetOptions()) do
		if opt.value ~= nil and map[opt.value] then
			table.insert(texts, opt.text or tostring(opt.value))
		end
	end
	sortMixedKeys(texts)
	local summary = ""
	local widthLimit = self.Dropdown and self.Dropdown:GetWidth()
	for index, text in ipairs(texts) do
		local candidate = (summary == "") and text or (summary .. ", " .. text)
		if widthLimit and summary ~= "" and self:WouldExceedWidth(candidate, widthLimit) then
			local overflow = #texts - index + 1
			summary = summary .. string.format(" … (+%d)", overflow)
			break
		elseif widthLimit and summary == "" and self:WouldExceedWidth(candidate, widthLimit) then
			summary = text .. ( (#texts - index) > 0 and " …" or "" )
			break
		else
			summary = candidate
		end
	end
	if summary == "" then
		summary = "–"
	end
	if not widthLimit and #summary > SUMMARY_CHAR_LIMIT then
		summary = summary:sub(1, SUMMARY_CHAR_LIMIT) .. " …"
	end
	return summary
end

function LibEQOL_MultiDropdownMixin:GetMeasureFontString()
	if self.summaryMeasure and self.summaryMeasure:IsObjectType("FontString") then
		return self.summaryMeasure
	end
	if not self.Text then
		return nil
	end
	local fs = self:CreateFontString(nil, "OVERLAY")
	fs:SetFontObject(self.Text:GetFontObject())
	fs:SetWordWrap(false)
	fs:SetNonSpaceWrap(false)
	fs:SetSpacing(0)
	fs:Hide()
	self.summaryMeasure = fs
	return fs
end

function LibEQOL_MultiDropdownMixin:WouldExceedWidth(text, widthLimit)
	if not text or text == "" then
		return false
	end
	if not widthLimit then
		return #text > SUMMARY_CHAR_LIMIT
	end
	local measure = self:GetMeasureFontString()
	if not measure then
		return #text > SUMMARY_CHAR_LIMIT
	end
	measure:SetFontObject(self.Text:GetFontObject())
	measure:SetText(text)
	local getWidth = measure.GetUnboundedStringWidth or measure.GetStringWidth
	return getWidth(measure) > widthLimit
end

function LibEQOL_MultiDropdownMixin:EnsureSummaryAnchors()
	if self.summaryAnchored or not (self.Summary and self.Dropdown) then
		return
	end
	self.summaryAnchored = true
	self.Summary:ClearAllPoints()
	self.Summary:SetPoint("TOPLEFT", self.Dropdown, "BOTTOMLEFT", 0, -2)
	self.Summary:SetPoint("TOPRIGHT", self.Dropdown, "BOTTOMRIGHT", 0, -2)
	self.Summary:SetWidth(self.Dropdown:GetWidth())
end

function LibEQOL_MultiDropdownMixin:RefreshSummary()
	if not self.Summary then
		return
	end
	self:EnsureSummaryAnchors()
	local summary = self:FormatSummary(self:GetSummaryMap())
	self.Summary:SetText(summary)
end
