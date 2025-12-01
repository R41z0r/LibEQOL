std = "lua51"
max_line_length = false

ignore = {
	"211", -- unused locals
	"212", -- unused arguments
	"213", -- unused loop variable
	"214", -- unused field in table literal
	"231", -- value assigned to variable is unused
}

globals = {
	"LibStub",
	"Mixin",
	"CopyTable",
	"CreateFrame",
	"CreateUnsecuredObjectPool",
	"UIParent",
	"Enum",
	"HUD_EDIT_MODE_HIDE",
	"HUD_EDIT_MODE_SHOW",
	"C_EditMode",
	"C_SpecializationInfo",
	"InCombatLockdown",
	"IsShiftKeyDown",
	"securecallfunction",
	"EventRegistry",
	"EditModeManagerFrame",
	"IsInEditMode",
	"GetBuildInfo",
	"GameTooltip",
	"ButtonStateBehaviorMixin",
	"DefaultTooltipMixin",
	"MenuConstants",
	"Settings",
	"ColorPickerFrame",
	"SOUNDKIT",
	"HUD_EDIT_MODE_RESET_POSITION",
	"RESET_TO_DEFAULT",
	"GenerateClosure",
	"CUSTOM",
	"CreateMinimalSliderFormatter",
	"MinimalSliderWithSteppersMixin",
	"DEFAULT_CHAT_FRAME",
	"GameFontHighlightSmall",
	"GameFontDisableSmall",
	"GameFontHighlightMedium",
	"GameFontDisable",
	"GameFontHighlight",
	"GameFontHighlightLarge",
	"GameFontNormal",
	"GameFontNormalSmall",
	"GameFontNormalSmall2",
	"GameFontHighlightSmall2",
	"KeyBindingFrameBindingTemplateMixin",
	"KeyBindingButtonMixin",
	"KeyBindingButtonTemplateMixin",
	"ColorMixin",
	"UIParentBottomLeft",
	"UIParentBottomMiddle",
	"UIParentBottomRight",
	"UIParentTopLeft",
	"UIParentTopMiddle",
	"UIParentTopRight",
	"UIParentMiddleLeft",
	"UIParentMiddleMiddle",
	"UIParentMiddleRight",
}

files = {
	["libs/LibStub/LibStub.lua"] = {
		max_line_length = false,
		globals = {
			"strmatch",
		},
	},
}
