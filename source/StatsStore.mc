import Toybox.Application;
import Toybox.Lang;

//! Persistence and settings glue, shared by the foreground field and the
//! background service (Application.Storage is shared across both scopes, so the
//! background writes the snapshot and every field read picks it up). Marked
//! (:background) so the symbols resolve when compiled into the background scope.
(:background)
module StatsStore {
    //! Storage key under which the latest fetched `stats` dictionary is cached.
    const STORAGE_STATS = "stats";

    // Property ids declared in resources/settings/settings.xml.
    const PROP_BASE_URL = "baseUrl";
    const PROP_COMPETITION_ID = "competitionId";
    const PROP_BIB = "bib";
    const PROP_ROW_COUNT = "rowCount";

    //! Per-row metric properties are "metric1".."metric4".
    const PROP_METRIC_PREFIX = "metric";

    //! Default metric index (see StatsFormatter.METRICS); 0 == place_abs.
    const DEFAULT_METRIC_INDEX = 0;

    //! Rows drawn before the rider changes anything.
    const DEFAULT_ROW_COUNT = 1;

    //! Cache the freshly fetched per-bib stats dictionary.
    //! @param stats The `stats` object from the site response
    function save(stats as Dictionary) as Void {
        Application.Storage.setValue(STORAGE_STATS, stats as Application.Storage.ValueType);
    }

    //! The cached stats dictionary, or null when nothing has been fetched yet.
    //! @return The cached dictionary, or null
    function load() as Dictionary? {
        var stats = Application.Storage.getValue(STORAGE_STATS);
        if (stats instanceof Dictionary) {
            return stats as Dictionary;
        }
        return null;
    }

    //! How many metric rows the rider asked the field to draw. Not clamped here;
    //! StatsFormatter.clampRowCount owns that rule so it stays unit-testable.
    //! @return The configured row count, or the default when unset
    function rowCount() as Number {
        var rows = Application.Properties.getValue(PROP_ROW_COUNT);
        if (rows instanceof Number) {
            return rows;
        }
        return DEFAULT_ROW_COUNT;
    }

    //! The configured metric index (into StatsFormatter.METRICS) for one row. The
    //! phone settings expose each row as a dropdown of numeric indices; mapping an
    //! index to a metric stays in the foreground formatter so this background-safe
    //! module has no UI dependency.
    //! @param row The 1-based row number
    //! @return The selected index, or the default when unset
    function metricIndexForRow(row as Number) as Number {
        var index = Application.Properties.getValue(PROP_METRIC_PREFIX + row.toString());
        if (index instanceof Number) {
            return index;
        }
        return DEFAULT_METRIC_INDEX;
    }

    //! The full public GET url, or null when the competition id or bib have not
    //! been configured yet (in which case the background service skips the fetch).
    //! @return The request url, or null when settings are incomplete
    function buildRequestUrl() as String? {
        var baseUrl = Application.Properties.getValue(PROP_BASE_URL);
        var competitionId = Application.Properties.getValue(PROP_COMPETITION_ID);
        var bib = Application.Properties.getValue(PROP_BIB);

        if (!(baseUrl instanceof String) || baseUrl.length() == 0) {
            return null;
        }
        if (!(competitionId instanceof Number) || competitionId <= 0) {
            return null;
        }
        if (!(bib instanceof String) || bib.length() == 0) {
            return null;
        }
        return baseUrl + "/api/v1/live-stats/" + competitionId.toString() + "/" + bib;
    }
}
