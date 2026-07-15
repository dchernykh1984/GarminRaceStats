import Toybox.Lang;
import Toybox.Test;

//! Unit tests for the round-screen geometry. These run under the Connect IQ
//! "Run No Evil" harness and need no emulator.
//!
//! The expected band shapes below are not invented: they are Garmin's own native
//! round layouts, read out of the SDK's Devices/<device>/simulator.json. That
//! file is the oracle - if our band rule ever drifts away from how Garmin lays a
//! circle out, these tests say so.

//! Garmin's native round layouts, for every field count they define. Checked
//! against fenix7 (which stops at 6) and fr965 (which goes to 8):
//!
//!   4 Fields B  band / 2col / band          6 Fields  band / 2col / 2col / band
//!   5 Fields    band / band / 2col / band   8 Fields  band / 2col / 2col / 2col / band
(:test)
function bandColumnsMatchesTheNativeRoundLayouts(logger as Test.Logger) as Boolean {
    var expected = {
        1 => [1],
        2 => [1, 1],
        3 => [1, 1, 1],
        4 => [1, 2, 1],
        5 => [1, 1, 2, 1],
        6 => [1, 2, 2, 1],
        8 => [1, 2, 2, 2, 1],
    };

    var counts = expected.keys();
    for (var i = 0; i < counts.size(); i++) {
        var count = counts[i] as Number;
        var want = expected.get(count) as Array<Number>;
        var got = RoundLayout.bandColumns(count);

        if (got.size() != want.size()) {
            logger.error(count + " metrics -> " + got.toString() + ", want " + want.toString());
            return false;
        }
        for (var band = 0; band < want.size(); band++) {
            if (got[band] != want[band]) {
                logger.error(count + " metrics -> " + got.toString() + ", want " + want.toString());
                return false;
            }
        }
    }
    return true;
}

//! Garmin's law, verified against all 114 round devices in the SDK: no native
//! round layout ever puts two columns in the first or last band, because that is
//! where the circle is narrowest. Ours must not either - at any metric count,
//! including the 9 and 10 that Garmin has no round layout for.
(:test)
function bandColumnsNeverPutsColumnsAgainstTheBezel(logger as Test.Logger) as Boolean {
    for (var count = 3; count <= StatsFormatter.MAX_ROWS; count++) {
        var bands = RoundLayout.bandColumns(count);
        if (bands[0] != 1 || bands[bands.size() - 1] != 1) {
            logger.error(count + " metrics -> " + bands.toString());
            return false;
        }
    }
    return true;
}

//! Every metric gets a cell: the bands account for exactly the metrics drawn,
//! never one more (a blank cell) or one fewer (a dropped metric).
(:test)
function bandColumnsAccountForEveryMetric(logger as Test.Logger) as Boolean {
    for (var count = 1; count <= StatsFormatter.MAX_ROWS; count++) {
        var bands = RoundLayout.bandColumns(count);
        var total = 0;
        for (var i = 0; i < bands.size(); i++) {
            total += bands[i];
        }
        if (total != count) {
            logger.error(count + " metrics -> " + bands.toString() + " holds " + total);
            return false;
        }
    }
    return true;
}

//! The row limit on a round screen is geometric: bands are dropped when they
//! would fall below the readable minimum, and one metric always survives.
//! Heights below are real round screens (fenix7 is 260, fr55 is 208).
(:test)
function visibleMetricsFitsBandsToTheSlot(logger as Test.Logger) as Boolean {
    return (
        // fenix7 full screen: 10 metrics need 6 bands of >= 34px = 204px, and 260
        // fits that. So does the smallest round screen Garmin ships (fr55, 208px).
        RoundLayout.visibleMetrics(10, 260, 34) == 10 &&
        RoundLayout.visibleMetrics(10, 208, 34) == 10 &&
        // half of a fenix7 only holds 3 bands (102px), so 4 metrics: [1, 2, 1]
        RoundLayout.visibleMetrics(10, 130, 34) == 4 &&
        // 100px is one pixel short of a third band, so it drops to two
        RoundLayout.visibleMetrics(10, 100, 34) == 2 &&
        // a configured count below the limit is never padded out
        RoundLayout.visibleMetrics(3, 260, 34) == 3 &&
        // a slot too thin for even one band still draws one metric
        RoundLayout.visibleMetrics(10, 10, 34) == 1
    );
}

//! The round row limit is caption-aware: a band must fit a caption above a
//! value, so fewer rows survive than if only the value had to fit. The minBand
//! values are label+value heights of the order measured on real devices
//! (fenix7 ~48px, fr55 ~42px, approachs7047mm ~72px). This is what makes a
//! fenix7 settle at the 8 rows that look right instead of cramming 10.
(:test)
function visibleMetricsCapsRowsToWhereCaptionsFit(logger as Test.Logger) as Boolean {
    return (
        // fenix7 (260px): 5 bands of 48px = 240 fit, 6 bands = 288 do not, so the
        // configured 10 drop to the 8 that fill five bands
        RoundLayout.visibleMetrics(10, 260, 48) == 8 &&
        // fr55 (208px): the small screen only holds four bands, so six metrics
        RoundLayout.visibleMetrics(10, 208, 42) == 6 &&
        // approachs7047mm (454px): the big screen still fits all ten
        RoundLayout.visibleMetrics(10, 454, 72) == 10
    );
}

//! Half the chord: the full radius on the centre line, nothing at the edge, and
//! the 3-4-5 triangle in between. Past the edge it is zero rather than an error.
(:test)
function halfChordFollowsTheCircle(logger as Test.Logger) as Boolean {
    return (
        RoundLayout.halfChord(130, 0) == 130 &&
        RoundLayout.halfChord(130, 130) == 0 &&
        RoundLayout.halfChord(130, 200) == 0 &&
        // 5-12-13 scaled by 10: at dy=50 the half chord is 120
        RoundLayout.halfChord(130, 50) == 120
    );
}

//! The invariant the whole fix rests on: a text block placed inside the span is
//! on screen along its *entire* height, not just at its middle. Checked at every
//! round screen size Garmin ships (208 to 454) for every block a band layout can
//! produce - both corners of the block must lie inside the circle.
(:test)
function spanForNeverLeavesTheCircle(logger as Test.Logger) as Boolean {
    var diameters = [208, 218, 240, 260, 280, 360, 390, 416, 454] as Array<Number>;

    for (var d = 0; d < diameters.size(); d++) {
        var radius = diameters[d] / 2;

        for (var count = 1; count <= StatsFormatter.MAX_ROWS; count++) {
            var bands = RoundLayout.bandColumns(count);
            var bandHeight = diameters[d] / bands.size();

            for (var band = 0; band < bands.size(); band++) {
                // The worst block a band can hold is the band itself.
                var top = band * bandHeight;
                var bottom = top + bandHeight;
                var span = RoundLayout.spanFor(radius, top, bottom);

                for (var corner = 0; corner < 4; corner++) {
                    var x = corner % 2 == 0 ? span[0] : span[1];
                    var y = corner < 2 ? top : bottom;
                    var dx = x - radius;
                    var dy = y - radius;
                    if (dx * dx + dy * dy > radius * radius) {
                        logger.error(
                            diameters[d] +
                                "px, " +
                                count +
                                " metrics, band " +
                                band +
                                ": (" +
                                x +
                                "," +
                                y +
                                ") is outside r=" +
                                radius
                        );
                        return false;
                    }
                }
            }
        }
    }
    return true;
}

//! The span is centred on the screen and widest across the middle: a band that
//! straddles the centre line gets more room than one against the bezel. This is
//! what pulls the top and bottom rows inward instead of letting them run into
//! the crescent.
(:test)
function spanForIsWidestAcrossTheMiddle(logger as Test.Logger) as Boolean {
    var middle = RoundLayout.spanFor(130, 120, 140);
    var edge = RoundLayout.spanFor(130, 0, 20);

    var middleWidth = middle[1] - middle[0];
    var edgeWidth = edge[1] - edge[0];

    return (
        middleWidth > edgeWidth &&
        // symmetric about the centre line
        middle[0] + middle[1] == 260 &&
        edge[0] + edge[1] == 260 &&
        // the band against the bezel really is narrow: the old grid gave it the
        // full 260px, which is how "Place abs" came out as "e abs"
        edgeWidth < 130
    );
}

//! A block is pushed off the bezel in the top and bottom bands (down, then up)
//! and centred everywhere else, so the caption never sits in the sliced crescent.
//! An un-cut edge (a partial slot) is centred rather than pushed.
(:test)
function bandBlockTopPushesEdgesAwayFromTheBezel(logger as Test.Logger) as Boolean {
    return (
        // top band, top cut: dropped to the bottom of its band (0 + 100 - 40 - 3)
        RoundLayout.bandBlockTop(0, 3, 100, 40, 3, true, true) == 57 &&
        // bottom band, bottom cut: raised to the top of its band (200 + 3)
        RoundLayout.bandBlockTop(2, 3, 100, 40, 3, true, true) == 203 &&
        // a middle band is centred: 100 + (100 - 40) / 2
        RoundLayout.bandBlockTop(1, 3, 100, 40, 3, true, true) == 130 &&
        // an edge that is not actually cut (a partial slot) is centred, not pushed
        RoundLayout.bandBlockTop(0, 3, 100, 40, 3, false, true) == 30 &&
        RoundLayout.bandBlockTop(2, 3, 100, 40, 3, true, false) == 230
    );
}

//! Why the row count is pulled down until the columns sit central: the caption
//! rides the top of its block, and a two-column band nearer the centre line gets
//! a wider chord for it. On fr55 (208px, R=104, 52px bands) the upper columned
//! band of a 6-metric layout is narrower than the single central band a 5-metric
//! layout uses, so dropping the sixth metric is what lets the captions fit.
(:test)
function reducingRowsWidensTheCaptionChord(logger as Test.Logger) as Boolean {
    var radius = 104;
    var labelHeight = 18;
    var block = 44;

    // 6 metrics -> [1, 2, 2, 1]: the upper two-column band (index 1 of 4) sits
    // away from the centre line.
    var upperTop = RoundLayout.bandBlockTop(1, 4, 52, block, 3, true, true);
    var upper = RoundLayout.spanFor(radius, upperTop, upperTop + labelHeight);

    // 5 metrics -> [1, 1, 2, 1]: the one two-column band (index 2 of 4) straddles
    // the centre line, so its caption strip spans a wider chord.
    var centralTop = RoundLayout.bandBlockTop(2, 4, 52, block, 3, true, true);
    var central = RoundLayout.spanFor(radius, centralTop, centralTop + labelHeight);

    return central[1] - central[0] > upper[1] - upper[0];
}
