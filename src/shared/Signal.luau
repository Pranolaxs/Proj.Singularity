--!strict

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	return setmetatable({
		_connections = {},
	}, Signal) :: any
end

function Signal:Connect(callback)
	local connection = {
		Connected = true,
		_callback = callback,
	}

	function connection:Disconnect()
		self.Connected = false
	end

	table.insert(self._connections, connection)
	return connection
end

function Signal:Once(callback)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		callback(...)
	end)
	return connection
end

function Signal:Fire(...)
	local compacted = {}
	for _, connection in ipairs(self._connections) do
		if connection.Connected then
			table.insert(compacted, connection)
			task.spawn(connection._callback, ...)
		end
	end
	self._connections = compacted
end

function Signal:Destroy()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
end

return Signal
