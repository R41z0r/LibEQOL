local MODULE_MAJOR, EXPECTED_MINOR = "LibEQOLSettingsMode-1.0", 23001000
local ok, lib = pcall(LibStub, MODULE_MAJOR)
if not ok or not lib then
	return
end
if lib.MINOR and lib.MINOR > EXPECTED_MINOR then
	return
end

LibEQOL_SortableListMixin = CreateFromMixins(SettingsListElementMixin)

local DEFAULT_ROW_HEIGHT = 22
local DEFAULT_SPACING = 4
local DEFAULT_PADDING = 4
local DEFAULT_BUTTON_SIZE = 20
local DEFAULT_ADD_BUTTON_WIDTH = 96

local function wipeTable(tbl)
	if not tbl then
		return
	end
	for k in pairs(tbl) do
		tbl[k] = nil
	end
end

local function shallowCopy(tbl)
	if type(tbl) ~= "table" then
		return tbl
	end
	local copy = {}
	for k, v in pairs(tbl) do
		copy[k] = v
	end
	return copy
end

local function itemValue(item)
	if type(item) == "table" then
		return item.value or item.key or item.id or item.text or item.label or item.name
	end
	return item
end

local function itemLabel(item)
	if type(item) == "table" then
		local label = item.label or item.text or item.name or item.title or item.value or item.key or item.id
		if label ~= nil then
			return tostring(label)
		end
	end
	if item ~= nil then
		return tostring(item)
	end
	return ""
end

local function copyItems(items)
	local list = {}
	if type(items) ~= "table" then
		return list
	end
	for index, item in ipairs(items) do
		list[index] = shallowCopy(item)
	end
	return list
end

local function containsItem(items, candidate)
	local value = itemValue(candidate)
	for _, item in ipairs(items or {}) do
		if itemValue(item) == value then
			return true
		end
	end
	return false
end

local function call(func, ...)
	if type(func) ~= "function" then
		return nil
	end
	local ok, result = pcall(func, ...)
	if ok then
		return result
	end
	return nil
end

local function repairSettingsLayout()
	if SettingsInbound and SettingsInbound.RepairDisplay then
		SettingsInbound.RepairDisplay()
	elseif SettingsPanel and SettingsPanel.RepairDisplay then
		SettingsPanel:RepairDisplay()
	end
end

local function setButtonText(button, text)
	if not button then
		return
	end
	if not button._LibEQOLText then
		button._LibEQOLText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		button._LibEQOLText:SetPoint("CENTER")
	end
	button._LibEQOLText:SetText(text or "")
end

local function setupButton(button, width, tooltip)
	button:SetSize(width or DEFAULT_BUTTON_SIZE, DEFAULT_BUTTON_SIZE)
	if button.SetNormalFontObject then
		button:SetNormalFontObject(GameFontNormalSmall)
		button:SetHighlightFontObject(GameFontHighlightSmall)
		button:SetDisabledFontObject(GameFontDisableSmall)
	end
	if tooltip then
		button:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip_SetTitle(GameTooltip, tooltip)
			GameTooltip:Show()
		end)
		button:SetScript("OnLeave", GameTooltip_Hide)
	else
		button:SetScript("OnEnter", nil)
		button:SetScript("OnLeave", nil)
	end
end

local function updateButtonTextEnabled(button, enabled)
	if button and button._LibEQOLText then
		button._LibEQOLText:SetFontObject(enabled and GameFontNormalSmall or GameFontDisableSmall)
	end
end

function LibEQOL_SortableListMixin:OnLoad()
	SettingsListElementMixin.OnLoad(self)

	self.Rows = CreateFrame("Frame", nil, self)
	self.Rows:SetPoint("TOPLEFT", self, "TOP", -80, -2)
	self.Rows:SetPoint("RIGHT", self, "RIGHT", -12, 0)
	self.Rows:SetFrameLevel((self:GetFrameLevel() or 0) + 5)

	self.RowPool = CreateFramePool("FRAME", self.Rows)
	self.rowFrames = {}

	local settingsLabel = self.Text
	self.AddButton = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
	self.Text = settingsLabel
	self.AddButton:SetSize(96, 22)
	self.AddButton:SetFrameLevel((self:GetFrameLevel() or 0) + 6)
	self.AddButton:SetScript("OnClick", function()
		self:OpenAddMenu()
	end)
end

function LibEQOL_SortableListMixin:Init(initializer)
	SettingsListElementMixin.Init(self, initializer)

	local data = initializer.data or {}
	self.initializer = initializer
	self.data = data
	self.rowHeight = data.rowHeight or DEFAULT_ROW_HEIGHT
	self.spacing = data.spacing or DEFAULT_SPACING
	self.padding = data.padding or DEFAULT_PADDING
	self.showDelete = data.delete ~= false and data.deletable ~= false and data.onDelete ~= false
	self.showAdd = data.add ~= false and (data.addOptions or data.addValues or data.addOptionFunc or data.menuGenerator or data.onAddButtonClick)
	self.allowDuplicates = data.allowDuplicates == true
	self.buttonSize = data.buttonSize or DEFAULT_BUTTON_SIZE

	self.AddButton:SetText(data.addText or data.addButtonText or "Add")
	self.AddButton:SetWidth(data.addButtonWidth or DEFAULT_ADD_BUTTON_WIDTH)

	self.items = self:ReadItems()
	self:RefreshRows()
	self:EvaluateState()
end

function LibEQOL_SortableListMixin:ReadItems()
	local data = self.data or {}
	local items
	if data.getItems then
		items = call(data.getItems)
	elseif data.get then
		items = call(data.get)
	else
		items = data.items
	end
	return copyItems(items)
end

function LibEQOL_SortableListMixin:Commit(action, item, oldIndex, newIndex)
	local items = copyItems(self.items)
	local data = self.data or {}
	if data.setItems then
		call(data.setItems, items, action, item, oldIndex, newIndex)
	elseif data.set then
		call(data.set, items, action, item, oldIndex, newIndex)
	elseif type(data.items) == "table" then
		wipeTable(data.items)
		for index, entry in ipairs(items) do
			data.items[index] = entry
		end
	end

	call(data.onChanged or data.callback, items, action, item, oldIndex, newIndex)
	if action == "move" then
		call(data.onReorder, items, item, oldIndex, newIndex)
	elseif action == "delete" then
		call(data.onDelete, item, oldIndex, items)
	elseif action == "add" then
		call(data.onAdd, item, newIndex, items)
	end

	if data.notify and Settings and Settings.NotifyUpdate then
		Settings.NotifyUpdate(data.notify)
	end
end

function LibEQOL_SortableListMixin:MoveItem(index, delta)
	local newIndex = index + delta
	if newIndex < 1 or newIndex > #self.items then
		return
	end
	local item = self.items[index]
	self.items[index], self.items[newIndex] = self.items[newIndex], item
	self:Commit("move", item, index, newIndex)
	self:RefreshRows()
	repairSettingsLayout()
end

function LibEQOL_SortableListMixin:DeleteItem(index)
	local item = table.remove(self.items, index)
	if not item then
		return
	end
	self:Commit("delete", item, index)
	self:RefreshRows()
	repairSettingsLayout()
end

function LibEQOL_SortableListMixin:AddItem(item)
	if item == nil then
		return
	end
	local entry = shallowCopy(item)
	if not self.allowDuplicates and containsItem(self.items, entry) then
		return
	end
	local index = #self.items + 1
	self.items[index] = entry
	self:Commit("add", entry, nil, index)
	self:RefreshRows()
	repairSettingsLayout()
end

function LibEQOL_SortableListMixin:ResolveAddOptions()
	local data = self.data or {}
	local options
	if data.addOptionFunc then
		options = call(data.addOptionFunc, copyItems(self.items), self)
	elseif data.addOptions or data.addValues then
		options = data.addOptions or data.addValues
	end
	return copyItems(options)
end

function LibEQOL_SortableListMixin:OpenAddMenu()
	local data = self.data or {}
	if data.onAddButtonClick then
		call(data.onAddButtonClick, self, copyItems(self.items))
		return
	end

	if data.menuGenerator and MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(self.AddButton, function(owner, rootDescription)
			self.menuDescription = rootDescription
			call(data.menuGenerator, owner, rootDescription, self, copyItems(self.items))
			self.menuDescription = nil
		end)
		return
	end

	local options = self:ResolveAddOptions()
	if #options == 1 then
		self:AddItem(options[1])
		return
	end

	if MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(self.AddButton, function(owner, rootDescription)
			local added = false
			for _, option in ipairs(options) do
				if self.allowDuplicates or not containsItem(self.items, option) then
					rootDescription:CreateButton(itemLabel(option), function()
						self:AddItem(option)
					end)
					added = true
				end
			end
			if not added then
				rootDescription:CreateTitle(data.emptyAddText or "No entries available")
			end
		end)
	end
end

function LibEQOL_SortableListMixin:AddMenuOption(option, text)
	if not (self.menuDescription and option ~= nil) then
		return
	end
	self.menuDescription:CreateButton(text or itemLabel(option), function()
		self:AddItem(option)
	end)
end

function LibEQOL_SortableListMixin:SetupRow(frame, item, index)
	if not frame.initialized then
		frame.Label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		frame.Label:SetJustifyH("LEFT")
		frame.Label:SetPoint("LEFT", 4, 0)

		frame.UpButton = CreateFrame("Button", nil, frame)
		frame.DownButton = CreateFrame("Button", nil, frame)
		frame.DeleteButton = CreateFrame("Button", nil, frame)
		setButtonText(frame.UpButton, "^")
		setButtonText(frame.DownButton, "v")
		setButtonText(frame.DeleteButton, "x")

		frame.initialized = true
	end

	frame:SetHeight(self.rowHeight)
	frame:SetPoint("LEFT", self.Rows, "LEFT", 0, 0)
	frame:SetPoint("RIGHT", self.Rows, "RIGHT", 0, 0)
	frame.data = item
	frame.index = index

	setupButton(frame.UpButton, self.buttonSize, self.data.upTooltip or "Move up")
	setupButton(frame.DownButton, self.buttonSize, self.data.downTooltip or "Move down")
	setupButton(frame.DeleteButton, self.buttonSize, self.data.deleteTooltip or "Delete")

	frame.DeleteButton:SetShown(self.showDelete)
	frame.DeleteButton:ClearAllPoints()
	frame.DeleteButton:SetPoint("RIGHT", frame, "RIGHT", 0, 0)

	frame.DownButton:ClearAllPoints()
	if self.showDelete then
		frame.DownButton:SetPoint("RIGHT", frame.DeleteButton, "LEFT", -2, 0)
	else
		frame.DownButton:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
	end

	frame.UpButton:ClearAllPoints()
	frame.UpButton:SetPoint("RIGHT", frame.DownButton, "LEFT", -2, 0)

	frame.Label:ClearAllPoints()
	frame.Label:SetPoint("LEFT", frame, "LEFT", 4, 0)
	frame.Label:SetPoint("RIGHT", frame.UpButton, "LEFT", -6, 0)
	frame.Label:SetText(itemLabel(item))

	frame.UpButton:SetScript("OnClick", function()
		self:MoveItem(index, -1)
	end)
	frame.DownButton:SetScript("OnClick", function()
		self:MoveItem(index, 1)
	end)
	frame.DeleteButton:SetScript("OnClick", function()
		self:DeleteItem(index)
	end)

	local enabled = self._enabledState ~= false
	local canMoveUp = index > 1
	local canMoveDown = index < #self.items
	frame.Label:SetFontObject(enabled and GameFontHighlightSmall or GameFontDisableSmall)
	frame.UpButton:SetShown(canMoveUp)
	frame.DownButton:SetShown(canMoveDown)
	frame.UpButton:SetEnabled(enabled and canMoveUp)
	frame.DownButton:SetEnabled(enabled and canMoveDown)
	frame.DeleteButton:SetEnabled(enabled)
	updateButtonTextEnabled(frame.UpButton, enabled and canMoveUp)
	updateButtonTextEnabled(frame.DownButton, enabled and canMoveDown)
	updateButtonTextEnabled(frame.DeleteButton, enabled)
end

function LibEQOL_SortableListMixin:RefreshRows()
	if self.data then
		self.data._currentCount = #(self.items or {})
		self.data._showAdd = self.showAdd
	end

	self.RowPool:ReleaseAll()
	wipeTable(self.rowFrames)
	self.rowFrames = self.rowFrames or {}

	local y = 0
	for index, item in ipairs(self.items or {}) do
		local frame = self.RowPool:Acquire()
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", self.Rows, "TOPLEFT", 0, y)
		frame:SetPoint("TOPRIGHT", self.Rows, "TOPRIGHT", 0, y)
		frame:SetFrameLevel((self.Rows:GetFrameLevel() or 0) + 1)
		self:SetupRow(frame, item, index)
		frame:Show()
		self.rowFrames[#self.rowFrames + 1] = frame
		y = y - (self.rowHeight + self.spacing)
	end

	self.AddButton:ClearAllPoints()
	if #self.rowFrames > 0 then
		self.AddButton:SetPoint("TOPLEFT", self.Rows, "TOPLEFT", 0, y - (self.showAdd and 2 or 0))
	else
		self.AddButton:SetPoint("TOPLEFT", self.Rows, "TOPLEFT", 0, 0)
	end
	self.AddButton:SetShown(self.showAdd)
end

function LibEQOL_SortableListMixin:Release()
	if self.RowPool then
		self.RowPool:ReleaseAll()
	end
	SettingsListElementMixin.Release(self)
end

function LibEQOL_SortableListMixin:EvaluateState()
	SettingsListElementMixin.EvaluateState(self)

	local enabled = true
	local data = self.data or {}
	if data.parentCheck then
		enabled = data.parentCheck() ~= false
	end
	if data.isEnabled then
		if type(data.isEnabled) == "function" then
			local result = call(data.isEnabled)
			enabled = enabled and result ~= false
		else
			enabled = enabled and data.isEnabled ~= false
		end
	end
	self._enabledState = enabled

	for index, frame in ipairs(self.rowFrames or {}) do
		if frame.Label then
			frame.Label:SetFontObject(enabled and GameFontHighlightSmall or GameFontDisableSmall)
		end
		if frame.UpButton then
			local canMoveUp = index > 1
			local buttonEnabled = enabled and canMoveUp
			frame.UpButton:SetShown(canMoveUp)
			frame.UpButton:SetEnabled(buttonEnabled)
			updateButtonTextEnabled(frame.UpButton, buttonEnabled)
		end
		if frame.DownButton then
			local canMoveDown = index < #self.items
			local buttonEnabled = enabled and canMoveDown
			frame.DownButton:SetShown(canMoveDown)
			frame.DownButton:SetEnabled(buttonEnabled)
			updateButtonTextEnabled(frame.DownButton, buttonEnabled)
		end
		if frame.DeleteButton then
			frame.DeleteButton:SetEnabled(enabled)
			updateButtonTextEnabled(frame.DeleteButton, enabled)
		end
	end
	self.AddButton:SetEnabled(enabled)
end
