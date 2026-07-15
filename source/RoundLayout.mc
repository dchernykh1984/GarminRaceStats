import Toybox.Lang;
import Toybox.Math;

//! Pure geometry for laying metrics out on a round screen.
//!
//! A round watch cuts the corners off the rectangular slot the system hands a
//! data field, so text that "fits the cell" can still be sliced off by the
//! bezel. Everything here answers one question: at a given height, how much of
//! the slot is actually on screen?
//!
//! The band rule below is Garmin's own, read off the native layouts the SDK
//! ships in Devices/<device>/simulator.json: across all 114 round devices there
//! is not one native layout that puts two columns in the first or last band.
//! The middle of a circle is wide, the top and bottom are not - so columns only
//! ever appear in the middle. bandColumns() reproduces their 1..8 field layouts
//! exactly and extends the same rule to 9 and 10.
//!
//! Rectangular screens (Edge) do not come through here at all: there the native
//! layouts really are a uniform grid, which is what the view already draws.
module RoundLayout {
    //! Fraction of a cell that text may occupy when the slot is *not* the whole
    //! screen. The obscurity flags say which edges the bezel cuts, but not where
    //! the slot sits, so the circle cannot be reconstructed and the chord cannot
    //! be computed: in native layouts a slot flagged "left and right" may be
    //! full width or inset by 80px. This keeps text well inside every native
    //! slot instead of guessing (Garmin's own budget for such slots is a median
    //! 0.64-0.88 of the slot width).
    const PARTIAL_WIDTH_PERCENT = 70;

    //! Columns for each band, top to bottom, for `metricCount` metrics on a
    //! round screen. The first and last band are always a single full-width
    //! column; the rest pair up into two-column bands. An odd leftover becomes
    //! one more full-width band just below the top, which is what Garmin's own
    //! "5 Fields" does.
    //! @param metricCount How many metrics are drawn
    //! @return The column count of each band, top to bottom
    function bandColumns(metricCount as Number) as Array<Number> {
        if (metricCount <= 1) {
            return [1] as Array<Number>;
        }
        if (metricCount == 2) {
            return [1, 1] as Array<Number>;
        }

        var columns = [1] as Array<Number>;
        var interior = metricCount - 2;
        if (interior % 2 == 1) {
            columns.add(1);
            interior -= 1;
        }
        for (var i = 0; i < interior / 2; i++) {
            columns.add(2);
        }
        columns.add(1);
        return columns;
    }

    //! The most metrics, up to `configured`, whose bands all stay at least
    //! `minBandHeight` tall in a slot `heightPx` tall. This is the whole row
    //! limit on a round screen: it is derived from the geometry rather than
    //! copied from Garmin's per-device caps, because those are a product
    //! decision, not a readability one (venu3 and fr965 have the same 454x454
    //! screen yet Garmin allows 4 fields on one and 8 on the other).
    //! @param configured The row count from settings
    //! @param heightPx The slot height
    //! @param minBandHeight The smallest readable band height
    //! @return The number of metrics to draw, at least one
    function visibleMetrics(
        configured as Number,
        heightPx as Number,
        minBandHeight as Number
    ) as Number {
        if (minBandHeight <= 0) {
            return configured;
        }
        for (var n = configured; n > 1; n--) {
            if (bandColumns(n).size() * minBandHeight <= heightPx) {
                return n;
            }
        }
        return 1;
    }

    //! Half the width of the round screen at `dy` pixels from its centre line -
    //! that is, half the chord. Zero past the edge of the circle.
    //! @param radius The screen radius
    //! @param dy Distance from the horizontal centre line
    //! @return Half the on-screen width at that height
    function halfChord(radius as Number, dy as Number) as Number {
        if (dy >= radius) {
            return 0;
        }
        var squared = radius.toDouble() * radius - dy.toDouble() * dy;
        return Math.sqrt(squared).toNumber();
    }

    //! The horizontal span [left, right] of a full-screen round slot that is on
    //! screen for *every* height in [top, bottom] - so a text block drawn inside
    //! that span cannot be clipped by the bezel anywhere along its height. The
    //! narrowest chord is always at whichever end of the block is furthest from
    //! the centre line.
    //! @param radius The screen radius (slot centre is at radius, radius)
    //! @param top Top of the text block, in slot coordinates
    //! @param bottom Bottom of the text block, in slot coordinates
    //! @return [left, right] in slot coordinates
    function spanFor(radius as Number, top as Number, bottom as Number) as Array<Number> {
        var above = radius - top;
        if (above < 0) {
            above = -above;
        }
        var below = bottom - radius;
        if (below < 0) {
            below = -below;
        }

        var dy = above > below ? above : below;
        var half = halfChord(radius, dy);
        return [radius - half, radius + half] as Array<Number>;
    }
}
