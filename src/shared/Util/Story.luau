--!strict
-- Pure story-order progress (#254). `progress[id]` = chapters done.

local Story = {}

export type Chapter = { customer: string, address: string, line: string }
export type Def = { id: string, title: string, chapters: { Chapter }, ending: string }

-- The first unfinished story and its next chapter (1-based), or nil.
function Story.next(stories: { Def }, progress: { [string]: number }): (Def?, number?)
	for _, s in stories do
		local done = math.max(0, math.floor(progress[s.id] or 0))
		if done < #s.chapters then
			return s, done + 1
		end
	end
	return nil, nil
end

function Story.isLast(story: Def, chapter: number): boolean
	return chapter >= #story.chapters
end

-- "Grandpa's Marathon · 2/3"
function Story.label(story: Def, chapter: number): string
	return `{story.title} · {chapter}/{#story.chapters}`
end

-- Progress table from profile claims ("story.<id>" = number).
function Story.fromClaims(claims: { [string]: any }, stories: { Def }): { [string]: number }
	local out: { [string]: number } = {}
	for _, s in stories do
		local v = claims[`story.{s.id}`]
		out[s.id] = if typeof(v) == "number" then v else 0
	end
	return out
end

return Story
