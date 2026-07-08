import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

//! The application entry point. Marked (:background) because Connect IQ runs the
//! temporal fetch in a separate background process that shares this class; the
//! service delegate it returns does the actual web request.
(:background)
class GarminRaceStatsApp extends Application.AppBase {

    //! Constructor
    public function initialize() {
        AppBase.initialize();
    }

    //! Handle app startup: (re)register the repeating background fetch.
    //! @param state Startup arguments
    public function onStart(state as Dictionary?) as Void {
        scheduleBackgroundFetch();
    }

    //! Handle app shutdown
    //! @param state Shutdown arguments
    public function onStop(state as Dictionary?) as Void {
    }

    //! Persist the stats handed back by the background service so every field
    //! read on the main process picks up the fresh snapshot.
    //! @param data The value passed to Background.exit by the service delegate
    public function onBackgroundData(data as PersistableType) as Void {
        if (data instanceof Dictionary) {
            StatsStore.save(data as Dictionary);
        }
    }

    //! Re-render when the rider edits the settings on the paired phone.
    public function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }

    //! Return the initial view for the app
    //! @return Array [View]
    public function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new $.RaceStatsView()];
    }

    //! Return the background service delegate that runs the temporal fetch.
    //! @return Array [ServiceDelegate]
    public function getServiceDelegate() as [ServiceDelegate] {
        return [new $.BackgroundService()];
    }

    //! Register the repeating ~5-minute temporal event that drives the fetch.
    //! Five minutes is the Connect IQ minimum for a data-field background
    //! service; anything smaller is rejected.
    (:typecheck(disableBackgroundCheck))
    private function scheduleBackgroundFetch() as Void {
        try {
            Background.registerForTemporalEvent(new Time.Duration(5 * 60));
        } catch (e instanceof Background.InvalidBackgroundTimeException) {
            // Registered too soon after a previous event; the existing schedule
            // stays in effect, so there is nothing to do here.
        }
    }
}
