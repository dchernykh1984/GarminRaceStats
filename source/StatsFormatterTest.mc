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
//!
//! The direction in a label names the *other* rider, not the reader: gap_prev is
//! the gap to the rider one place ahead, so it reads "ahd", and gap_next is the
//! rider one place behind, so it reads "bhd".
(:test)
function labelForKnownAndUnknown(logger as Test.Logger) as Boolean {
    return (
        StatsFormatter.labelFor("place_abs").equals("Place abs") &&
        StatsFormatter.labelFor("gap_prev_abs").equals("Gap ahd abs") &&
        StatsFormatter.labelFor("gap_next_abs").equals("Gap bhd abs") &&
        StatsFormatter.labelFor("gap_prev_abs_delta").equals("Dynam ah abs") &&
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
        StatsFormatter.MAX_ROWS == 10 &&
        StatsFormatter.clampRowCount(1) == 1 &&
        StatsFormatter.clampRowCount(4) == 4 &&
        StatsFormatter.clampRowCount(10) == 10 &&
        StatsFormatter.clampRowCount(0) == 1 &&
        StatsFormatter.clampRowCount(-3) == 1 &&
        StatsFormatter.clampRowCount(11) == StatsFormatter.MAX_ROWS &&
        StatsFormatter.clampRowCount(99) == StatsFormatter.MAX_ROWS
    );
}

//! A tall slot draws every configured row; a short one drops rows rather than
//! squeezing them below the readable minimum, but always draws at least one.
//! Heights below are the real Edge 540 slot sizes (screen is 246x322).
(:test)
function visibleRowsFitsRowsToSlotHeight(logger as Test.Logger) as Boolean {
    return (
        // full screen ("1 Field") fits all 10 configured rows
        StatsFormatter.visibleRows(10, 322, 22) == 10 &&
        // half screen ("2 Fields") only fits 7 of the 10
        StatsFormatter.visibleRows(10, 160, 22) == 7 &&
        // quarter screen ("4 Fields A") only fits 3
        StatsFormatter.visibleRows(10, 79, 22) == 3 &&
        // a smaller configured count is never padded out
        StatsFormatter.visibleRows(4, 322, 22) == 4 &&
        StatsFormatter.visibleRows(1, 322, 22) == 1 &&
        // a slot thinner than one row still draws one
        StatsFormatter.visibleRows(10, 10, 22) == 1
    );
}

//! A grid only appears when it earns its place: enough metrics, and a slot wide
//! and tall enough. Sizes below are real Edge 540 slots (screen is 246x322).
(:test)
function columnCountPicksAGridOnlyWhenItFits(logger as Test.Logger) as Boolean {
    return (
        // full screen, 8 metrics -> grid
        StatsFormatter.columnCount(8, 246, 322) == 2 &&
        // half screen ("2 Fields"), 4 metrics -> still a grid
        StatsFormatter.columnCount(4, 246, 160) == 2 &&
        // too few metrics -> one column reads better
        StatsFormatter.columnCount(3, 246, 322) == 1 &&
        // narrow cell from the "8 Fields" layout (122px wide) -> one column
        StatsFormatter.columnCount(8, 122, 62) == 1 &&
        // a quarter-screen strip (79px) still fits two rows of ~39px cells
        StatsFormatter.columnCount(8, 246, 79) == 2 &&
        // but a cell shorter than two stacked cells (2x34) stays one column
        StatsFormatter.columnCount(8, 246, 60) == 1
    );
}

//! Cells are dropped, never squeezed below the readable minimum, and the grid
//! rows follow from the cells and columns.
(:test)
function visibleCellsAndGridRowsFitTheSlot(logger as Test.Logger) as Boolean {
    return (
        // 322px / 34px = 9 rows, x2 columns = 18 cells: all 10 fit
        StatsFormatter.visibleCells(10, 2, 322, 34) == 10 &&
        // 160px / 34px = 4 rows, x2 = 8 cells: two of the ten are dropped
        StatsFormatter.visibleCells(10, 2, 160, 34) == 8 &&
        // a slot shorter than one cell still draws one row of cells
        StatsFormatter.visibleCells(10, 2, 10, 34) == 2 &&
        // rounding up: 5 cells in 2 columns need 3 rows
        StatsFormatter.gridRows(5, 2) == 3 &&
        StatsFormatter.gridRows(10, 2) == 5 &&
        StatsFormatter.gridRows(4, 2) == 2 &&
        StatsFormatter.gridRows(3, 1) == 3
    );
}

//! Reading a property this build declares but an older settings store never had
//! must yield null, not an exception: a data field may never crash on settings.
(:test)
function propertyNeverThrowsOnUnknownKey(logger as Test.Logger) as Boolean {
    return (
        StatsStore.property("noSuchPropertyExistsHere") == null &&
        StatsStore.property(StatsStore.PROP_ROW_COUNT) != null
    );
}

//! Font choice takes the biggest candidate that fits both dimensions, and falls
//! back to the smallest rather than dropping the text when nothing fits.
(:test)
function largestFontIndexPicksBiggestThatFits(logger as Test.Logger) as Boolean {
    var widths = [10, 20, 30, 40, 50] as Array<Number>;
    var heights = [10, 15, 20, 25, 30] as Array<Number>;
    return (
        // plenty of room: the biggest font
        StatsFormatter.largestFontIndex(widths, heights, 100, 100) == 4 &&
        // width-bound: 30 fits in 35, 40 does not
        StatsFormatter.largestFontIndex(widths, heights, 35, 100) == 2 &&
        // height-bound: 15 fits in 17, 20 does not
        StatsFormatter.largestFontIndex(widths, heights, 100, 17) == 1 &&
        // exact fit still counts
        StatsFormatter.largestFontIndex(widths, heights, 40, 25) == 3 &&
        // nothing fits: never drop the row, use the smallest
        StatsFormatter.largestFontIndex(widths, heights, 1, 1) == 0
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
