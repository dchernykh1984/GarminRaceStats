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
    const PROP_METRIC_INDEX = "metricIndex";

    //! Default metric-key index (see StatsFormatter.KNOWN_KEYS); 4 == place_abs.
    const DEFAULT_METRIC_INDEX = 4;

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

    //! The configured metric-key index (into StatsFormatter.KNOWN_KEYS). The
    //! phone settings expose the metric as a dropdown of numeric indices;
    //! mapping the index to a key stays in the foreground formatter so this
    //! background-safe module has no UI dependency.
    //! @return The selected index, or the default when unset/out of range
    function metricIndex() as Number {
        var index = Application.Properties.getValue(PROP_METRIC_INDEX);
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
