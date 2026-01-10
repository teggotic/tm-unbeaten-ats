enum UnbeatenATsAPI {
  XertroVs_API, Teggots_API
}

[Setting category="API" name="Which API? Please note that Teggots API is highly experimental."]
UnbeatenATsAPI S_API_Choice = UnbeatenATsAPI::XertroVs_API;

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

    string MapUrl(int TrackID) {
        return MM_API_ROOT + "/maps/download/" + TrackID;
    }
}
