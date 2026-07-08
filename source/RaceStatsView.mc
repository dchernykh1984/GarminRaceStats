import Toybox.Activity;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

//! The data field itself. A SimpleDataField shows one label plus one computed
//! value in the native activity screen. The value is the configured metric read
//! from the cached snapshot, or blank when there is no data yet. compute() must
//! never throw, so all the guarding lives in the pure StatsFormatter helpers.
(:typecheck(disableBackgroundCheck))
class RaceStatsView extends WatchUi.SimpleDataField {
    //! The metric key this field shows, resolved once from the settings index.
    private var _key as String;

    //! Constructor: resolve the configured metric and set the field header.
    public function initialize() {
        SimpleDataField.initialize();
        _key = StatsFormatter.keyForIndex(StatsStore.metricIndex());
        label = StatsFormatter.labelFor(_key);
    }

    //! Compute the value to show. Reads the cached snapshot written by the
    //! background service and picks the configured metric out of it.
    //! @param info The updated Activity.Info object (unused; data comes from the site)
    //! @return The metric string to display, or "" when unavailable
    public function compute(info as Info) as Numeric or Duration or String or Null {
        return StatsFormatter.valueFor(StatsStore.load(), _key);
    }
}
