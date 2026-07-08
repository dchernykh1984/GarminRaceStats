import Toybox.Lang;
import Toybox.Test;

//! Unit tests for the pure StatsFormatter helpers. These run under the Connect
//! IQ "Run No Evil" harness: each (:test) function takes a Logger, returns a
//! Boolean, and is stripped from non-test (release) builds automatically.

//! A present string key returns its stored value verbatim.
(:test)
function valueForReturnsStoredString(logger as Test.Logger) as Boolean {
    var stats = { "place_abs" => "17" } as Dictionary;
    return StatsFormatter.valueFor(stats, "place_abs").equals("17");
}

//! An absent key renders blank rather than throwing.
(:test)
function valueForBlankWhenKeyMissing(logger as Test.Logger) as Boolean {
    var stats = { "place_abs" => "17" } as Dictionary;
    return StatsFormatter.valueFor(stats, "laps").equals("");
}

//! No snapshot cached yet renders blank.
(:test)
function valueForBlankWhenStatsNull(logger as Test.Logger) as Boolean {
    return StatsFormatter.valueFor(null, "place_abs").equals("");
}

//! A non-string value (defensive: the contract is all strings) renders blank.
(:test)
function valueForBlankWhenValueNotString(logger as Test.Logger) as Boolean {
    var stats = { "place_abs" => 17 } as Dictionary;
    return StatsFormatter.valueFor(stats, "place_abs").equals("");
}

//! Known v1 keys are recognised; anything else is treated as unknown.
(:test)
function isKnownKeyRecognisesV1Keys(logger as Test.Logger) as Boolean {
    return StatsFormatter.isKnownKey("gap_prev_group") && !StatsFormatter.isKnownKey("wattage");
}

//! A known key gets its label; a future/unknown key falls back to the raw key.
(:test)
function labelForKnownAndUnknownKeys(logger as Test.Logger) as Boolean {
    return StatsFormatter.labelFor("place_abs").equals("Place")
        && StatsFormatter.labelFor("future_key").equals("future_key");
}

//! The settings dropdown index maps to the matching key; the default index
//! (4) resolves to place_abs and an out-of-range index falls back to it too.
(:test)
function keyForIndexMapsAndFallsBack(logger as Test.Logger) as Boolean {
    return StatsFormatter.keyForIndex(4).equals("place_abs")
        && StatsFormatter.keyForIndex(8).equals("laps")
        && StatsFormatter.keyForIndex(-1).equals("place_abs")
        && StatsFormatter.keyForIndex(99).equals("place_abs");
}
