-- Wrap every table in a horizontally scrollable container.
--
-- The site is almost entirely tabular and some tables (the sprint calendar, the
-- coverage matrix) are wider than a phone. Quarto emits a bare <table> with no
-- wrapper, and overflow-x is ignored on a table box — so without this the page
-- itself scrolls sideways.
--
-- Doing it here rather than with `table { display: block }` in CSS matters:
-- overriding a table's display drops it from the accessibility tree as a table
-- in WebKit/VoiceOver, costing row/column navigation and header association on
-- exactly the tables that carry the blueprint.
function Table(el)
  return pandoc.Div({ el }, pandoc.Attr("", { "table-scroll" }))
end
