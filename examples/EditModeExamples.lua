--[[
	Minimal, self-contained example showing how to use the LibEQOLEditMode sublib from LibEQOL.
	Drop this file into an addon folder together with LibStub and LibEQOL
	and add it to your TOC after the library is loaded.
]]

local LibStub = _G.LibStub
assert(LibStub, "LibEQOL example requires LibStub")

local EditMode = LibStub("LibEQOLEditMode-1.0")
assert(EditMode, "LibEQOLEditMode-1.0 is not loaded")

-- simple in-memory storage for demo purposes
local DB = { layouts = {} }

local function getLayout(layoutName)
	local key = layoutName or EditMode:GetActiveLayoutName() or "_Global"
	local layout = DB.layouts[key]
	if not layout then
		layout = {}
		DB.layouts[key] = layout
	end
	return layout
end

local function getRecord(id, layoutName)
	local layout = getLayout(layoutName)
	local record = layout[id]
	if not record then
		record = {}
		layout[id] = record
	end
	return record
end

local function getField(id, field, default, layoutName)
	local record = getRecord(id, layoutName)
	local value = record[field]
	if value == nil then return default end
	return value
end

local function setField(id, field, value, layoutName)
	local record = getRecord(id, layoutName)
	record[field] = value
end

local function createExampleFrame(name, title, color)
	local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
	frame:SetSize(180, 50)
	frame:SetFrameStrata("DIALOG")

	frame:SetBackdrop({
		bgFile = "Interface/Buttons/WHITE8X8",
		edgeFile = "Interface/Buttons/WHITE8X8",
		edgeSize = 1,
	})
	frame:SetBackdropColor(color[1], color[2], color[3], 0.08)
	frame:SetBackdropBorderColor(color[1], color[2], color[3], 0.9)

	local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("CENTER")
	label:SetText(title)

	return frame
end

local examples = {
	{
		key = "Checkbox",
		title = "Checkbox",
		color = { 0.2, 0.6, 1 },
		defaults = { point = "CENTER", x = -260, y = 120, checkbox = true },
		settings = {
			{
				name = "Checkbox",
				kind = EditMode.SettingType.Checkbox,
				field = "checkbox",
				default = true,
			},
		},
	},
	{
		key = "Dropdown",
		title = "Dropdown",
		color = { 0.25, 0.8, 0.45 },
		defaults = { point = "CENTER", x = -80, y = 120, dropdown = "Option A" },
		settings = {
			{
				name = "Dropdown",
				kind = EditMode.SettingType.Dropdown,
				field = "dropdown",
				default = "Option A",
				values = {
					{ text = "Option A" },
					{ text = "Option B" },
					{ text = "Option C" },
				},
			},
		},
	},
	{
		key = "MultiDropdown",
		title = "Multi Dropdown",
		color = { 0.3, 0.65, 0.95 },
		defaults = {
			point = "CENTER",
			x = 260,
			y = 20,
			roles = { TANK = true, HEALER = true },
		},
		settings = {
			{
				name = "Roles",
				kind = EditMode.SettingType.MultiDropdown,
				field = "roles",
				default = { TANK = true, HEALER = true },
				values = {
					{ text = "Tank", value = "TANK" },
					{ text = "Healer", value = "HEALER" },
					{ text = "DPS", value = "DPS" },
				},
			},
		},
	},
	{
		key = "SliderInput",
		title = "Slider + Input",
		color = { 0.85, 0.6, 0.2 },
		defaults = { point = "CENTER", x = 100, y = 120, slider = 50 },
		settings = {
			{
				name = "Slider",
				kind = EditMode.SettingType.Slider,
				field = "slider",
				default = 50,
				minValue = 0,
				maxValue = 100,
				valueStep = 5,
				allowInput = true,
				formatter = function(value) return string.format("%d%%", value) end,
			},
		},
	},
	{
		key = "SliderSimple",
		title = "Slider",
		color = { 0.85, 0.45, 0.2 },
		defaults = { point = "CENTER", x = 260, y = 120, slider = 10 },
		settings = {
			{
				name = "Slider",
				kind = EditMode.SettingType.Slider,
				field = "slider",
				default = 10,
				minValue = 0,
				maxValue = 20,
				valueStep = 1,
				allowInput = false,
				formatter = function(value) return tostring(value) end,
			},
		},
	},
	{
		key = "Color",
		title = "Color",
		color = { 0.6, 0.35, 0.85 },
		defaults = { point = "CENTER", x = -260, y = 20, color = { 0.3, 0.7, 1, 1 } },
		settings = {
			{
				name = "Color",
				kind = EditMode.SettingType.Color,
				field = "color",
				default = { 0.3, 0.7, 1, 1 },
				hasOpacity = true,
			},
		},
	},
	{
		key = "CheckboxColor",
		title = "Checkbox + Color",
		color = { 0.95, 0.5, 0.3 },
		defaults = {
			point = "CENTER",
			x = -80,
			y = 20,
			checkboxColorEnabled = true,
			checkboxColor = { 1, 0.8, 0.2, 1 },
		},
		settings = {
			{
				name = "Checkbox + Color",
				kind = EditMode.SettingType.CheckboxColor,
				field = "checkboxColorEnabled",
				default = true,
				colorField = "checkboxColor",
				colorDefault = { 1, 0.8, 0.2, 1 },
				hasOpacity = true,
			},
		},
	},
	{
		key = "OverlayToggle",
		title = "Overlay Toggle",
		color = { 0.4, 0.7, 0.9 },
		defaults = {
			point = "CENTER",
			x = -80,
			y = -80,
			enableOverlayToggle = true,
			allowDrag = true,
			collapseExclusive = true,
		},
		settings = {
			{
				name = "Example toggle",
				kind = EditMode.SettingType.Checkbox,
				field = "demoToggle",
				default = true,
			},
			{
				name = "Collapse exclusives",
				kind = EditMode.SettingType.Checkbox,
				field = "collapseExclusive",
				default = true,
				set = function(layout, value)
					setField("OverlayToggle", "collapseExclusive", value, layout)
					EditMode:SetFrameCollapseExclusive(_G["LibEMIExample_OverlayToggle_Frame"], value)
				end,
				get = function(layout)
					return getField("OverlayToggle", "collapseExclusive", true, layout)
				end,
				tooltip = "When enabled, expanding one collapsible will collapse the others.",
			},
			{
				name = "Disable drag when parented",
				kind = EditMode.SettingType.Checkbox,
				field = "dragCondition",
				default = false,
				set = function(layout, value)
					setField("OverlayToggle", "dragCondition", value, layout)
					local frame = _G["LibEMIExample_OverlayToggle_Frame"]
					if frame then
						if value then
							EditMode:SetFrameDragEnabled(frame, function()
								return frame:GetParent() == UIParent
							end)
						else
							EditMode:SetFrameDragEnabled(frame, nil)
						end
					end
				end,
				get = function(layout)
					return getField("OverlayToggle", "dragCondition", false, layout)
				end,
				tooltip = "If enabled, drag/nudge only works when parent is UIParent.",
			},
		},
	},
	{
		key = "DropdownColor",
		title = "Dropdown + Color",
		color = { 0.2, 0.7, 0.7 },
		defaults = {
			point = "CENTER",
			x = 100,
			y = 20,
			dropdownColorChoice = "Default",
			dropdownColor = { 0.2, 0.8, 0.2, 1 },
		},
		settings = {
			{
				name = "Dropdown + Color",
				kind = EditMode.SettingType.DropdownColor,
				field = "dropdownColorChoice",
				default = "Default",
				values = {
					{ text = "Default" },
					{ text = "Smooth" },
					{ text = "Flat" },
				},
				colorField = "dropdownColor",
				colorDefault = { 0.2, 0.8, 0.2, 1 },
				hasOpacity = true,
			},
		},
	},
}

local function registerExample(example)
	local id = "LibEMIExample_" .. example.key
	local frame = createExampleFrame(id .. "_Frame", example.title, example.color or { 0.7, 0.7, 0.7 })

	-- position callback
	EditMode:AddFrame(frame, function(_, layoutName, point, x, y)
		setField(id, "point", point, layoutName)
		setField(id, "relativePoint", point, layoutName)
		setField(id, "x", x, layoutName)
		setField(id, "y", y, layoutName)

		frame:ClearAllPoints()
		frame:SetPoint(point, UIParent, point, x, y)
	end, {
		point = example.defaults.point,
		x = example.defaults.x,
		y = example.defaults.y,
		enableOverlayToggle = example.defaults.enableOverlayToggle,
		overlayToggleEnabled = example.defaults.overlayToggleEnabled,
		allowDrag = example.defaults.allowDrag,
		dragEnabled = example.defaults.dragEnabled,
		collapseExclusive = example.defaults.collapseExclusive,
		exclusiveCollapse = example.defaults.exclusiveCollapse,
	})

	-- settings rows
	local prepared = {}
	for i, setting in ipairs(example.settings or {}) do
		local copy = CopyTable(setting)
		local field = copy.field

		if copy.colorField then
			copy.colorGet = function(layout) return getField(id, copy.colorField, copy.colorDefault, layout) end
			copy.colorSet = function(layout, value) setField(id, copy.colorField, value, layout) end
			copy.colorField = nil
		end

		copy.get = copy.get
			or function(layout)
				return getField(id, field, copy.default, layout)
			end
		copy.set = copy.set
			or function(layout, value)
				setField(id, field, value, layout)
			end

		prepared[i] = copy
	end

	if #prepared > 0 then EditMode:AddFrameSettings(frame, prepared) end
end

for _, example in ipairs(examples) do
	registerExample(example)
end

-- optional: react to layout changes (for debugging/demo)
EditMode:RegisterCallback("layout", function(layoutName)
	print("|cff66ccffLibEQOL demo|r active layout:", layoutName or "(nil)")
end)
