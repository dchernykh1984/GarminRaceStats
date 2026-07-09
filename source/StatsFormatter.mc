import Toybox.Lang;

//! Pure helpers that map the opaque per-bib stats dictionary returned by the
//! site to the values the data field renders. Deliberately free of any Toybox
//! UI, Storage or Communications dependency so it can be exercised directly by
//! the unit tests in StatsFormatterTest.mc.
module StatsFormatter {
    //! The stats keys this build understands: the base set (SPEC section 5) plus
    //! the extend-live-stats additions (leader gaps and per-lap gap deltas). A
    //! key the server adds later that is not in this set is simply ignored by an
    //! old build, which is the backward-compatibility contract in SPEC section 7.
    //!
    //! The array index is what the settings dropdown stores (see keyForIndex), so
    //! new keys are appended (indices 9+) and the original 0-8 order is never
    //! reshuffled, otherwise a saved metricIndex would point at a different key.
    const KNOWN_KEYS =
        [
            "place_group",
            "qty_group",
            "gap_prev_group",
            "gap_next_group",
            "place_abs",
            "qty_abs",
            "gap_prev_abs",
            "gap_next_abs",
            "laps",
            "gap_leader_abs",
            "gap_prev_abs_delta",
            "gap_next_abs_delta",
            "gap_leader_abs_delta",
            "gap_leader_group",
            "gap_prev_group_delta",
            "gap_next_group_delta",
            "gap_leader_group_delta",
        ] as Array<String>;

    //! Value stored for `key` in `stats`, or an empty string when there is no
    //! data yet (null dictionary), the key is absent, or the value is not a
    //! string. The field renders blank in every one of those cases and never
    //! throws, so a partial or missing snapshot can never crash the field.
    //! @param stats The cached per-bib dictionary, or null when nothing is cached
    //! @param key The metric key this field is configured to show
    //! @return The value to display, or "" when unavailable
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

    //! The metric key at `index` in KNOWN_KEYS, used to resolve the numeric
    //! dropdown selection stored in settings. An out-of-range index falls back
    //! to place_abs so a bad setting can never leave the field keyless.
    //! @param index The 0-based index from the settings dropdown
    //! @return The metric key for that index
    function keyForIndex(index as Number) as String {
        if (index >= 0 && index < KNOWN_KEYS.size()) {
            return KNOWN_KEYS[index];
        }
        return "place_abs";
    }

    //! Whether `key` is one of the v1 keys this build knows how to label.
    //! @param key The metric key to test
    //! @return true when the key is part of the v1 dictionary
    function isKnownKey(key as String) as Boolean {
        for (var i = 0; i < KNOWN_KEYS.size(); i++) {
            if (KNOWN_KEYS[i].equals(key)) {
                return true;
            }
        }
        return false;
    }

    //! Short human label for a metric key, shown by the data field next to the
    //! value. An unknown key falls back to the raw key so a future server-side
    //! key still renders something sensible instead of nothing.
    //! @param key The metric key to label
    //! @return A short label for the field header
    function labelFor(key as String) as String {
        var labels = {
            "place_group" => "Place (grp)",
            "qty_group" => "Riders (grp)",
            "gap_prev_group" => "Gap prev (grp)",
            "gap_next_group" => "Gap next (grp)",
            "place_abs" => "Place",
            "qty_abs" => "Riders",
            "gap_prev_abs" => "Gap prev",
            "gap_next_abs" => "Gap next",
            "laps" => "Laps",
            "gap_leader_abs" => "Gap leader",
            "gap_prev_abs_delta" => "Gap prev trend",
            "gap_next_abs_delta" => "Gap next trend",
            "gap_leader_abs_delta" => "Gap leader trend",
            "gap_leader_group" => "Gap leader (grp)",
            "gap_prev_group_delta" => "Gap prev trend (grp)",
            "gap_next_group_delta" => "Gap next trend (grp)",
            "gap_leader_group_delta" => "Gap leader trend (grp)",
        };
        var label = labels.get(key);
        if (label != null) {
            return label as String;
        }
        return key;
    }
}
