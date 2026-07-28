--!strict
--[=[
	Runs a package's instrumented spec suite in-process under Lune, using
	`tiniest_for_lune` with the coverage plugin attached. Spec collection is
	rooted at the materialized build dir, so each spec's own relative requires
	resolve to the instrumented sources.
]=]

local fs = require("@lune/fs")

local adapter = require("../adapter")
type PackageSpec = adapter.PackageSpec

-- Require paths are resolved relative to THIS file. Repo root is four levels up
-- from tools/coverage/lune/core/.
local ROOT = "../../../../"

local LuneRunner = {}

export type RunOutput = {
	-- tiniest_coverage.CoverageResult: { hits, total, map_sha, per_test? }. Typed
	-- loosely so this module carries no load-time dependency on the framework --
	-- a repo whose packages all run on the Roblox pipeline has no tiniest at all.
	coverage: any,
	tally: { pass: number, fail: number, skipped: number },
	duration: number,
}

local function collectSpecs(dir: string, out: { string })
	for _, entry in fs.readDir(dir) do
		local full = dir .. "/" .. entry
		if fs.isDir(full) then
			if entry ~= "_Index" then
				collectSpecs(full, out)
			end
		elseif entry:match("%.spec%.luau$") then
			table.insert(out, full)
		end
	end
end

--[=[
	Runs the instrumented suite in `buildDir`. Returns coverage + tally.
]=]
function LuneRunner.run(spec: PackageSpec, buildDir: string, options: { timeout: number? }?): RunOutput
	local dynRequire: any = require
	local tiniest_coverage = dynRequire("@tiniest/tiniest_coverage")

	-- The emitted runtime module (same cached instance the instrumented
	-- sources require, since Lune caches by resolved path).
	local covPath = ROOT .. buildDir .. "/" .. spec.sourceRoot .. "/_cov"
	local runtime = dynRequire(covPath)

	local coveragePlugin = tiniest_coverage.configure {
		runtime = runtime,
		enable_per_test = true,
	}

	local tiniest = dynRequire(ROOT .. "test/tiniest/tiniest_for_lune").configure {
		snapshot_path = "./test/__snapshots__",
		save_snapshots = false,
		plugins = { coveragePlugin },
		pretty = {
			trim_duplicate_trace = true,
			hide_passed_tests = false,
		},
	}

	local specFiles: { string } = {}
	collectSpecs(buildDir .. "/" .. spec.sourceRoot, specFiles)

	local buildPrefix = buildDir .. "/"
	local tests = tiniest.collect_tests(function()
		local describe = tiniest.describe
		for _, file in specFiles do
			local requirePath = ROOT .. (file:gsub("%.luau$", ""))
			-- Label with the spec path relative to the build dir (drop the
			-- ".coverage/<pkg>/build/" prefix and ".luau" suffix).
			local label = (file:gsub("^" .. buildPrefix:gsub("([%-%.%+])", "%%%1"), ""):gsub("%.luau$", ""))
			describe(label, function()
				dynRequire(requirePath)(tiniest)
			end)
		end
	end)

	local runOptions: any = { safe_mode = true }
	if options and options.timeout then
		runOptions.timeout_seconds = options.timeout
	end

	local start = os.clock()
	local result = tiniest.run_tests(tests, runOptions)
	local duration = os.clock() - start

	return {
		coverage = result.coverage,
		tally = result.status_tally,
		duration = duration,
	}
end

return LuneRunner
