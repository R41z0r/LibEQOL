--[[
	Minimal example for LibEQOLNativeEditMode-1.0.
	Load this file in an addon together with LibEQOL and include LibEQOLNativeEditMode.xml.
]]

local LibStub = _G.LibStub
assert(LibStub, "LibEQOL native example requires LibStub")

local NativeEditMode = LibStub("LibEQOLNativeEditMode-1.0")
assert(NativeEditMode, "LibEQOLNativeEditMode-1.0 is not loaded")

local DB = { layouts = {} }
local DEFAULT_POINT, DEFAULT_X, DEFAULT_Y = "CENTER", 0, 80

local function getLayout(layoutName)
	local key = layoutName or NativeEditMode:GetActiveLayoutName() or "_Global"
	if not DB.layouts[key] then
		DB.layouts[key] = {}
	end
	return DB.layouts[key]
end

local function getField(layoutName, field, default)
	local layout = getLayout(layoutName)
	local value = layout[field]
	if value == nil then
		return default
	end
	return value
end

local function setField(layoutName, field, value)
	local layout = getLayout(layoutName)
	layout[field] = value
end

local frame = CreateFrame("Frame", "LibEQOLNativeExampleFrame", UIParent, "BackdropTemplate")
frame:SetSize(220, 60)
frame:SetFrameStrata("DIALOG")
frame:SetClampedToScreen(true)
frame:SetBackdrop({
	bgFile = "Interface/Buttons/WHITE8X8",
	edgeFile = "Interface/Buttons/WHITE8X8",
	edgeSize = 1,
})
frame:SetBackdropColor(0.08, 0.22, 0.45, 0.35)
frame:SetBackdropBorderColor(0.25, 0.70, 1.00, 0.95)

local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
label:SetPoint("CENTER")
label:SetText("LibEQOL Native Edit")

local function applyFramePosition(layoutName)
	local point = getField(layoutName, "point", DEFAULT_POINT)
	local x = getField(layoutName, "x", DEFAULT_X)
	local y = getField(layoutName, "y", DEFAULT_Y)
	frame:ClearAllPoints()
	frame:SetPoint(point, UIParent, point, x, y)
end

applyFramePosition()
frame:Show()

NativeEditMode:AddFrame(frame, function(self, layoutName, point, x, y)
	setField(layoutName, "point", point)
	setField(layoutName, "x", x)
	setField(layoutName, "y", y)

	applyFramePosition(layoutName)
end, {
	point = DEFAULT_POINT,
	x = DEFAULT_X,
	y = DEFAULT_Y,
	enableOverlayToggle = true,
	allowDrag = true,
})

NativeEditMode:AddFrameSettings(frame, {
	{
		name = "Show label",
		kind = NativeEditMode.SettingType.Checkbox,
		default = true,
		get = function(layoutName)
			return getField(layoutName, "showLabel", true)
		end,
		set = function(layoutName, value)
			setField(layoutName, "showLabel", value)
			label:SetShown(value)
		end,
	},
	{
		name = "Scale",
		kind = NativeEditMode.SettingType.Slider,
		default = 1,
		minValue = 0.5,
		maxValue = 2,
		valueStep = 0.05,
		allowInput = true,
		formatter = function(value)
			return string.format("%.2fx", value)
		end,
		get = function(layoutName)
			return getField(layoutName, "scale", 1)
		end,
		set = function(layoutName, value)
			setField(layoutName, "scale", value)
			frame:SetScale(value)
		end,
	},
})

NativeEditMode:RegisterCallback("layout", function(layoutName)
	applyFramePosition(layoutName)
end)

NativeEditMode:RegisterCallback("spec", function()
	applyFramePosition(NativeEditMode:GetActiveLayoutName())
end)

SLASH_LIBEQOLNATIVE1 = "/eqolnative"
SlashCmdList.LIBEQOLNATIVE = function(msg)
	msg = (msg or ""):lower()
	if msg == "on" then
		NativeEditMode:EnterEditMode()
	elseif msg == "off" then
		NativeEditMode:ExitEditMode()
	elseif msg == "where" then
		local point, _, _, x, y = frame:GetPoint(1)
		print(string.format("|cff66ccffLibEQOL native example|r point=%s x=%.1f y=%.1f", point or "?", x or 0, y or 0))
	elseif msg == "reset" then
		setField(nil, "point", DEFAULT_POINT)
		setField(nil, "x", DEFAULT_X)
		setField(nil, "y", DEFAULT_Y)
		applyFramePosition()
		frame:SetScale(1)
	elseif msg == "grid" then
		NativeEditMode:SetGridEnabled(not NativeEditMode:GetGridEnabled())
	else
		NativeEditMode:ToggleEditMode()
	end
end

print("|cff66ccffLibEQOL native example|r loaded. Use /eqolnative (toggle), /eqolnative where, /eqolnative reset")
