import Toybox.Lang;

//! Pure helpers that map the opaque per-bib stats dictionary returned by the
//! site to the values the data field renders. Deliberately free of any Toybox
//! UI, Storage or Communications dependency so it can be exercised directly by
//! the unit tests in StatsFormatterTest.mc.
module StatsFormatter {
    //! The v1 stats keys this build understands (see SPEC section 5). A key the
    //! server adds later that is not in this set is simply ignored by an old
    //! build, which is the backward-compatibility contract in SPEC section 7.
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
        };
        var label = labels.get(key);
        if (label != null) {
            return label as String;
        }
        return key;
    }
}
