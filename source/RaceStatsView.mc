import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! The data field itself. A full DataField (rather than a SimpleDataField) so it
//! can draw several metrics inside the one slot the rider gives it: the rider
//! picks the native screen layout, so that slot may be the whole screen or a thin
//! strip, and we size the text and drop metrics to fit.
//!
//! Three shapes, chosen automatically from the slot and the screen:
//!
//!   one column           two columns (rectangular)   bands (round)
//!   +--------------+     +---------+--------+        +-------------+
//!   | Place abs 3/4|     |Place abs|Place gr|        |  Place abs  |
//!   | Gap ahd +0:22|     |   3/4   |  2/3   |        | Gap ahd|Laps|
//!   +--------------+     +---------+--------+        |  Gap bhd    |
//!                                                    +-------------+
//!
//! The band shape exists because a round screen slices the corners off the slot:
//! text that fits its cell can still be cut off by the bezel. See RoundLayout -
//! the rule (columns only in the middle bands, content pushed away from the
//! bezel) is read off Garmin's own native layouts.
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

    //! True when the screen is round (or semi-round): the corners of the slot are
    //! then off screen, and the band shape is drawn instead of the grid.
    private var _round as Boolean = false;

    //! The band plan, one entry per drawn cell (round screens only). Built once
    //! per layout rather than per frame: the geometry only changes when the slot
    //! or the settings change.
    private var _cellCentreX as Array<Number> = [] as Array<Number>;
    private var _cellLabelY as Array<Number> = [] as Array<Number>;
    private var _cellValueY as Array<Number> = [] as Array<Number>;
    private var _cellValueFont as Array<FontDefinition> = [] as Array<FontDefinition>;
    private var _cellHasLabel as Array<Boolean> = [] as Array<Boolean>;
    private var _bandColumns as Array<Number> = [] as Array<Number>;
    private var _bandHeight as Number = 0;

    //! The round-planning context for one pass: set at the top of planBands and
    //! read by its helpers instead of being threaded through them, because older
    //! devices cap a method at nine arguments.
    private var _topCut as Boolean = false;
    private var _bottomCut as Boolean = false;
    private var _valueWidths as Array<Number> = [] as Array<Number>;
    private var _valueHeights as Array<Number> = [] as Array<Number>;

    //! Set whenever the rows change, so the layout is re-picked on the next draw.
    //! Font choice needs a device context, and the obscurity flags are only valid
    //! during onUpdate, so all of it happens there rather than in onLayout.
    private var _layoutStale as Boolean = true;

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
        _layoutStale = true;
    }

    //! The slot changed, so the layout must be picked again. The work itself waits
    //! for onUpdate: getObscurityFlags() is only valid during that call.
    //! @param dc Device context for the slot this field was placed in (unused)
    public function onLayout(dc as Dc) as Void {
        _layoutStale = true;
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
        if (_layoutStale) {
            selectLayout(dc);
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
        if (_round) {
            drawBands(dc, stats, foreground, separator);
        } else if (_columns == 2) {
            drawGrid(dc, stats, foreground, separator);
        } else {
            drawRows(dc, stats, foreground);
        }
    }

    //! Pick the shape, then the fonts and cell geometry that fit it.
    //! @param dc Device context for the slot this field was placed in
    private function selectLayout(dc as Dc) as Void {
        var shape = System.getDeviceSettings().screenShape;
        _round = shape == System.SCREEN_SHAPE_ROUND || shape == System.SCREEN_SHAPE_SEMI_ROUND;

        if (_round) {
            planBands(dc);
        } else {
            _columns = StatsFormatter.columnCount(_rows, dc.getWidth(), dc.getHeight());
            if (_columns == 2) {
                selectGridFonts(dc);
            } else {
                selectRowFonts(dc);
            }
        }
        _layoutStale = false;
    }

    //! Work out, for a round screen, where every label and value goes and how big
    //! it may be. Each cell is sized against the chord of the circle at the height
    //! its text actually occupies - not against the cell rectangle, whose corners
    //! may be off screen.
    //!
    //! Captions are decided per band, not per cell: a band shows captions only if
    //! every cell in it has room for one, so a captioned value never sits beside a
    //! bare one. And the row count is pulled down until no two-column band has to
    //! go caption-less - on a small screen a caption only fits the chord in the
    //! central bands, so we drop rows rather than draw a columned band of bare
    //! numbers. Single top/bottom bands may still be bare, which is what the native
    //! round layouts do at their edges.
    //! @param dc Device context for the slot this field was placed in
    private function planBands(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var settings = System.getDeviceSettings();

        // Only when the field owns the whole screen do we know where the circle
        // is: the slot and the screen then share an origin. In a smaller slot the
        // obscurity flags say which edges the bezel cuts but not where the slot
        // sits (a slot flagged left and right may be full width or inset by 80px),
        // so the chord cannot be reconstructed and RoundLayout's conservative
        // budget is used instead.
        var fullScreen = width == settings.screenWidth && height == settings.screenHeight;
        var radius = width / 2;

        var flags = getObscurityFlags();
        var topCut = (flags & DataField.OBSCURE_TOP) != 0;
        var bottomCut = (flags & DataField.OBSCURE_BOTTOM) != 0;

        // Every native round layout captions its fields in the smallest font, and
        // for good reason: the label sits in the narrowest part of the cell.
        _labelFont = FONTS[0];
        _labelHeight = dc.getFontHeight(_labelFont);

        var value = measure(dc, [SAMPLE_VALUE] as Array<String>);
        var valueWidths = value[0];
        var valueHeights = value[1];

        // Hand the pass-wide context to the helpers through fields, not arguments.
        _topCut = topCut;
        _bottomCut = bottomCut;
        _valueWidths = valueWidths;
        _valueHeights = valueHeights;

        // First cap: a band must have room for a caption above a readable value,
        // else the row is dropped rather than shown caption-less. Stricter than the
        // rectangular limit (which needs room for the value alone).
        var minBand = _labelHeight + valueHeights[0] + 2 * PAD;
        var heightCap = RoundLayout.visibleMetrics(_rows, height, minBand);

        // Second cap: pull the count down further while any two-column band would
        // have to drop its captions, so a columned band is never a row of bare
        // numbers. On a wide screen this changes nothing; on a small one it steps
        // down until the columns sit central enough for a caption to fit.
        var cells = captionedRoundMetrics(dc, heightCap, width, height, fullScreen, radius);
        _bandColumns = RoundLayout.bandColumns(cells);
        _bandHeight = height / _bandColumns.size();

        _cellCentreX = [] as Array<Number>;
        _cellLabelY = [] as Array<Number>;
        _cellValueY = [] as Array<Number>;
        _cellValueFont = [] as Array<FontDefinition>;
        _cellHasLabel = [] as Array<Boolean>;

        var cell = 0;
        for (var band = 0; band < _bandColumns.size(); band++) {
            var columns = _bandColumns[band];
            var bandCells = columns;
            if (cell + bandCells > cells) {
                bandCells = cells - cell;
            }

            // Pass 1: pick each cell's value font and whether its caption fits; the
            // band captions its cells only if all of them can.
            var fonts = [] as Array<Number>;
            var bandHasLabels = true;
            for (var c = 0; c < bandCells; c++) {
                var cellLeft = (c * width) / columns;
                var cellRight = ((c + 1) * width) / columns;
                var labelWidth = dc.getTextDimensions(_labels[cell + c], _labelFont)[0];
                var plan = planCell(
                    band,
                    _bandColumns.size(),
                    _bandHeight,
                    cellLeft,
                    cellRight,
                    labelWidth,
                    fullScreen,
                    radius
                );
                fonts.add(plan[0]);
                if (plan[1] == 0) {
                    bandHasLabels = false;
                }
            }

            // Pass 2: place every cell the same way for the band, captioned or not.
            for (var c = 0; c < bandCells; c++) {
                var cellLeft = (c * width) / columns;
                var cellRight = ((c + 1) * width) / columns;
                var chosen = fonts[c];

                var blockHeight = valueHeights[chosen];
                if (bandHasLabels) {
                    blockHeight += _labelHeight;
                }
                var top = RoundLayout.bandBlockTop(
                    band,
                    _bandColumns.size(),
                    _bandHeight,
                    blockHeight,
                    PAD,
                    topCut,
                    bottomCut
                );
                var span = spanFor(fullScreen, radius, top, top + blockHeight, cellLeft, cellRight);

                _cellCentreX.add((span[0] + span[1]) / 2);
                _cellValueFont.add(FONTS[chosen]);
                _cellHasLabel.add(bandHasLabels);
                if (bandHasLabels) {
                    _cellLabelY.add(top + _labelHeight / 2);
                    _cellValueY.add(top + _labelHeight + valueHeights[chosen] / 2);
                } else {
                    _cellLabelY.add(top);
                    _cellValueY.add(top + valueHeights[chosen] / 2);
                }
            }
            cell += bandCells;
        }
    }

    //! The largest metric count, up to heightCap, whose two-column bands can all
    //! show their captions. Single top and bottom bands may still go bare - the
    //! native round layouts leave them so - so only the columned bands, where a
    //! captioned cell beside a bare one looks broken, drive the reduction.
    //! @param dc Device context
    //! @param heightCap The count the band height already allows
    //! @param width The slot width
    //! @param height The slot height
    //! @param fullScreen Whether the slot is the whole screen
    //! @param radius The screen radius
    //! @return The number of metrics to draw, at least one
    private function captionedRoundMetrics(
        dc as Dc,
        heightCap as Number,
        width as Number,
        height as Number,
        fullScreen as Boolean,
        radius as Number
    ) as Number {
        for (var n = heightCap; n > 1; n--) {
            var bands = RoundLayout.bandColumns(n);
            var bandHeight = height / bands.size();
            var cell = 0;
            var ok = true;
            for (var band = 0; band < bands.size() && ok; band++) {
                var columns = bands[band];
                if (columns == 2) {
                    for (var c = 0; c < 2; c++) {
                        var cellLeft = (c * width) / columns;
                        var cellRight = ((c + 1) * width) / columns;
                        var labelWidth = dc.getTextDimensions(_labels[cell + c], _labelFont)[0];
                        var plan = planCell(
                            band,
                            bands.size(),
                            bandHeight,
                            cellLeft,
                            cellRight,
                            labelWidth,
                            fullScreen,
                            radius
                        );
                        if (plan[1] == 0) {
                            ok = false;
                        }
                    }
                }
                cell += columns;
            }
            if (ok) {
                return n;
            }
        }
        return 1;
    }

    //! Pick a cell's value font, and decide whether its caption fits. The biggest
    //! value font whose block fits the band and stays within the chord wins; the
    //! caption is then measured over its own strip (the top of the block), which
    //! can be wider than the whole block's narrowest point when the value reaches
    //! nearer the rim than the caption does.
    //! @param band The band index
    //! @param bandCount How many bands there are
    //! @param bandHeight The height of one band
    //! @param cellLeft Left edge of the cell
    //! @param cellRight Right edge of the cell
    //! @param labelWidth The measured caption width
    //! @param fullScreen Whether the slot is the whole screen
    //! @param radius The screen radius
    //! @return [fontIndex, captionFits], captionFits being 1 or 0
    private function planCell(
        band as Number,
        bandCount as Number,
        bandHeight as Number,
        cellLeft as Number,
        cellRight as Number,
        labelWidth as Number,
        fullScreen as Boolean,
        radius as Number
    ) as Array<Number> {
        for (var font = FONTS.size() - 1; font >= 0; font--) {
            var blockHeight = _labelHeight + _valueHeights[font];
            if (font > 0 && blockHeight > bandHeight - 2 * PAD) {
                continue;
            }
            var top = RoundLayout.bandBlockTop(
                band,
                bandCount,
                bandHeight,
                blockHeight,
                PAD,
                _topCut,
                _bottomCut
            );
            var valueRoom = usableWidth(
                fullScreen,
                radius,
                top,
                top + blockHeight,
                cellLeft,
                cellRight
            );
            if (font == 0 || _valueWidths[font] <= valueRoom) {
                var labelRoom = usableWidth(
                    fullScreen,
                    radius,
                    top,
                    top + _labelHeight,
                    cellLeft,
                    cellRight
                );
                return [font, labelWidth <= labelRoom ? 1 : 0] as Array<Number>;
            }
        }
        return [0, 0] as Array<Number>;
    }

    //! The part of a cell a text block spanning [top, bottom] can use.
    //! @param fullScreen Whether the slot is the whole screen
    //! @param radius The screen radius
    //! @param top Top of the text block
    //! @param bottom Bottom of the text block
    //! @param cellLeft Left edge of the cell
    //! @param cellRight Right edge of the cell
    //! @return [left, right] in slot coordinates
    private function spanFor(
        fullScreen as Boolean,
        radius as Number,
        top as Number,
        bottom as Number,
        cellLeft as Number,
        cellRight as Number
    ) as Array<Number> {
        var left = cellLeft;
        var right = cellRight;

        if (fullScreen) {
            var chord = RoundLayout.spanFor(radius, top, bottom);
            if (chord[0] > left) {
                left = chord[0];
            }
            if (chord[1] < right) {
                right = chord[1];
            }
        } else {
            var inset = ((cellRight - cellLeft) * (100 - RoundLayout.PARTIAL_WIDTH_PERCENT)) / 200;
            left += inset;
            right -= inset;
        }

        if (right < left) {
            right = left;
        }
        return [left, right] as Array<Number>;
    }

    //! Text width available to a block, once the chord and the padding are taken
    //! off. Never negative.
    //! @param fullScreen Whether the slot is the whole screen
    //! @param radius The screen radius
    //! @param top Top of the text block
    //! @param bottom Bottom of the text block
    //! @param cellLeft Left edge of the cell
    //! @param cellRight Right edge of the cell
    //! @return The width the text may occupy
    private function usableWidth(
        fullScreen as Boolean,
        radius as Number,
        top as Number,
        bottom as Number,
        cellLeft as Number,
        cellRight as Number
    ) as Number {
        // The chord clamp is inlined rather than calling spanFor: usableWidth sits
        // on the deepest call chain in the app (the round row-fit reduction), and a
        // data field has a shallow stack, so one fewer frame here avoids a stack
        // overflow. spanFor keeps the same logic for the shallower drawing pass.
        var left = cellLeft;
        var right = cellRight;
        if (fullScreen) {
            var chord = RoundLayout.spanFor(radius, top, bottom);
            if (chord[0] > left) {
                left = chord[0];
            }
            if (chord[1] < right) {
                right = chord[1];
            }
        } else {
            var inset = ((cellRight - cellLeft) * (100 - RoundLayout.PARTIAL_WIDTH_PERCENT)) / 200;
            left += inset;
            right -= inset;
        }
        var room = right - left - 2 * PAD;
        if (room < 0) {
            return 0;
        }
        return room;
    }

    //! Round screens: bands, each cell centred on the part of it that is on screen.
    //! @param dc Device context
    //! @param stats The cached snapshot, or null
    //! @param foreground The text colour
    //! @param separator The separator colour
    private function drawBands(
        dc as Dc,
        stats as Dictionary?,
        foreground as Number,
        separator as Number
    ) as Void {
        var width = dc.getWidth();

        dc.setColor(separator, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        for (var band = 0; band < _bandColumns.size(); band++) {
            var top = band * _bandHeight;
            if (band > 0) {
                dc.drawLine(0, top, width, top);
            }
            if (_bandColumns[band] == 2) {
                dc.drawLine(width / 2, top, width / 2, top + _bandHeight);
            }
        }

        dc.setColor(foreground, Graphics.COLOR_TRANSPARENT);
        for (var cell = 0; cell < _cellValueFont.size(); cell++) {
            if (_cellHasLabel[cell]) {
                dc.drawText(
                    _cellCentreX[cell],
                    _cellLabelY[cell],
                    _labelFont,
                    _labels[cell],
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
                );
            }
            dc.drawText(
                _cellCentreX[cell],
                _cellValueY[cell],
                _cellValueFont[cell],
                StatsFormatter.displayOr(stats, _metrics[cell]),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
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
                StatsFormatter.displayOr(stats, _metrics[i]),
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
                StatsFormatter.displayOr(stats, _metrics[i]),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }
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
