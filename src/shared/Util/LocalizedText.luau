--!strict
-- Keep producer text separate from our last rendering. Property signals can
-- arrive after a translated write; a boolean writing guard cannot identify it.
local Text = {}
export type State = { source: string, rendered: string }
function Text.new(source: string): State
	return { source = source, rendered = source }
end
function Text.render(
	state: State,
	current: string,
	locale: string,
	translate: (string, string) -> string
): string
	if current ~= state.rendered then
		state.source = current
	end
	state.rendered = translate(state.source, locale)
	return state.rendered
end
function Text.original(state: State, current: string): string
	return if current ~= state.rendered then current else state.source
end
return Text
