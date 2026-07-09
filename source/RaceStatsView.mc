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

    //! The widest value we ever draw: a gap over an hour ("+1:23:45") and a place
    //! in a huge field ("100/1000") are both eight characters.
    private const SAMPLE_VALUE = "+0:00:00";

    //! Minimum space kept between a row's label and its value.
    private const GAP = 6;

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
    //!
    //! Both columns are measured, because label and value share one row: with few
    //! rows the value font grows, and a long label like "Dynam ah abs" next to a
    //! long value like "+1:23:45" would otherwise collide. The value is sized
    //! first, keeping room for the label at its smallest, then the label takes
    //! whatever is left and never grows past the value.
    //! @param dc Device context for the slot this field was placed in
    private function selectFonts(dc as Dc) as Void {
        var rows = StatsFormatter.visibleRows(_rows, dc.getHeight(), StatsFormatter.MIN_ROW_HEIGHT);
        var maxHeight = dc.getHeight() / rows - 2;
        var usable = dc.getWidth() - 2 * PAD;

        var valueWidths = [] as Array<Number>;
        var valueHeights = [] as Array<Number>;
        var labelWidths = [] as Array<Number>;
        var labelHeights = [] as Array<Number>;

        for (var i = 0; i < FONTS.size(); i++) {
            var value = dc.getTextDimensions(SAMPLE_VALUE, FONTS[i]);
            valueWidths.add(value[0]);
            valueHeights.add(value[1]);

            // The widest configured label decides what the label column needs.
            var widest = 0;
            var tallest = 0;
            for (var row = 0; row < _labels.size(); row++) {
                var label = dc.getTextDimensions(_labels[row], FONTS[i]);
                if (label[0] > widest) {
                    widest = label[0];
                }
                if (label[1] > tallest) {
                    tallest = label[1];
                }
            }
            labelWidths.add(widest);
            labelHeights.add(tallest);
        }

        var valueBudget = usable - labelWidths[0] - GAP;
        var valueIndex = StatsFormatter.largestFontIndex(
            valueWidths,
            valueHeights,
            valueBudget,
            maxHeight
        );

        var labelBudget = usable - valueWidths[valueIndex] - GAP;
        var labelIndex = StatsFormatter.largestFontIndex(
            labelWidths,
            labelHeights,
            labelBudget,
            maxHeight
        );
        if (labelIndex > valueIndex) {
            labelIndex = valueIndex;
        }

        _valueFont = FONTS[valueIndex];
        _labelFont = FONTS[labelIndex];
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
}
