import Toybox.Lang;
import Toybox.WatchUi;

//! Pure helpers that map the opaque per-bib stats dictionary returned by the
//! site to the values the data field renders. The value helpers are free of any
//! Toybox UI/Storage/Communications dependency so they can be exercised directly
//! by the unit tests; labelFor is the one exception (it loads a localized
//! string resource for the device language).
module StatsFormatter {
    //! Every stats key this build understands: the base set (SPEC section 5) plus
    //! the extend-live-stats additions (leader gaps and per-lap gap deltas). Used
    //! only by isKnownKey - a key the server adds later that is not in this set is
    //! simply ignored by an old build (the backward-compatibility contract in SPEC
    //! section 7). This still includes qty_group/qty_abs: they are no longer shown
    //! on their own, but the server keeps sending them and place folds them in.
    const KNOWN_KEYS =
        [
            "place_group",
            "qty_group",
            "gap_prev_group",
            "gap_next_group",
            "gap_leader_group",
            "gap_prev_group_delta",
            "gap_next_group_delta",
            "gap_leader_group_delta",
            "place_abs",
            "qty_abs",
            "gap_prev_abs",
            "gap_next_abs",
            "gap_leader_abs",
            "gap_prev_abs_delta",
            "gap_next_abs_delta",
            "gap_leader_abs_delta",
            "laps",
        ] as Array<String>;

    //! The metrics the rider can pick for a field, in the order the settings
    //! dropdown lists them; the stored metricIndex is an index into this array.
    //! qty is intentionally absent - it is shown as "place/qty" by the two place
    //! metrics instead of on its own.
    const METRICS =
        [
            "place_abs",
            "place_group",
            "gap_prev_abs",
            "gap_next_abs",
            "gap_leader_abs",
            "gap_prev_abs_delta",
            "gap_next_abs_delta",
            "gap_leader_abs_delta",
            "gap_prev_group",
            "gap_next_group",
            "gap_leader_group",
            "gap_prev_group_delta",
            "gap_next_group_delta",
            "gap_leader_group_delta",
            "laps",
        ] as Array<String>;

    //! Default metric index (into METRICS); 0 == place_abs.
    const DEFAULT_METRIC_INDEX = 0;

    //! The most rows the field will ever draw in its slot. Edge screens split into
    //! at most 10 native cells, so 10 is the practical ceiling for one field too.
    const MAX_ROWS = 10;

    //! A row thinner than this is unreadable on device, so rows are dropped
    //! rather than squeezed below it.
    const MIN_ROW_HEIGHT = 22;

    //! Clamp a configured row count into 1..MAX_ROWS, so a bad setting can never
    //! make the field draw nothing (or more rows than it has metrics for).
    //! @param configured The row count from settings
    //! @return The row count to use
    function clampRowCount(configured as Number) as Number {
        if (configured < 1) {
            return 1;
        }
        if (configured > MAX_ROWS) {
            return MAX_ROWS;
        }
        return configured;
    }

    //! How many rows actually fit in a slot `heightPx` tall. The rider picks the
    //! native screen layout, so the slot can be anything from the full screen to
    //! a thin strip; we draw as many of the configured rows as stay readable and
    //! always draw at least one.
    //! @param configured The row count from settings
    //! @param heightPx The slot height reported by the device context
    //! @param minRowHeightPx The smallest readable row height
    //! @return The number of rows to draw
    function visibleRows(
        configured as Number,
        heightPx as Number,
        minRowHeightPx as Number
    ) as Number {
        var rows = clampRowCount(configured);
        if (minRowHeightPx <= 0) {
            return rows;
        }
        var fits = heightPx / minRowHeightPx;
        if (fits < 1) {
            fits = 1;
        }
        if (fits < rows) {
            return fits;
        }
        return rows;
    }

    //! A grid cell stacks a label above its value, so it needs more height than a
    //! single side-by-side row.
    const MIN_CELL_HEIGHT = 34;

    //! Below this slot width two columns would be too narrow to read.
    const MIN_TWO_COLUMN_WIDTH = 180;

    //! With fewer metrics than this, a single column reads better than a grid.
    const MIN_TWO_COLUMN_METRICS = 4;

    //! How many columns to draw in a slot: one tall list, or a two-column grid
    //! like the native Garmin data screen. A grid only pays off when there are
    //! enough metrics and the slot is wide and tall enough for readable cells;
    //! a thin cell from an 8-field layout stays a single column.
    //! @param metricCount How many metrics the rider configured
    //! @param widthPx The slot width
    //! @param heightPx The slot height
    //! @return 1 or 2
    function columnCount(metricCount as Number, widthPx as Number, heightPx as Number) as Number {
        if (metricCount < MIN_TWO_COLUMN_METRICS) {
            return 1;
        }
        if (widthPx < MIN_TWO_COLUMN_WIDTH) {
            return 1;
        }
        if (heightPx < 2 * MIN_CELL_HEIGHT) {
            return 1;
        }
        return 2;
    }

    //! How many cells actually fit, given the columns and the readable minimum
    //! cell height. Always at least one, never more than configured.
    //! @param configured The row count from settings
    //! @param columns The column count from columnCount
    //! @param heightPx The slot height
    //! @param minCellHeight The smallest readable cell height
    //! @return The number of cells to draw
    function visibleCells(
        configured as Number,
        columns as Number,
        heightPx as Number,
        minCellHeight as Number
    ) as Number {
        var cells = clampRowCount(configured);
        if (minCellHeight <= 0 || columns < 1) {
            return cells;
        }
        var rows = heightPx / minCellHeight;
        if (rows < 1) {
            rows = 1;
        }
        var fits = rows * columns;
        if (fits < cells) {
            return fits;
        }
        return cells;
    }

    //! Grid rows needed for `cells` cells laid out in `columns` columns.
    //! @param cells The number of cells drawn
    //! @param columns The column count
    //! @return The number of grid rows
    function gridRows(cells as Number, columns as Number) as Number {
        if (columns < 1) {
            return cells;
        }
        return (cells + columns - 1) / columns;
    }

    //! Index of the largest font that fits a box, given each candidate font's
    //! measured width and height (candidates ordered smallest first). Falls back
    //! to the smallest font when nothing fits, so a row is always drawn rather
    //! than dropped. Pure on purpose: the view measures, this decides.
    //! @param widths Measured text width per candidate font
    //! @param heights Measured text height per candidate font
    //! @param maxWidth The width the text may occupy
    //! @param maxHeight The height the text may occupy
    //! @return The index of the font to use
    function largestFontIndex(
        widths as Array<Number>,
        heights as Array<Number>,
        maxWidth as Number,
        maxHeight as Number
    ) as Number {
        for (var i = widths.size() - 1; i > 0; i--) {
            if (widths[i] <= maxWidth && heights[i] <= maxHeight) {
                return i;
            }
        }
        return 0;
    }

    //! Value stored for `key` in `stats`, or an empty string when there is no
    //! data yet (null dictionary), the key is absent, or the value is not a
    //! string. Never throws, so a partial or missing snapshot can never crash the
    //! field. This is the raw single-key lookup; place composition is in
    //! displayValue.
    //! @param stats The cached per-bib dictionary, or null when nothing is cached
    //! @param key The stats key to read
    //! @return The value stored for the key, or "" when unavailable
    function valueFor(stats as Dictionary?, key as String) as String {
        if (stats == null) {
            return "";
        }
        var value = stats.get(key);
        if (value instanceof String) {
            return value;
        }
        return "";
    }

    //! The value to render for a picked metric. For the two place metrics this is
    //! "place/qty" (e.g. "17/84"); for everything else it is the raw key value.
    //! @param stats The cached per-bib dictionary, or null when nothing is cached
    //! @param metric A metric from METRICS
    //! @return The display string, or "" when unavailable
    function displayValue(stats as Dictionary?, metric as String) as String {
        if (metric.equals("place_abs")) {
            return placeValue(stats, "place_abs", "qty_abs");
        }
        if (metric.equals("place_group")) {
            return placeValue(stats, "place_group", "qty_group");
        }
        return valueFor(stats, metric);
    }

    //! Placeholder drawn when a value is not available yet - the same "no data"
    //! dashes a native Garmin field shows before its sensor reports.
    const NO_VALUE = "--";

    //! Like displayValue, but never blank: a missing value becomes NO_VALUE. This
    //! is what the field actually draws, so an unconfigured or not-yet-fetched
    //! field reads as "waiting for data" instead of looking broken (a store
    //! reviewer testing it has no race configured, so every value is missing).
    //! @param stats The cached per-bib dictionary, or null when nothing is cached
    //! @param metric A metric from METRICS
    //! @return The display string, or NO_VALUE when unavailable
    function displayOr(stats as Dictionary?, metric as String) as String {
        var value = displayValue(stats, metric);
        if (value.equals("")) {
            return NO_VALUE;
        }
        return value;
    }

    //! "place/qty" (e.g. "17/84"), or just the place when qty is missing, or ""
    //! when there is no place yet. A non-numeric place (e.g. "DSQ") is shown on
    //! its own, since "DSQ/84" would be nonsense.
    //! @param stats The cached per-bib dictionary, or null when nothing is cached
    //! @param placeKey The place key (place_abs or place_group)
    //! @param qtyKey The matching field-size key (qty_abs or qty_group)
    //! @return The composed place string, or "" when there is no place
    function placeValue(stats as Dictionary?, placeKey as String, qtyKey as String) as String {
        var place = valueFor(stats, placeKey);
        if (place.equals("")) {
            return "";
        }
        var qty = valueFor(stats, qtyKey);
        if (qty.equals("") || place.toNumber() == null) {
            return place;
        }
        return place + "/" + qty;
    }

    //! The metric for a settings dropdown index. An out-of-range index falls back
    //! to the default (place_abs) so a bad setting can never leave the field
    //! metric-less.
    //! @param index The 0-based index from the settings dropdown
    //! @return The metric for that index
    function metricForIndex(index as Number) as String {
        if (index >= 0 && index < METRICS.size()) {
            return METRICS[index];
        }
        return METRICS[DEFAULT_METRIC_INDEX];
    }

    //! Whether `key` is one of the keys this build knows (base + extension).
    //! @param key The stats key to test
    //! @return true when the key is part of the known dictionary
    function isKnownKey(key as String) as Boolean {
        for (var i = 0; i < KNOWN_KEYS.size(); i++) {
            if (KNOWN_KEYS[i].equals(key)) {
                return true;
            }
        }
        return false;
    }

    //! Localized field-header label for a metric, loaded from the string
    //! resources so it follows the device language. Kept at most 12 characters in
    //! every shipped language so it is not truncated on device. An unknown metric
    //! falls back to its raw id so a future metric still renders something.
    //! @param metric A metric from METRICS
    //! @return The localized field-header label
    function labelFor(metric as String) as String {
        var id = labelResourceId(metric);
        if (id == null) {
            return metric;
        }
        return WatchUi.loadResource(id) as String;
    }

    //! Maps a metric to its Rez string resource id, or null for an unknown
    //! metric. Split out from labelFor so the mapping is easy to keep in step
    //! with METRICS and resources/strings/strings.xml.
    //! @param metric A metric from METRICS
    //! @return The resource id, or null when the metric is unknown
    function labelResourceId(metric as String) as Lang.ResourceId? {
        var ids = {
            "place_abs" => Rez.Strings.MetricPlaceAbs,
            "place_group" => Rez.Strings.MetricPlaceGroup,
            "gap_prev_abs" => Rez.Strings.MetricGapPrevAbs,
            "gap_next_abs" => Rez.Strings.MetricGapNextAbs,
            "gap_leader_abs" => Rez.Strings.MetricGapLeaderAbs,
            "gap_prev_abs_delta" => Rez.Strings.MetricGapPrevAbsDelta,
            "gap_next_abs_delta" => Rez.Strings.MetricGapNextAbsDelta,
            "gap_leader_abs_delta" => Rez.Strings.MetricGapLeaderAbsDelta,
            "gap_prev_group" => Rez.Strings.MetricGapPrevGroup,
            "gap_next_group" => Rez.Strings.MetricGapNextGroup,
            "gap_leader_group" => Rez.Strings.MetricGapLeaderGroup,
            "gap_prev_group_delta" => Rez.Strings.MetricGapPrevGroupDelta,
            "gap_next_group_delta" => Rez.Strings.MetricGapNextGroupDelta,
            "gap_leader_group_delta" => Rez.Strings.MetricGapLeaderGroupDelta,
            "laps" => Rez.Strings.MetricLaps,
        };
        return ids.get(metric) as Lang.ResourceId?;
    }
}
