--!strict
--!nolint LocalUnused
local task = nil -- Disable usage of Roblox's task scheduler

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = ReplicatedStorage.Fusion

local External = require(Fusion.External)
local Spring = require(Fusion.Animation.Spring)
local Value = require(Fusion.State.Value)
local peek = require(Fusion.State.peek)
local doCleanup = require(Fusion.Memory.doCleanup)

return function()
	local it = getfenv().it

	it("preserves velocity when setPosition is called after addVelocity", function()
		local expect = getfenv().expect

		local now = 100
		External.performUpdateStep(now)

		local scope = {}
		local goal = Value(scope, 0)
		local spring = Spring(scope, goal, 10, 1)
		local control = Spring(scope, goal, 10, 1)

		spring:addVelocity(10)
		spring:setPosition(5)
		control:setPosition(5)

		expect(peek(spring)).to.equal(5)

		External.performUpdateStep(now + 0.1)

		-- Both springs fall from 5 towards 0, but only `spring` carries the
		-- +10 velocity, so it must sit above the control.
		expect(peek(spring) > peek(control)).to.equal(true)

		doCleanup(scope)
	end)

	it("preserves position when addVelocity is called after setPosition", function()
		local expect = getfenv().expect

		local now = 200
		External.performUpdateStep(now)

		local scope = {}
		local goal = Value(scope, 0)
		local spring = Spring(scope, goal, 10, 1)

		spring:setPosition(5)
		spring:addVelocity(10)

		expect(peek(spring)).to.equal(5)

		External.performUpdateStep(now + 0.01)

		-- Motion must start from the set position, not from the goal.
		expect(peek(spring) > 4).to.equal(true)

		doCleanup(scope)
	end)

	it("preserves position when setVelocity is called after setPosition", function()
		local expect = getfenv().expect

		local now = 300
		External.performUpdateStep(now)

		local scope = {}
		local goal = Value(scope, 0)
		local spring = Spring(scope, goal, 10, 1)

		spring:setPosition(5)
		spring:setVelocity(10)

		expect(peek(spring)).to.equal(5)

		External.performUpdateStep(now + 0.01)

		expect(peek(spring) > 4).to.equal(true)

		doCleanup(scope)
	end)

	it("passes non-state goals through transparently", function()
		local expect = getfenv().expect

		local scope = {}
		local spring = Spring(scope, 5)

		expect(peek(spring)).to.equal(5)

		doCleanup(scope)
	end)

	it("sleeps and snaps to the goal once motion decays", function()
		local expect = getfenv().expect

		local now = 400
		External.performUpdateStep(now)

		local scope = {}
		local goal = Value(scope, 0)
		local spring = Spring(scope, goal, 10, 1)

		spring:setPosition(5)

		-- springCoefficients integrates analytically from the start position, so
		-- one large step is enough to reach the settled state.
		External.performUpdateStep(now + 2)
		expect(peek(spring)).to.equal(0)

		-- Stepping again exercises the already-asleep path.
		External.performUpdateStep(now + 3)
		expect(peek(spring)).to.equal(0)

		doCleanup(scope)
	end)

	it("accepts state objects for speed and damping", function()
		local expect = getfenv().expect

		local now = 500
		External.performUpdateStep(now)

		local scope = {}
		local goal = Value(scope, 0)
		local speed = Value(scope, 10)
		local spring = Spring(scope, goal, speed, Value(scope, 1))
		local control = Spring(scope, goal, 10, 1)

		spring:setPosition(5)
		control:setPosition(5)

		-- Reconfiguring speed mid-flight must change the motion. The spring
		-- integrates using the previous frame's parameters, so the new speed
		-- only takes effect on the frame after the reconfiguration.
		speed:set(50)
		External.performUpdateStep(now + 0.1)
		External.performUpdateStep(now + 0.2)

		expect(peek(spring) < peek(control)).to.equal(true)

		doCleanup(scope)
	end)

	it("animates every component of a multi-component type", function()
		local expect = getfenv().expect

		local now = 600
		External.performUpdateStep(now)

		local scope = {}
		local goal = Value(scope, Vector2.zero)
		local spring = Spring(scope, goal, 10, 1)

		spring:setPosition(Vector2.new(5, 7))
		spring:addVelocity(Vector2.new(1, 2))
		External.performUpdateStep(now + 0.1)

		local position = peek(spring)
		expect(position.X < 5 and position.X > 0).to.equal(true)
		expect(position.Y < 7 and position.Y > 0).to.equal(true)

		doCleanup(scope)
	end)

	it("reconfigures when the goal, speed or damping change", function()
		local expect = getfenv().expect

		local now = 1000
		External.performUpdateStep(now)

		local scope = {}
		local goal = Value(scope, 0)
		local speed = Value(scope, 10)
		local damping = Value(scope, 1)
		local spring = Spring(scope, goal, speed, damping)

		spring:setPosition(5)
		External.performUpdateStep(now + 0.1)

		-- Changed one at a time, because the reconfiguration test short-circuits
		-- as soon as any one parameter differs.
		damping:set(2)
		External.performUpdateStep(now + 0.2)

		goal:set(3)
		speed:set(20)
		External.performUpdateStep(now + 0.3)

		-- Motion continues from where it was, then settles on the new goal.
		External.performUpdateStep(now + 5)
		expect(peek(spring)).to.equal(3)

		doCleanup(scope)
	end)

	it("zeroes velocity when setVelocity is called with no argument", function()
		local expect = getfenv().expect

		local now = 700
		External.performUpdateStep(now)

		local scope = {}
		local goal = Value(scope, 0)
		local spring = Spring(scope, goal, 10, 1)
		local control = Spring(scope, goal, 10, 1)

		spring:setPosition(5)
		spring:addVelocity(10)
		spring:setVelocity()

		control:setPosition(5)

		External.performUpdateStep(now + 0.1)

		-- The added velocity must have been discarded, leaving both springs
		-- following the same trajectory.
		expect(peek(spring)).to.equal(peek(control))

		doCleanup(scope)
	end)

	it("rejects values of the wrong type", function()
		local expect = getfenv().expect

		local now = 800
		External.performUpdateStep(now)

		local scope = {}
		local goal = Value(scope, 0)
		local spring = Spring(scope, goal, 10, 1)

		expect(function()
			spring:setPosition(Vector2.zero :: any)
		end).to.throw()
		expect(function()
			spring:addVelocity(Vector2.zero :: any)
		end).to.throw()
		expect(function()
			spring:setVelocity(Vector2.zero :: any)
		end).to.throw()

		doCleanup(scope)
	end)

	it("ignores NaN goals", function()
		local expect = getfenv().expect

		local now = 900
		External.performUpdateStep(now)

		local scope = {}
		local goal = Value(scope, 0)
		local spring = Spring(scope, goal, 10, 1)

		spring:setPosition(5)
		goal:set(0 / 0)
		External.performUpdateStep(now + 0.1)

		-- The NaN goal is refused, so the spring keeps its last sane value.
		expect(peek(spring) == peek(spring)).to.equal(true)

		doCleanup(scope)
	end)
end
