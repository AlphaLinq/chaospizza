--!strict
-- The caller must atomically persist this ledger WITH the granted profile.
-- External side effects require their own durable, idempotent outbox.
local ReceiptLedger = {}
function ReceiptLedger.contains(purchases: { [string]: number }, purchaseId: string): boolean
	return purchases[purchaseId] ~= nil
end
function ReceiptLedger.apply(
	purchases: { [string]: number },
	purchaseId: string,
	timestamp: number,
	grant: () -> boolean
): boolean
	if #purchaseId == 0 or timestamp ~= timestamp or timestamp < 0 or timestamp == math.huge then
		return false
	end
	if ReceiptLedger.contains(purchases, purchaseId) then
		return true
	end
	-- Never record failed grants; the caller discards the complete draft on failure.
	if grant() ~= true then
		return false
	end
	purchases[purchaseId] = math.floor(timestamp)
	return true
end
return ReceiptLedger
