import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! The data field itself. A full DataField (rather than a SimpleDataField) so it
//! can draw several metrics as rows inside the one slot the rider gives it: the
//! rider picks the native screen layout, so that slot may be the whole screen or
//! a thin strip, and we size the text and drop rows to fit.
//!
//! Drawing our own rows is what lets a single field replace the "clones" pattern:
//! one app, one Connect IQ field, several metrics at once.
(:typecheck(disableBackgroundCheck))
class RaceStatsView extends WatchUi.DataField {
    //! Horizontal breathing room at each edge of the slot.
    private const PAD = 3;

    //! A wide-ish value used to pick a font that will not clip real values.
    private const SAMPLE_VALUE = "+00:00";

    //! Candidate value fonts, smallest first.
    private const FONTS = [
        Graphics.FONT_XTINY,
        Graphics.FONT_TINY,
        Graphics.FONT_SMALL,
        Graphics.FONT_MEDIUM,
        Graphics.FONT_LARGE,
    ];

    private var _metrics as Array<String> = [] as Array<String>;
    private var _labels as Array<String> = [] as Array<String>;
    private var _rows as Number = 1;
    private var _valueFont as FontDefinition = Graphics.FONT_XTINY;
    private var _labelFont as FontDefinition = Graphics.FONT_XTINY;

    //! Set whenever the rows change, so the fonts are re-picked on the next draw
    //! (font choice needs a device context, which only onLayout/onUpdate have).
    private var _fontsStale as Boolean = true;

    //! Constructor: resolve the configured rows, with their localized labels.
    public function initialize() {
        DataField.initialize();
        loadConfiguration();
    }

    //! Re-read the settings after the rider edits them on the phone. Without
    //! this the field would keep drawing the rows it read when it was created.
    public function reloadSettings() as Void {
        loadConfiguration();
    }

    //! Read the row count and each row's metric, resolving localized labels.
    private function loadConfiguration() as Void {
        _rows = StatsFormatter.clampRowCount(StatsStore.rowCount());

        var metrics = [] as Array<String>;
        var labels = [] as Array<String>;
        for (var row = 1; row <= _rows; row++) {
            var metric = StatsFormatter.metricForIndex(StatsStore.metricIndexForRow(row));
            metrics.add(metric);
            labels.add(StatsFormatter.labelFor(metric));
        }
        _metrics = metrics;
        _labels = labels;
        _fontsStale = true;
    }

    //! Pick the biggest fonts that fit once the slot size is known.
    //! @param dc Device context for the slot this field was placed in
    public function onLayout(dc as Dc) as Void {
        selectFonts(dc);
    }

    //! Choose the value/label fonts for the current slot and row count.
    //! @param dc Device context for the slot this field was placed in
    private function selectFonts(dc as Dc) as Void {
        var rows = StatsFormatter.visibleRows(_rows, dc.getHeight(), StatsFormatter.MIN_ROW_HEIGHT);
        var rowHeight = dc.getHeight() / rows;
        _valueFont = largestFont(dc, dc.getWidth() / 2 - PAD, rowHeight - 2);
        _labelFont = smallerFont(_valueFont);
        _fontsStale = false;
    }

    //! Nothing to compute: every value comes from the site snapshot, never from
    //! the device sensors. The snapshot is read in onUpdate instead, because the
    //! system gives no guarantee that compute() runs before onUpdate() - caching
    //! it here would leave the first frame after a screen switch blank.
    //! @param info The updated Activity.Info object (unused)
    public function compute(info as Info) as Void {}

    //! Draw one "label ....... value" row per configured metric.
    //! @param dc Device context for the slot this field was placed in
    public function onUpdate(dc as Dc) as Void {
        if (_fontsStale) {
            selectFonts(dc);
        }

        var background = getBackgroundColor();
        var foreground = Graphics.COLOR_WHITE;
        if (background == Graphics.COLOR_WHITE) {
            foreground = Graphics.COLOR_BLACK;
        }

        dc.setColor(foreground, background);
        dc.clear();
        dc.setColor(foreground, Graphics.COLOR_TRANSPARENT);

        var stats = StatsStore.load();
        var rows = StatsFormatter.visibleRows(_rows, dc.getHeight(), StatsFormatter.MIN_ROW_HEIGHT);
        var rowHeight = dc.getHeight() / rows;
        var right = dc.getWidth() - PAD;

        for (var i = 0; i < rows; i++) {
            var y = i * rowHeight + rowHeight / 2;
            dc.drawText(
                PAD,
                y,
                _labelFont,
                _labels[i],
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
            );
            dc.drawText(
                right,
                y,
                _valueFont,
                StatsFormatter.displayValue(stats, _metrics[i]),
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }
    }

    //! The biggest candidate font whose sample value fits the given box.
    //! @param dc Device context
    //! @param maxWidth Width the value may occupy
    //! @param maxHeight Height the value may occupy
    //! @return The font to draw values with
    private function largestFont(
        dc as Dc,
        maxWidth as Number,
        maxHeight as Number
    ) as FontDefinition {
        for (var i = FONTS.size() - 1; i > 0; i--) {
            var size = dc.getTextDimensions(SAMPLE_VALUE, FONTS[i]);
            if (size[0] <= maxWidth && size[1] <= maxHeight) {
                return FONTS[i];
            }
        }
        return FONTS[0];
    }

    //! One step down from `font`, so the row label never outshouts its value.
    //! @param font The value font
    //! @return The label font
    private function smallerFont(font as FontDefinition) as FontDefinition {
        for (var i = 1; i < FONTS.size(); i++) {
            if (FONTS[i] == font) {
                return FONTS[i - 1];
            }
        }
        return FONTS[0];
    }
}
