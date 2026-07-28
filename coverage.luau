--!strict
--[=[
	CLI entry for the coverage system. Parses args, loads a repo adapter, hands
	both to the repo-agnostic orchestrator. See tools/coverage/README.md.

		lune run coverage.luau                     # the whole package
		lune run coverage.luau --per-file --recommend
		lune run coverage.luau --adapter=./tools/coverage/lune/adapters/coverage_self package=self
]=]

local process = require("@lune/process")

local adapterMod = require("./tools/coverage/lune/adapter")
local Orchestrator = require("./tools/coverage/lune/core/Orchestrator")

local DEFAULT_ADAPTER = "./tools/coverage/lune/adapters/fusion"

local selector = "all"
local adapterPath = DEFAULT_ADAPTER
local options: Orchestrator.Options = {}

local function number(arg: string, value: string): number
	return assert(tonumber(value), `{arg} expects a number, got '{value}'`)
end

for _, arg in process.args do
	local key, value = arg:match("^%-%-([%w%-]+)=(.*)$")
	if key == "adapter" then
		adapterPath = value :: string
	elseif key == "mutate-limit" then
		options.mutateLimit = number(key, value :: string)
	elseif key == "mutate-ops" then
		options.mutateOps = value
	elseif key == "mutate-timeout" then
		options.mutateTimeout = number(key, value :: string)
	elseif key == "timeout" then
		options.timeout = number(key, value :: string)
	elseif key == "roblox-runner" then
		options.robloxRunner = value
	elseif arg == "--json" then
		options.json = true
	elseif arg == "--per-test" then
		options.perTest = true
	elseif arg == "--per-file" then
		options.perFile = true
	elseif arg == "--no-conditions" then
		options.noConditions = true
	elseif arg == "--suggest-const" then
		options.suggestConst = true
	elseif arg == "--mutate" then
		options.mutate = true
	elseif arg == "--recommend" then
		options.recommend = true
	elseif arg == "--lune-only" then
		options.luneOnly = true
	elseif arg == "--roblox-only" then
		options.robloxOnly = true
	elseif arg == "--rebuild-engine" then
		options.rebuildEngine = true
	elseif arg:match("^package=") then
		selector = arg:sub(#"package=" + 1)
	else
		error(`unknown argument '{arg}'`)
	end
end

-- Adapter path is data, so the require has to be dynamic.
local dynRequire: any = require
local adapter = adapterMod.validate(dynRequire(adapterPath))

local summary = Orchestrator.run(adapter, selector, options)
process.exit(if summary.failedTests > 0 then 1 else 0)
