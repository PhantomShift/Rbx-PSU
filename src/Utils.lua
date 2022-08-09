local Utils = {}

function Utils.waitForCondition(signal: RBXScriptSignal, filter: (...any) -> boolean)
	local b = Instance.new("BindableEvent")
	local c: RBXScriptConnection
	c = signal:Connect(function(...)
		if filter(...) then
			c:Disconnect()
			b:Fire(...)
		end
	end)
	return b.Event:Wait()
end

return Utils