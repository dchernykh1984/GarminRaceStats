import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

//! The background entry point. Connect IQ only lets a data field issue web
//! requests from this temporal process, and never more often than every five
//! minutes, so this does exactly one GET per firing and hands the parsed stats
//! back to the main app through Background.exit -> onBackgroundData.
(:background)
class BackgroundService extends System.ServiceDelegate {

    //! Constructor
    public function initialize() {
        ServiceDelegate.initialize();
    }

    //! Fired by the registered temporal event (~5 min). Issues the single public
    //! GET, or exits immediately without new data when there is no phone
    //! connection or the settings are incomplete.
    public function onTemporalEvent() as Void {
        if (!System.getDeviceSettings().phoneConnected) {
            Background.exit(null);
            return;
        }

        var url = StatsStore.buildRequestUrl();
        if (url == null) {
            Background.exit(null);
            return;
        }

        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(url, null, options, method(:onReceive));
    }

    //! makeWebRequest callback. On a 200 with a `stats` object, hand it back to
    //! the app; a 404 (no data yet) or any failure exits without new data so the
    //! field keeps its last value.
    //! @param responseCode HTTP status, or a negative Connect IQ error code
    //! @param data The parsed JSON body, or null on failure
    public function onReceive(responseCode as Number, data as Dictionary or String or Null) as Void {
        if (responseCode == 200 && data instanceof Dictionary) {
            var stats = data.get("stats");
            if (stats instanceof Dictionary) {
                Background.exit(stats as Application.PropertyValueType);
                return;
            }
        }
        Background.exit(null);
    }
}
