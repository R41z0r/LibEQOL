--[[
	Example for LibEQOLDebugMode-1.0.
	Add this file after LibEQOLDebugMode.xml in your addon's TOC.
	Use /eqoldebugexample start|step|stop|report|clear
]]

local LibStub = _G.LibStub
assert(LibStub, "LibEQOL debug example requires LibStub")

local Debug = LibStub("LibEQOLDebugMode-1.0")
assert(Debug, "LibEQOLDebugMode-1.0 is not loaded")

LibEQOLDebugExampleDB = LibEQOLDebugExampleDB or {}

local BASIC_KEY = "LibEQOLDebugExample.Basic"
local DEEP_KEY = "LibEQOLDebugExample.Deep"

local function setupAddons()
	Debug:RegisterAddon(BASIC_KEY, {
		tier = "basic",
		limits = {
			maxEventsPerSession = 100,
			maxSessions = 5,
		},
	})

	Debug:RegisterAddon(DEEP_KEY, {
		tier = "deep",
		persistence = {
			enabled = true,
			savedRoot = LibEQOLDebugExampleDB,
			path = { "ExampleDeep", "Debug" },
		},
		limits = {
			maxEventsPerSession = 150,
			maxSessions = 10,
			maxPayloadBytes = 2048,
			maxSpanDepth = 16,
		},
	})
end

local function startSessions()
	setupAddons()
	local basicId, basicErr = Debug:StartSession(BASIC_KEY)
	local deepId, deepErr = Debug:StartSession(DEEP_KEY)
	print("|cff66ccffLibEQOLDebug example|r start basic=", basicId or "nil", basicErr or "")
	print("|cff66ccffLibEQOLDebug example|r start deep=", deepId or "nil", deepErr or "")
end

local function runStep()
	Debug:Trace(BASIC_KEY, "OpenConfig", { tab = "General" })
	Debug:CaptureError(BASIC_KEY, "ApplyConfig", "Example warning", { value = "invalid" })

	local rootSpan = Debug:BeginSpan(DEEP_KEY, "HandleSlashCommand", { command = "step" })
	Debug:Trace(DEEP_KEY, "ValidateInput", { ok = true })

	local childSpan = Debug:BeginSpan(DEEP_KEY, "RunAction", { action = "simulate" })
	local wrapped = Debug:Wrap(DEEP_KEY, "RiskyCall", function(shouldFail)
		if shouldFail then
			error("simulated failure")
		end
		return "ok"
	end, { rethrow = false })

	if wrapped then
		wrapped(false)
		wrapped(true)
	end

	if childSpan then
		Debug:EndSpan(DEEP_KEY, childSpan, "ok", { note = "child done" })
	end
	if rootSpan then
		Debug:EndSpan(DEEP_KEY, rootSpan, "ok")
	end

	print("|cff66ccffLibEQOLDebug example|r captured one step")
end

local function stopSessions()
	local basicId, basicErr = Debug:StopSession(BASIC_KEY, "manual-stop")
	local deepId, deepErr = Debug:StopSession(DEEP_KEY, "manual-stop")
	print("|cff66ccffLibEQOLDebug example|r stop basic=", basicId or "nil", basicErr or "")
	print("|cff66ccffLibEQOLDebug example|r stop deep=", deepId or "nil", deepErr or "")
end

local function printReport(addonKey)
	local report, text, err = Debug:BuildReport(addonKey)
	if not report then
		print("|cff66ccffLibEQOLDebug example|r report error:", err or "unknown")
		return
	end
	print("|cff66ccffLibEQOLDebug example|r report for", addonKey, "events=", report.eventCount)
	print(text)
end

local function clearHistory()
	Debug:ClearActiveSession(BASIC_KEY)
	Debug:ClearActiveSession(DEEP_KEY)
	Debug:ClearStoredSessions(BASIC_KEY)
	Debug:ClearStoredSessions(DEEP_KEY)
	print("|cff66ccffLibEQOLDebug example|r cleared")
end

SLASH_LIBEQOLDEBUGEXAMPLE1 = "/eqoldebugexample"
SlashCmdList.LIBEQOLDEBUGEXAMPLE = function(msg)
	msg = (msg or ""):lower()
	if msg == "start" then
		startSessions()
	elseif msg == "step" then
		runStep()
	elseif msg == "stop" then
		stopSessions()
	elseif msg == "report" then
		printReport(BASIC_KEY)
		printReport(DEEP_KEY)
	elseif msg == "clear" then
		clearHistory()
	else
		print("|cff66ccffLibEQOLDebug example|r commands: start, step, stop, report, clear")
	end
end

print("|cff66ccffLibEQOLDebug example|r loaded. Use /eqoldebugexample")
