import Toybox.Lang;

//! Pure helpers that map the opaque per-bib stats dictionary returned by the
//! site to the values the data field renders. Deliberately free of any Toybox
//! UI, Storage or Communications dependency so it can be exercised directly by
//! the unit tests in StatsFormatterTest.mc.
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

    //! Short field-header label for a metric (at most 11 characters so it is not
    //! truncated on device). An unknown metric falls back to its raw id so a
    //! future metric still renders something instead of nothing.
    //! @param metric A metric from METRICS
    //! @return The field-header label
    function labelFor(metric as String) as String {
        var labels = {
            "place_abs" => "Place abs",
            "place_group" => "Place gr",
            "gap_prev_abs" => "Behind abs",
            "gap_next_abs" => "Ahead abs",
            "gap_leader_abs" => "Leader abs",
            "gap_prev_abs_delta" => "Bhd abs d",
            "gap_next_abs_delta" => "Ahd abs d",
            "gap_leader_abs_delta" => "Ldr abs d",
            "gap_prev_group" => "Behind gr",
            "gap_next_group" => "Ahead gr",
            "gap_leader_group" => "Leader gr",
            "gap_prev_group_delta" => "Bhd gr d",
            "gap_next_group_delta" => "Ahd gr d",
            "gap_leader_group_delta" => "Ldr gr d",
            "laps" => "Laps",
        };
        var label = labels.get(metric);
        if (label != null) {
            return label as String;
        }
        return metric;
    }
}
