import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! The data field itself. A full DataField (rather than a SimpleDataField) so it
//! can draw several metrics inside the one slot the rider gives it: the rider
//! picks the native screen layout, so that slot may be the whole screen or a thin
//! strip, and we size the text and drop metrics to fit.
//!
//! Two shapes, chosen automatically from the slot (see StatsFormatter.columnCount):
//!
//!   one column                two columns (like the native data screen)
//!   +----------------+        +--------+--------+
//!   | Place abs 3/4  |        | Place abs|Place gr|
//!   | Gap ahd  +0:22 |        |   3/4    |  2/3   |
//!   +----------------+        +--------+--------+
//!
//! Drawing our own cells is what lets a single field replace the "clones" pattern:
//! one app, one Connect IQ field, several metrics at once.
(:typecheck(disableBackgroundCheck))
class RaceStatsView extends WatchUi.DataField {
    //! Breathing room at the edge of the slot and of every grid cell.
    private const PAD = 3;

    //! The widest value we ever draw: a gap over an hour ("+1:23:45") and a place
    //! in a huge field ("100/1000") are both eight characters.
    private const SAMPLE_VALUE = "+0:00:00";

    //! Minimum space kept between a row's label and its value (one-column shape).
    private const GAP = 6;

    //! Candidate fonts, smallest first.
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
    private var _columns as Number = 1;
    private var _valueFont as FontDefinition = Graphics.FONT_XTINY;
    private var _labelFont as FontDefinition = Graphics.FONT_XTINY;
    private var _labelHeight as Number = 0;

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

    //! Pick the shape and the fonts once the slot size is known.
    //! @param dc Device context for the slot this field was placed in
    public function onLayout(dc as Dc) as Void {
        selectFonts(dc);
    }

    //! Nothing to compute: every value comes from the site snapshot, never from
    //! the device sensors. The snapshot is read in onUpdate instead, because the
    //! system gives no guarantee that compute() runs before onUpdate() - caching
    //! it here would leave the first frame after a screen switch blank.
    //! @param info The updated Activity.Info object (unused)
    public function compute(info as Info) as Void {}

    //! Draw the configured metrics in whichever shape fits the slot.
    //! @param dc Device context for the slot this field was placed in
    public function onUpdate(dc as Dc) as Void {
        if (_fontsStale) {
            selectFonts(dc);
        }

        var background = getBackgroundColor();
        var foreground = Graphics.COLOR_WHITE;
        var separator = Graphics.COLOR_DK_GRAY;
        if (background == Graphics.COLOR_WHITE) {
            foreground = Graphics.COLOR_BLACK;
            separator = Graphics.COLOR_LT_GRAY;
        }

        dc.setColor(foreground, background);
        dc.clear();

        var stats = StatsStore.load();
        if (_columns == 2) {
            drawGrid(dc, stats, foreground, separator);
        } else {
            drawRows(dc, stats, foreground);
        }
    }

    //! One column: "label ....... value" per row, the value right-aligned.
    //! @param dc Device context
    //! @param stats The cached snapshot, or null
    //! @param foreground The text colour
    private function drawRows(dc as Dc, stats as Dictionary?, foreground as Number) as Void {
        dc.setColor(foreground, Graphics.COLOR_TRANSPARENT);

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

    //! Two columns: each cell centres its label over its value, like the native
    //! data screen, with thin separators between the cells.
    //! @param dc Device context
    //! @param stats The cached snapshot, or null
    //! @param foreground The text colour
    //! @param separator The separator colour
    private function drawGrid(
        dc as Dc,
        stats as Dictionary?,
        foreground as Number,
        separator as Number
    ) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var cells = StatsFormatter.visibleCells(
            _rows,
            _columns,
            height,
            StatsFormatter.MIN_CELL_HEIGHT
        );
        var rows = StatsFormatter.gridRows(cells, _columns);
        var cellWidth = width / _columns;
        var cellHeight = height / rows;

        dc.setColor(separator, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        for (var row = 1; row < rows; row++) {
            dc.drawLine(0, row * cellHeight, width, row * cellHeight);
        }
        for (var column = 1; column < _columns; column++) {
            dc.drawLine(column * cellWidth, 0, column * cellWidth, height);
        }

        dc.setColor(foreground, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < cells; i++) {
            var left = (i % _columns) * cellWidth;
            var top = (i / _columns) * cellHeight;
            var centre = left + cellWidth / 2;

            dc.drawText(
                centre,
                top + PAD + _labelHeight / 2,
                _labelFont,
                _labels[i],
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            dc.drawText(
                centre,
                top + _labelHeight + (cellHeight - _labelHeight) / 2,
                _valueFont,
                StatsFormatter.displayValue(stats, _metrics[i]),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }
    }

    //! Choose the shape, then the biggest fonts that fit it.
    //! @param dc Device context for the slot this field was placed in
    private function selectFonts(dc as Dc) as Void {
        _columns = StatsFormatter.columnCount(_rows, dc.getWidth(), dc.getHeight());
        if (_columns == 2) {
            selectGridFonts(dc);
        } else {
            selectRowFonts(dc);
        }
        _fontsStale = false;
    }

    //! One column: label and value share a row, so both columns are measured. The
    //! value is sized keeping room for the label at its smallest, then the label
    //! takes what is left and never grows past the value.
    //! @param dc Device context
    private function selectRowFonts(dc as Dc) as Void {
        var rows = StatsFormatter.visibleRows(_rows, dc.getHeight(), StatsFormatter.MIN_ROW_HEIGHT);
        var maxHeight = dc.getHeight() / rows - 2;
        var usable = dc.getWidth() - 2 * PAD;

        var label = measure(dc, _labels);
        var value = measure(dc, [SAMPLE_VALUE] as Array<String>);

        var valueBudget = usable - label[0][0] - GAP;
        var valueIndex = StatsFormatter.largestFontIndex(
            value[0],
            value[1],
            valueBudget,
            maxHeight
        );

        var labelBudget = usable - value[0][valueIndex] - GAP;
        var labelIndex = StatsFormatter.largestFontIndex(
            label[0],
            label[1],
            labelBudget,
            maxHeight
        );
        if (labelIndex > valueIndex) {
            labelIndex = valueIndex;
        }

        _valueFont = FONTS[valueIndex];
        _labelFont = FONTS[labelIndex];
        _labelHeight = label[1][labelIndex];
    }

    //! Two columns: the label gets the top of the cell and the value the rest, so
    //! the value may use the full cell width instead of half a row.
    //! @param dc Device context
    private function selectGridFonts(dc as Dc) as Void {
        var height = dc.getHeight();
        var cells = StatsFormatter.visibleCells(
            _rows,
            _columns,
            height,
            StatsFormatter.MIN_CELL_HEIGHT
        );
        var rows = StatsFormatter.gridRows(cells, _columns);
        var cellHeight = height / rows;
        var inner = dc.getWidth() / _columns - 2 * PAD;

        var label = measure(dc, _labels);
        var value = measure(dc, [SAMPLE_VALUE] as Array<String>);

        // The label is a caption: at most two fifths of the cell.
        var labelIndex = StatsFormatter.largestFontIndex(
            label[0],
            label[1],
            inner,
            (cellHeight * 2) / 5
        );
        _labelHeight = label[1][labelIndex];

        var valueIndex = StatsFormatter.largestFontIndex(
            value[0],
            value[1],
            inner,
            cellHeight - _labelHeight - PAD
        );

        _labelFont = FONTS[labelIndex];
        _valueFont = FONTS[valueIndex];
    }

    //! Widest and tallest of `texts` for each candidate font.
    //! @param dc Device context
    //! @param texts The strings that must fit
    //! @return [widths, heights], one entry per candidate font
    private function measure(dc as Dc, texts as Array<String>) as Array<Array<Number> > {
        var widths = [] as Array<Number>;
        var heights = [] as Array<Number>;
        for (var i = 0; i < FONTS.size(); i++) {
            var widest = 0;
            var tallest = 0;
            for (var t = 0; t < texts.size(); t++) {
                var size = dc.getTextDimensions(texts[t], FONTS[i]);
                if (size[0] > widest) {
                    widest = size[0];
                }
                if (size[1] > tallest) {
                    tallest = size[1];
                }
            }
            widths.add(widest);
            heights.add(tallest);
        }
        return [widths, heights] as Array<Array<Number> >;
    }
}
