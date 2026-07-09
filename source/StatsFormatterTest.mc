import Toybox.Lang;
import Toybox.Test;

//! Unit tests for the pure StatsFormatter helpers. These run under the Connect
//! IQ "Run No Evil" harness: each (:test) function takes a Logger, returns a
//! Boolean, and is stripped from non-test (release) builds automatically.

//! A present string key returns its stored value verbatim (raw lookup).
(:test)
function valueForReturnsStoredString(logger as Test.Logger) as Boolean {
    var stats = ({ "place_abs" => "17" }) as Dictionary;
    return StatsFormatter.valueFor(stats, "place_abs").equals("17");
}

//! An absent key, and a null snapshot, both render blank rather than throwing.
(:test)
function valueForBlankWhenMissingOrNull(logger as Test.Logger) as Boolean {
    var stats = ({ "place_abs" => "17" }) as Dictionary;
    return (
        StatsFormatter.valueFor(stats, "laps").equals("") &&
        StatsFormatter.valueFor(null, "place_abs").equals("")
    );
}

//! A non-string value (defensive: the contract is all strings) renders blank.
(:test)
function valueForBlankWhenValueNotString(logger as Test.Logger) as Boolean {
    var stats = ({ "place_abs" => 17 }) as Dictionary;
    return StatsFormatter.valueFor(stats, "place_abs").equals("");
}

//! A delta value is rendered verbatim, including a negative sign (gap shrank).
(:test)
function valueForRendersSignedDelta(logger as Test.Logger) as Boolean {
    var stats = ({ "gap_prev_abs_delta" => "-0:20" }) as Dictionary;
    return StatsFormatter.valueFor(stats, "gap_prev_abs_delta").equals("-0:20");
}

//! A place metric combines place and field size as "place/qty".
(:test)
function displayValuePlaceCombinesPlaceAndQty(logger as Test.Logger) as Boolean {
    var stats = ({ "place_abs" => "17", "qty_abs" => "84" }) as Dictionary;
    return StatsFormatter.displayValue(stats, "place_abs").equals("17/84");
}

//! With no field size yet, a place metric shows the place on its own.
(:test)
function displayValuePlaceWithoutQtyShowsPlaceOnly(logger as Test.Logger) as Boolean {
    var stats = ({ "place_group" => "3" }) as Dictionary;
    return StatsFormatter.displayValue(stats, "place_group").equals("3");
}

//! A disqualified rider shows "DSQ" alone, never "DSQ/qty".
(:test)
function displayValuePlaceDsqShownAlone(logger as Test.Logger) as Boolean {
    var stats = ({ "place_abs" => "DSQ", "qty_abs" => "84" }) as Dictionary;
    return StatsFormatter.displayValue(stats, "place_abs").equals("DSQ");
}

//! No place yet renders blank even when the field size is present.
(:test)
function displayValueBlankWhenNoPlace(logger as Test.Logger) as Boolean {
    var stats = ({ "qty_abs" => "84" }) as Dictionary;
    return StatsFormatter.displayValue(stats, "place_abs").equals("");
}

//! A non-place metric renders the raw key value.
(:test)
function displayValueNonPlaceIsRawValue(logger as Test.Logger) as Boolean {
    var stats = ({ "gap_prev_abs" => "+0:12" }) as Dictionary;
    return StatsFormatter.displayValue(stats, "gap_prev_abs").equals("+0:12");
}

//! The dropdown index maps to the matching metric; the default (0) is place_abs
//! and an out-of-range index falls back to it too.
(:test)
function metricForIndexMapsAndFallsBack(logger as Test.Logger) as Boolean {
    return (
        StatsFormatter.metricForIndex(0).equals("place_abs") &&
        StatsFormatter.metricForIndex(5).equals("gap_prev_abs_delta") &&
        StatsFormatter.metricForIndex(14).equals("laps") &&
        StatsFormatter.metricForIndex(-1).equals("place_abs") &&
        StatsFormatter.metricForIndex(99).equals("place_abs")
    );
}

//! qty stays a known key (the server still sends it and place folds it in) even
//! though it is no longer a pickable metric; an unknown key is not.
(:test)
function isKnownKeyRecognisesKeys(logger as Test.Logger) as Boolean {
    return (
        StatsFormatter.isKnownKey("gap_leader_abs") &&
        StatsFormatter.isKnownKey("qty_abs") &&
        !StatsFormatter.isKnownKey("wattage")
    );
}

//! Known metrics load their (English, in the test simulator) label; an unknown
//! metric falls back to its raw id.
(:test)
function labelForKnownAndUnknown(logger as Test.Logger) as Boolean {
    return (
        StatsFormatter.labelFor("place_abs").equals("Place abs") &&
        StatsFormatter.labelFor("gap_prev_abs_delta").equals("Dynam bh abs") &&
        StatsFormatter.labelFor("future_metric").equals("future_metric")
    );
}

//! Every pickable metric maps to a resource id (no raw-id fallback), so no
//! metric is left unlabeled as the list grows.
(:test)
function everyMetricHasALabelResource(logger as Test.Logger) as Boolean {
    var metrics = StatsFormatter.METRICS;
    for (var i = 0; i < metrics.size(); i++) {
        if (StatsFormatter.labelResourceId(metrics[i]) == null) {
            logger.error("no label resource for " + metrics[i]);
            return false;
        }
    }
    return true;
}

//! A configured row count is clamped into 1..MAX_ROWS, so a bad setting can never
//! make the field draw nothing or more rows than there are metric settings.
(:test)
function clampRowCountKeepsRowsInRange(logger as Test.Logger) as Boolean {
    return (
        StatsFormatter.clampRowCount(1) == 1 &&
        StatsFormatter.clampRowCount(4) == 4 &&
        StatsFormatter.clampRowCount(0) == 1 &&
        StatsFormatter.clampRowCount(-3) == 1 &&
        StatsFormatter.clampRowCount(99) == StatsFormatter.MAX_ROWS
    );
}

//! A tall slot draws every configured row; a short one drops rows rather than
//! squeezing them below the readable minimum, but always draws at least one.
(:test)
function visibleRowsFitsRowsToSlotHeight(logger as Test.Logger) as Boolean {
    return (
        // 322px (Edge 540 full screen) fits all 4 configured rows
        StatsFormatter.visibleRows(4, 322, 22) == 4 &&
        // 160px (half screen) fits 4 rows of >=22px too
        StatsFormatter.visibleRows(4, 160, 22) == 4 &&
        // 79px (quarter screen) only fits 3
        StatsFormatter.visibleRows(4, 79, 22) == 3 &&
        // never more rows than configured
        StatsFormatter.visibleRows(1, 322, 22) == 1 &&
        // a slot thinner than one row still draws one
        StatsFormatter.visibleRows(4, 10, 22) == 1
    );
}

//! Every metric's (English) label is non-empty and at most 12 characters, so no
//! field header is truncated on device. Guards the length budget as metrics grow.
(:test)
function allMetricLabelsWithinTwelveChars(logger as Test.Logger) as Boolean {
    var metrics = StatsFormatter.METRICS;
    for (var i = 0; i < metrics.size(); i++) {
        var label = StatsFormatter.labelFor(metrics[i]);
        if (label.length() == 0 || label.length() > 12) {
            logger.error(metrics[i] + " -> '" + label + "' len=" + label.length());
            return false;
        }
    }
    return true;
}
