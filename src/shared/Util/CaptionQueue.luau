--!strict
-- A bounded queue, driven by the caller's monotonic clock. Missed display
-- intervals never cause a burst of obsolete captions on the next frame.
export type Caption = {
	text: string,
	cue: string?,
	priority: number,
	expires: number,
	untilAt: number,
}
local Queue = {}
function Queue.new(config: any, seconds: number)
	local active: Caption? = nil
	local pending: { Caption } = {}
	local api = {}
	function api.tick(now: number): Caption?
		for i = #pending, 1, -1 do
			if pending[i].expires <= now then
				table.remove(pending, i)
			end
		end
		if active and active.untilAt > now then
			return active
		end
		active = nil
		local best: number? = nil
		for i, caption in pending do
			if not best or caption.priority > pending[best].priority then
				best = i
			end
		end
		if best then
			local nextCaption = table.remove(pending, best) :: Caption
			nextCaption.untilAt = now + seconds
			active = nextCaption
		end
		return active
	end
	function api.push(text: string, cue: string?, now: number): Caption?
		api.tick(now)
		if text == "" or (active and active.text == text) then
			return active
		end
		for _, caption in pending do
			if caption.text == text then
				return active
			end
		end
		local priority = if cue
			then config.priorities[cue] or config.defaultPriority
			else config.defaultPriority
		local caption: Caption = {
			text = text,
			cue = cue,
			priority = priority,
			expires = now + config.maxWaitSeconds,
			untilAt = now + seconds,
		}
		if not active or (priority >= config.urgentPriority and priority > active.priority) then
			active = caption
			return active
		end
		if #pending >= config.maxPending then
			local lowest = 1
			for i, item in pending do
				if item.priority < pending[lowest].priority then
					lowest = i
				end
			end
			if priority < pending[lowest].priority then
				return active
			end
			table.remove(pending, lowest)
		end
		table.insert(pending, caption)
		return active
	end
	function api.pendingCount(): number
		return #pending
	end
	function api.clear()
		active = nil
		table.clear(pending)
	end
	return api
end
return Queue
