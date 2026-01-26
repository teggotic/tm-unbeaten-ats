enum UnbeatenATsAPI {
  XertroVs_API, Teggots_API
}

[Setting hidden]
UnbeatenATsAPI S_API_Choice = UnbeatenATsAPI::XertroVs_API;

[SettingsTab name="API" order=0]
void RenderAPISettings() {
    if (UI::Button("Reset to default")) {
        S_API_Choice = UnbeatenATsAPI::XertroVs_API;
        RefreshAPI();
    }

    UI::SetNextItemWidth(200);
    if (UI::BeginCombo("API to use as map list source", tostring(S_API_Choice))) {
        if (UI::Selectable("XertroVs API", S_API_Choice == UnbeatenATsAPI::XertroVs_API)) {
            S_API_Choice = UnbeatenATsAPI::XertroVs_API;
            RefreshAPI();
        }
        if (S_API_Choice == UnbeatenATsAPI::XertroVs_API) UI::SetItemDefaultFocus();
        if (UI::Selectable("Teggots API", S_API_Choice == UnbeatenATsAPI::Teggots_API)) {
            S_API_Choice = UnbeatenATsAPI::Teggots_API;
            RefreshAPI();
        }
        if (S_API_Choice == UnbeatenATsAPI::Teggots_API) UI::SetItemDefaultFocus();
        UI::EndCombo();
    }
    UI::Text("You should probably use Teggots API because XervoVs API is not updating unbeaten ats from the start of 2026");
    UI::Text("Warning: Teggots API is highly experimental and does not have all the features of XertroVs API");
}

void RefreshAPI() {
    startnew(MapMonitorCheckIfUserIsTrusted);
    if (g_UnbeatenATs !is null) g_UnbeatenATs.StartRefreshData();
    if (g_UnbeatenATsLeaderboard !is null) g_UnbeatenATsLeaderboard.StartRefreshData();
}

string APIChoiceToBaseURL(UnbeatenATsAPI choice) {
    if (choice == UnbeatenATsAPI::XertroVs_API) return "https://map-monitor.xk.io";
    if (choice == UnbeatenATsAPI::Teggots_API) return "https://map-monitor.teggot.name";
    throw("unknown api choice: " + tostring(choice));
    return "";
}

string GetAPIBaseURL() {
    return APIChoiceToBaseURL(S_API_Choice);
}

const string MM_API_ROOT {
    get {
        return GetAPIBaseURL();
    }
}

namespace MapMonitor {
    Json::Value@ GetNbPlayersForMap(const string &in mapUid) {
        return CallMapMonitorApiPath('/map/' + mapUid + '/nb_players/refresh');
    }

    int GetNextMapByTMXTrackID(int TrackID) {
        return CallMapMonitorApiPath('/tmx/' + TrackID + '/next')["next"];
    }

    Json::Value@ GetUnbeatenATsInfo() {
        return CallMapMonitorApiPath('/tmx/unbeaten_ats');
    }

    Json::Value@ GetUnbeatenLeaderboard() {
        return CallMapMonitorApiPath('/tmx/unbeaten_ats/leaderboard');
    }

    Json::Value@ GetUnbeatenInfoFor(int TrackID) {
        return CallMapMonitorApiPath('/tmx/unbeaten_ats/' + TrackID);
    }

    Json::Value@ GetUnbeatenInfoUrlFor(int TrackID) {
        return MM_API_ROOT + '/tmx/unbeaten_ats/' + TrackID;
    }

    Json::Value@ GetRecentlyBeatenATsInfo() {
        return CallMapMonitorApiPath('/tmx/recently_beaten_ats');
    }

    bool ReportMap(int TrackID, const string &in reason) {
        Json::Value@ payload = Json::Object();
        payload["reason"] = reason;
        bool success;
        CallMapMonitorApiPathAuthorized('/management/report_map/' + TrackID, Net::HttpMethod::Post, payload, success);
        return success;
    }

    bool RemoveMyCommunityNote(int TrackID) {
        bool success;
        CallMapMonitorApiPathAuthorized('/management/report_map/' + TrackID, Net::HttpMethod::Delete, null, success);
        return success;
    }

    bool AddMissingMap(int TrackID) {
        bool success;
        CallMapMonitorApiPathAuthorized('/management/add_missing_map/' + TrackID, Net::HttpMethod::Post, null, success);
        return success;
    }

    string MapUrl(int TrackID) {
        return MM_API_ROOT + "/maps/download/" + TrackID;
    }

    bool g_mmAuthTokenIsLoading = false;
    string g_mmAuthToken = "";

    const bool IsUserTrusted() {
        return CallMapMonitorApiPath("/auth/is-trusted/" + NadeoServices::GetAccountID());
    }

    const string GetAuthToken() {
        if (g_mmAuthTokenIsLoading) {
            while (g_mmAuthTokenIsLoading) {
                yield();
            }
        }
        if (g_mmAuthToken != "") return g_mmAuthToken;

        g_mmAuthTokenIsLoading = true;

        trace("Getting openplanet token");
        auto tokenTask = Auth::GetToken();
        while (!tokenTask.Finished()) {
            yield();
        }
        trace("Getting map-monitor token");
        auto mmTokenRes = AuthMapMonitor(tokenTask.Token());
        g_mmAuthToken = mmTokenRes.Get("token");
        g_mmAuthTokenIsLoading = false;
        return g_mmAuthToken;
    }
}
