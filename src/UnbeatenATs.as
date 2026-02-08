bool updatingATs = false;

// main coro to get and set info
void GetUnbeatenATsInfo() {
    if (updatingATs) return;
    updatingATs = true;

    await(startnew(_GetUnbeatenATsInfo));

    updatingATs = false;
}

UnbeatenATsData@ g_UnbeatenATs = null;

void _GetUnbeatenATsInfo() {
    @g_UnbeatenATs = UnbeatenATsData();
    while (!g_UnbeatenATs.LoadingDone) yield();
}


class UnbeatenATsData {
    Json::Value@ mainData;
    Json::Value@ recentData;
    string[] keys;
    string[] keysRB;
    private bool doneLoading = false;
    private bool doneLoadingRecent = false;
    int LoadingDoneTime = -1;

    UnbeatenATMap@[] maps;
    UnbeatenATMap@[] hiddenMaps;
    UnbeatenATMap@[] filteredMaps;
    UnbeatenATMap@[] filteredHiddenMaps;

    UnbeatenATMap@[] recentlyBeaten;
    UnbeatenATMap@[] recentlyBeaten100k;

    UnbeatenATsData() {
        StartRefreshData();
    }

    void StartRefreshData() {
        doneLoading = false;
        doneLoadingRecent = false;
        maps = {};
        keys = {};
        hiddenMaps = {};
        filteredMaps = {};
        filteredHiddenMaps = {};
        recentlyBeaten = {};
        recentlyBeaten100k = {};
        startnew(CoroutineFunc(this.RunInit));
        startnew(CoroutineFunc(this.RunRecentInit));
    }

    protected void RunInit() {
        RunGetQuery();
        yield();
        LoadMapsFromJson();
        yield();
        UpdateFiltered();
        doneLoading = true;
        if (LoadingDone)
            LoadingDoneTime = Time::Now;
    }

    protected void RunRecentInit() {
        RunGetRecent();
        yield();
        LoadRecentFromJson();
        yield();
        doneLoadingRecent = true;
        if (LoadingDone)
            LoadingDoneTime = Time::Now;
    }

    protected void RunGetQuery() {
        @mainData = MapMonitor::GetUnbeatenATsInfo();
    }

    protected void RunGetRecent() {
        @recentData = MapMonitor::GetRecentlyBeatenATsInfo();
    }

    protected void LoadMapsFromJson() {
        auto tracks = mainData['tracks'];
        auto keysJ = mainData['keys'];
        for (uint i = 0; i < keysJ.Length; i++) {
            keys.InsertLast(keysJ[i]);
            if ((i+1) % 100 == 0) yield();
        }
        for (uint i = 0; i < tracks.Length; i++) {
            auto track = tracks[i];
            auto map = UnbeatenATMap(track, keys);
            if (map.IsHidden) hiddenMaps.InsertLast(map);
            else maps.InsertLast(map);
            if ((i+1) % 100 == 0) yield();
        }
    }

    protected void LoadRecentFromJson() {
        auto keysJ = recentData['keys'];
        for (uint i = 0; i < keysJ.Length; i++) {
            keysRB.InsertLast(keysJ[i]);
            if ((i+1) % 100 == 0) yield();
        }

        auto tracks = recentData['all']['tracks'];
        for (uint i = 0; i < tracks.Length; i++) {
            auto track = tracks[i];
            recentlyBeaten.InsertLast(UnbeatenATMap(track, keysRB, true));
            if ((i+1) % 100 == 0) yield();
        }

        auto tracks100k = recentData['below100k']['tracks'];
        for (uint i = 0; i < tracks100k.Length; i++) {
            auto track = tracks100k[i];
            recentlyBeaten100k.InsertLast(UnbeatenATMap(track, keysRB, true));
            if ((i+1) % 100 == 0) yield();
        }
    }

    bool get_LoadingDone() {
        return doneLoading && doneLoadingRecent;
    }

    bool hiddenFilters = true;

    UnbeatenATFilters@ filters = UnbeatenATFilters();
    UnbeatenATSorting@ sorting = UnbeatenATSorting();
    void DrawFilters() {
        if (hiddenFilters) {
            if (UI::Button("Show Filters")) {
                hiddenFilters = false;
            }
            return;
        }
        auto origFilters = UnbeatenATFilters(filters);
        if (UI::Button("Hide Filters")) {
            hiddenFilters = true;
        }
        UI::SameLine();
        filters.Draw();
        if (origFilters != filters) {
            startnew(CoroutineFunc(UpdateFiltered));
        }
        auto origSorting = UnbeatenATSorting(sorting);
        sorting.Draw();
        if (origSorting != sorting) {
            startnew(CoroutineFunc(UpdateSortOrder));
        }
    }

    void UpdateFiltered() {
        filteredMaps.RemoveRange(0, filteredMaps.Length);
        filteredHiddenMaps.RemoveRange(0, filteredHiddenMaps.Length);
        filters.OnBeforeUpdate();
        uint lastPause = Time::Now;
        for (uint i = 0; i < maps.Length; i++) {
            if (lastPause + 4 < Time::Now) {
                yield();
                lastPause = Time::Now;
            }
            auto item = maps[i];
            if (filters.Matches(item)) {
                filteredMaps.InsertLast(item);
            }
        }
        for (uint i = 0; i < hiddenMaps.Length; i++) {
            if (lastPause + 4 < Time::Now) {
                yield();
                lastPause = Time::Now;
            }
            auto item = hiddenMaps[i];
            if (filters.Matches(item)) {
                filteredHiddenMaps.InsertLast(item);
            }
        }
        UpdateSortOrder();
    }

    void UpdateSortOrder() {
        // too slow!
        // sorting.sort(filteredMaps);
    }
}

enum Ord {
    EQ, LT, GT, LTE, GTE
}

enum IdRange {
    None = 0,
    R000_100K = 1,
    R100_200K = 2,
    R200_300K = 4,
}

enum NotesFilter {
    None, OnlyWithNotes, OnlyWithoutNotes
}

class UnbeatenATFilters {
    IdRange FilterIdRange = IdRange::None;
    bool ReverseOrder = false;
    bool FilterNbPlayers = false;
    bool ShouldPassAtCheck = false;
    int NbPlayers = 0;
    uint NbPlayersOrd = Ord::LTE;
    int LengthFilterMinMs = 0;
    int LengthFilterMaxMs = -1;
    int64 UploadedFrom = -1;
    string UploadedFromStr = "";
    bool UploadedFromSuccess = true;
    int64 UploadedBefore = -1;
    string UploadedBeforeStr = "";
    bool UploadedBeforeSuccess = true;
    NotesFilter NotesFilter = NotesFilter::None;
    string IdFilter = "";
    string AuthorFilter;
    string MapNameFilter;
    string BeatenByFilter;
    string TagsFilter;
    string ExcludeTagsFilter;

    UnbeatenATFilters() {}
    UnbeatenATFilters(UnbeatenATFilters@ other) {
        FilterIdRange = other.FilterIdRange;
        FilterNbPlayers = other.FilterNbPlayers;
        ShouldPassAtCheck = other.ShouldPassAtCheck;
        NbPlayers = other.NbPlayers;
        NbPlayersOrd = other.NbPlayersOrd;
        ReverseOrder = other.ReverseOrder;
        LengthFilterMinMs = other.LengthFilterMinMs;
        LengthFilterMaxMs = other.LengthFilterMaxMs;
        UploadedFrom = other.UploadedFrom;
        UploadedFromStr = other.UploadedFromStr;
        UploadedFromSuccess = other.UploadedFromSuccess;
        UploadedBefore = other.UploadedBefore;
        UploadedBeforeStr = other.UploadedBeforeStr;
        UploadedBeforeSuccess = other.UploadedBeforeSuccess;
        NotesFilter = other.NotesFilter;
        IdFilter = other.IdFilter;
        AuthorFilter = other.AuthorFilter;
        MapNameFilter = other.MapNameFilter;
        BeatenByFilter = other.BeatenByFilter;
        TagsFilter = other.TagsFilter;
        ExcludeTagsFilter = other.ExcludeTagsFilter;
    }

    bool opEquals(const UnbeatenATFilters@ other) {
        return true
            && FilterIdRange == other.FilterIdRange
            && FilterNbPlayers == other.FilterNbPlayers
            && ShouldPassAtCheck == other.ShouldPassAtCheck
            && NbPlayers == other.NbPlayers
            && NbPlayersOrd == other.NbPlayersOrd
            && ReverseOrder == other.ReverseOrder
            && LengthFilterMinMs == other.LengthFilterMinMs
            && LengthFilterMaxMs == other.LengthFilterMaxMs
            && UploadedFrom == other.UploadedFrom
            && UploadedBefore == other.UploadedBefore
            && NotesFilter == other.NotesFilter
            && IdFilter == other.IdFilter
            && AuthorFilter == other.AuthorFilter
            && MapNameFilter == other.MapNameFilter
            && BeatenByFilter == other.BeatenByFilter
            && TagsFilter == other.TagsFilter
            && ExcludeTagsFilter == other.ExcludeTagsFilter
            ;
    }

    bool Matches(const UnbeatenATMap@ map) {
        if (FilterIdRange != IdRange::None) {
            bool isInRange = false;
            if (FilterIdRange & IdRange::R000_100K > 0 &&      0 < map.TrackID && map.TrackID <= 100000) isInRange = true;
            if (FilterIdRange & IdRange::R100_200K > 0 && 100000 < map.TrackID && map.TrackID <= 200000) isInRange = true;
            if (FilterIdRange & IdRange::R200_300K > 0 && 200000 < map.TrackID && map.TrackID <= 300000) isInRange = true;
            if (!isInRange) return false;
        }
        if (IdFilter.Length > 0 && !tostring(map.TrackID).StartsWith(IdFilter)) return false;
        if (UploadedFrom > 0 && map.UploadedTimestamp < UploadedFrom) return false;
        if (UploadedBefore > 0 && map.UploadedTimestamp > UploadedBefore) return false;
        switch (NotesFilter) {
            case NotesFilter::None: break;
            case NotesFilter::OnlyWithNotes:
                if (map.Reported.Length == 0) return false;
                break;
            case NotesFilter::OnlyWithoutNotes:
                if (map.Reported.Length > 0) return false;
                break;
        }
        if (map.AuthorTime < LengthFilterMinMs) return false;
        if (LengthFilterMaxMs > 0 && map.AuthorTime > LengthFilterMaxMs) return false;
        if (ShouldPassAtCheck && map.AtSetByPlugin) return false;
        if (FilterNbPlayers) {
            if (NbPlayersOrd == Ord::EQ && NbPlayers != map.NbPlayers) return false;
            if (NbPlayersOrd == Ord::LT && NbPlayers >= map.NbPlayers) return false;
            if (NbPlayersOrd == Ord::GT && NbPlayers <= map.NbPlayers) return false;
            if (NbPlayersOrd == Ord::LTE && NbPlayers > map.NbPlayers) return false;
            if (NbPlayersOrd == Ord::GTE && NbPlayers < map.NbPlayers) return false;
        }
        if (!MatchString(authorSParts, map.AuthorDisplayName)) return false;
        if (!MatchString(mapNameSParts, map.Track_Name)) return false;
        if (!MatchString(beatenBySParts, map.ATBeatenUserDisplayName)) return false;
        if (!MatchString(tagsSParts, map.TagNames)) return false;
        if (ExcludeTagsFilter.Length > 0 && MatchString(excludeTagsSParts, map.TagNames)) return false;

        return true;
    }

    void DrawIdRangeFilter(const IdRange &in range, const string &in name) {
        bool inRange = UI::Checkbox(name, FilterIdRange & range > 0);
        if (inRange == (FilterIdRange & range > 0)) return;

        if (inRange)
            FilterIdRange = IdRange(FilterIdRange | range);
        else
            FilterIdRange = IdRange(FilterIdRange & ~range);
    }

    void Draw(bool includeBeatenFilters = false) {
        DrawIdRangeFilter(IdRange::R000_100K, "IDs <= 100k");
        UI::SameLine();
        DrawIdRangeFilter(IdRange::R100_200K, "IDs >100k & <=200k");
        UI::SameLine();
        DrawIdRangeFilter(IdRange::R200_300K, "IDs >200k & <=300k");
        UI::SameLine();
        ShouldPassAtCheck = UI::Checkbox("pass AT check", ShouldPassAtCheck);
        AddSimpleTooltip("Only show maps that passed \"Author Time Check\" plugin check.");

        UI::SetNextItemWidth(80);
        IdFilter = UI::InputText("ID starts with", IdFilter);

        bool afChanged, mnfChanged, bbfChanged, tfChanged, lfChanged;
        UI::SetNextItemWidth(600);
        AuthorFilter = UI::InputText("Author", AuthorFilter, afChanged);
        UI::SetNextItemWidth(600);
        MapNameFilter = UI::InputText("Map Name", MapNameFilter, mnfChanged);
        UI::SetNextItemWidth(600);
        TagsFilter = UI::InputText("Tags (space = wildcard)", TagsFilter, tfChanged);
        AddSimpleTooltip("Match the order of tags shown in the list. Example: \"LO snOW\" will match \"LOL, SnowCar\", but \"snOW LO\" will not.\n\n\\$iAlso, typing too fast might be an issue, so put a space after or something.");
        UI::SetNextItemWidth(600);
        ExcludeTagsFilter = UI::InputText("Exclude Tags (space = wildcard)", ExcludeTagsFilter, tfChanged);
        AddSimpleTooltip("Match the order of tags shown in the list. Example: \"LO snOW\" will match \"LOL, SnowCar\", but \"snOW LO\" will not.\n\n\\$iAlso, typing too fast might be an issue, so put a space after or something.");

        UI::AlignTextToFramePadding();
        UI::Text("Author Time length (seconds):");
        UI::SameLine();
        UI::Text("Min: ");
        UI::SameLine();
        UI::SetNextItemWidth(70);
        LengthFilterMinMs = 1000 * UI::InputInt("##LenghtMin", int(LengthFilterMinMs / 1000), 0);
        UI::SameLine();
        UI::Text("Max: ");
        AddSimpleTooltip("Leave at 0 to not filter by max length.");
        UI::SameLine();
        UI::SetNextItemWidth(70);
        LengthFilterMaxMs = 1000 * UI::InputInt("##LenghtMax", int(LengthFilterMaxMs / 1000), 0);

        UI::AlignTextToFramePadding();
        bool fromChanged, beforeChanged;
        UI::Text("Uploaded From: ");
        UI::SameLine();
        UI::SetNextItemWidth(150);
        UploadedFromStr = UI::InputText("##UploadedFrom", UploadedFromStr, fromChanged);
        AddSimpleTooltip("YYYY-MM-DD format. Leave blank to not filter by uploaded date.", 600);
        if (fromChanged) {
            if (UploadedFromStr == "") {
                UploadedFrom = -1;
                UploadedFromSuccess = true;
            } else {
                try {
                    UploadedFrom = Time::ParseFormatString("%Y-%m-%d", UploadedFromStr);
                    UploadedFromSuccess = true;
                } catch {
                    UploadedFromSuccess = false;
                }
            }
        }

        if (!UploadedBeforeSuccess) UI::PushStyleColor(UI::Col::Text, vec4(1.0, 0.3, 0.3, 1.0));
        UI::SameLine();
        UI::Text(" To: ");
        UI::SameLine();
        UI::SetNextItemWidth(150);
        UploadedBeforeStr = UI::InputText("##UploadedBefore", UploadedBeforeStr, beforeChanged);
        if (!UploadedBeforeSuccess) {
            auto msg = "Expected format: YYYY-MM-DD";
            AddSimpleTooltip("Incorrect date format. Enter a valid date or clear the field.\nUsing previous value of " + Time::FormatString("%Y-%m-%d", UploadedBefore) + " instead.", 800);
            UI::PopStyleColor();
        } else {
            AddSimpleTooltip("YYYY-MM-DD format. Leave blank to not filter by uploaded date.", 600);
        }
        if (beforeChanged) {
            if (UploadedBeforeStr == "") {
                UploadedBefore = -1;
                UploadedBeforeSuccess = true;
            } else {
                try {
                    UploadedBefore = Time::ParseFormatString("%Y-%m-%d", UploadedBeforeStr);
                    UploadedBeforeSuccess = true;
                } catch {
                    UploadedBeforeSuccess = false;
                }
            }
        }

        if (includeBeatenFilters) {
            BeatenByFilter = UI::InputText("Beaten By", BeatenByFilter, bbfChanged);
        }
        // UI::SameLine();
        // ReverseOrder = UI::Checkbox("Reverse Order", ReverseOrder);
    }

    // for the ReverseOrder option, but not sure I want to do it this way
    // int TransformIx(int ix) {}

    string[]@ authorSParts = {};
    string[]@ mapNameSParts = {};
    string[]@ beatenBySParts = {};
    string[]@ tagsSParts = {};
    string[]@ excludeTagsSParts = {};

    void OnBeforeUpdate() {
        @authorSParts = AuthorFilter.ToLower().Replace(" ", "*").Split("*");
        @mapNameSParts = MapNameFilter.ToLower().Replace(" ", "*").Split("*");
        @beatenBySParts = BeatenByFilter.ToLower().Replace(" ", "*").Split("*");
        @tagsSParts = TagsFilter.ToLower().Replace(" ", "*").Split("*");
        @excludeTagsSParts = ExcludeTagsFilter.ToLower().Replace(" ", "*").Split("*");
    }


    bool MatchString(string[]@ searchParts, const string &in text) {
        if (searchParts.Length > 0) {
            string rem = text.ToLower();
            int _ix = 0;
            for (uint i = 0; i < searchParts.Length; i++) {
                if (searchParts[i].Length == 0) continue;
                // if (i == 0 && searchParts[i].Length > 0 && !rem.StartsWith(searchParts[i])) {
                //     return false;
                // } else {
                // }
                _ix = rem.IndexOf(searchParts[i]);
                if (_ix < 0) return false;
                rem = rem.SubStr(_ix + searchParts[i].Length);
            }
        }
        return true;
    }
}

enum UnbeatenTableSort {
    TMX_ID, Name, Author_Name, Nb_Players, AT //, Missing_Time
}

class UnbeatenATSorting {
    UnbeatenTableSort order = UnbeatenTableSort::TMX_ID;

    UnbeatenATSorting() {}
    UnbeatenATSorting(const UnbeatenATSorting@ other) {
        order = other.order;
    }

    bool opEquals(const UnbeatenATSorting@ other) {
        return true
            && order == other.order
            ;
    }

    void sort(UnbeatenATMap@[]@ maps) {
        _g_sortingOrder = order;
        maps.Sort(_g_sortingLess);
    }

    void Draw() {

    }
}

UnbeatenTableSort _g_sortingOrder = UnbeatenTableSort::TMX_ID;


bool _g_sortingLess(const UnbeatenATMap@ const &in a, const UnbeatenATMap@ const &in b) {
    if (_g_sortingOrder == UnbeatenTableSort::TMX_ID) {
        return a.TrackID < b.TrackID;
    }
    if (_g_sortingOrder == UnbeatenTableSort::Name) {
        return a.Track_Name < b.Track_Name;
    }
    if (_g_sortingOrder == UnbeatenTableSort::Author_Name) {
        return a._AuthorDisplayName < b._AuthorDisplayName;
    }
    if (_g_sortingOrder == UnbeatenTableSort::Nb_Players) {
        return a.NbPlayers < b.NbPlayers;
    }
    if (_g_sortingOrder == UnbeatenTableSort::AT) {
        return a.AuthorTime < b.AuthorTime;
    }
    return a.TrackID < b.TrackID;
}

int intLess(int a, int b) {
    if (a < b) return -1;
    if (a == b) return 0;
    return 1;
}
int stringLess(const string &in a, const string &in b) {
    if (a < b) return -1;
    if (a == b) return 0;
    return 1;
}

int lastPickedTrackID;

void OnReportMapClicked(UnbeatenATMap@ map) {
    ReportMapDialog::OpenNew(map);
}

class ReportedData {
    string ReportedBy;
    string Reason;

    ReportedData(const string &in reportedBy, const string &in reason) {
        ReportedBy = reportedBy;
        Reason = reason;
    }
}

class UnbeatenATMap {
    Json::Value@ row;
    string[]@ keys;
    int TrackID = -1;
    int AuthorTime = -1;
    int WR = -1;
    int NbPlayers = -1;
    float LastChecked = -1.;
    string TrackUID;
    string Track_Name;
    string AuthorLogin;
    string Tags;
    string MapType;
    bool IsHidden = false;
    bool AtSetByPlugin = false;
    int64 UploadedTimestamp = 1769868872;
    string Reason = "";
    ReportedData@[] Reported = {};
    string TagNames;
    int ATBeatenTimestamp;
    string ATBeatenUser;

    bool hasPlayed = false;
    bool isBeaten = false;

    UnbeatenATMap(Json::Value@ row, string[]@ keys, bool isBeaten = false) {
        @this.row = row;
        @this.keys = keys;
        this.isBeaten = isBeaten;
        PopulateData();
    }

    void PopulateData () {
        TrackID = GetData('TrackID', TrackID);
        AuthorTime = GetData('AuthorTime', AuthorTime);
        ATFormatted = Time::Format(AuthorTime);
        WR = GetData('WR', WR);
        NbPlayers = GetData('NbPlayers', NbPlayers);
        LastChecked = GetData('LastChecked', LastChecked);
        TrackUID = GetData('TrackUID', TrackUID);
        Track_Name = GetData('Track_Name', Track_Name);
        AuthorLogin = GetData('AuthorLogin', AuthorLogin);
        Tags = GetData('Tags', Tags);
        MapType = GetData('MapType', MapType);
        if (HasKey('IsHidden')) IsHidden = GetData('IsHidden', IsHidden);
        if (HasKey('Reason')) Reason = GetData('Reason', Reason);
        if (HasKey('AtSetByPlugin')) AtSetByPlugin = GetData('AtSetByPlugin', AtSetByPlugin);
        if (HasKey('Reported')) Reported = GetReportedData();
        if (HasKey('UploadedTimestamp')) UploadedTimestamp = GetData('UploadedTimestamp', UploadedTimestamp);
        SetTags();
        if (S_API_Choice == UnbeatenATsAPI::XertroVs_API) {
            QueueAuthorLoginCache(AuthorLogin);
        } else if (S_API_Choice == UnbeatenATsAPI::Teggots_API) {
            QueueWsidNameCache(AuthorLogin);
        } else {
            throw("unknown api choice: " + tostring(S_API_Choice));
        }
        if (isBeaten) {
            ATBeatenTimestamp = GetData('ATBeatenTimestamp', ATBeatenTimestamp);
            ATBeatenUser = GetData('ATBeatenUsers', ATBeatenUser);
            QueueWsidNameCache(ATBeatenUser);
        }
        hasPlayed = HasPlayedTrack(TrackID);
    }

    string CSVHeader() {
        return string::Join(keys, ",") + "\n";
    }

    string CSVRow() {
        auto rowStr = Json::Write(row);
        return rowStr.SubStr(1, rowStr.Length - 2) + "\n";
    }

    string _AuthorDisplayName;
    string get_AuthorDisplayName() const {
        if (S_API_Choice == UnbeatenATsAPI::XertroVs_API) return GetDisplayNameForLogin(AuthorLogin);
        else if (S_API_Choice == UnbeatenATsAPI::Teggots_API) return GetDisplayNameForWsid(AuthorLogin);
        throw("unknown api choice: " + tostring(S_API_Choice));
        return "";
        // if (_AuthorDisplayName.Length > 0) return _AuthorDisplayName;
        // if (loginCache.HasKey(AuthorLogin)) _AuthorDisplayName = GetDisplayNameForLogin(AuthorLogin);
    }

    string get_ATBeatenUserDisplayName() const {
        return GetDisplayNameForWsid(ATBeatenUser);
    }

    string ATFormatted;

    void SetTags() {
        while (g_TmxTags is null) yield();
        auto parts = Tags.Split(",");
        for (uint i = 0; i < parts.Length; i++) {
            auto item = parts[i];
            if (parts[i].Length == 0) continue;
            int tagId;
            try {
                tagId = Text::ParseInt(parts[i]);
            } catch {
                warn("exception parsing tag ID: " + parts[i] + "; exception: " + getExceptionInfo());
                continue;
            }
            if (i > 0) TagNames += ", ";
            if (tagId >= int(tagLookup.Length)) {
                TagNames += tostring(tagId);
            } else {
                TagNames += tagLookup[tagId];
            }
            // TagNames.InsertLast(tagLookup[tagId]);
        }
    }

    int GetData(const string &in name, int _) {
        return GetData(name);
    }
    int GetData(const string &in name, int64 _) {
        return GetData(name);
    }
    float GetData(const string &in name, float _) {
        return GetData(name);
    }
    bool GetData(const string &in name, bool _) {
        return GetData(name);
    }

    ReportedData@[] GetReportedData() {
        const auto rows = GetData('Reported');
        ReportedData@[] ret = {};
        for (uint i = 0; i < rows.Length; i++) {
            ret.InsertLast(ReportedData(string(rows[i][0]), string(rows[i][1])));
        }
        return ret;
    }

    string GetData(const string &in name, const string &in _) {
        auto j = GetData(name);
        // print("GetDataStr: " + Json::Write(j));
        if (j is null || j.GetType() == Json::Type::Null) return "";
        return j;
    }
    Json::Value@ GetData(const string &in name) {
        return row[keys.Find(name)];
    }
    bool HasKey(const string &in name) {
        return keys.Find(name) >= 0;
    }

    protected void _OnPlayMap_MarkPlayed() {
        try {
            MarkTrackPlayed(TrackID);
            this.hasPlayed = true;
        } catch {
            NotifyWarning("Failed to mark track as played D:\nException: " + getExceptionInfo());
        }
    }

    void OnClickPlayMapCoro() {
        _OnPlayMap_MarkPlayed();
        LoadMapNow(MapMonitor::MapUrl(TrackID));
    }

    void OnClickPlayTogetherCoro() {
        _OnPlayMap_MarkPlayed();
        Together::SetRoomMap_Async(TrackUID);
    }

    void DrawUnbeatenTableRow(int i) {
        UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(2, 0));
        UI::TableNextRow();

        DrawTableStartCols(i);

        UI::TableNextColumn();
        UI::Text(TagNames);
        AddSimpleTooltip(TagNames);

        DrawATCol();
        DrawWRCols();
        DrawTableEndCols();

        if (g_isUserTrusted) {
            UI::TableNextColumn();
            if(UI::BeginMenu("Admin##" + TrackID)) {
                if (UI::MenuItem("Add/Replace Note##" + TrackID)) {
                    OnReportMapClicked(this);
                }
                if (UI::MenuItem("Remove my Note##" + TrackID)) {
                    startnew(CoroutineFunc(RemoveMyCommunityNote));
                }
                UI::EndMenu();
            }
        }

        UI::PopStyleVar();
    }

    void RemoveMyCommunityNote() {
        bool success = MapMonitor::RemoveMyCommunityNote(TrackID);
        if (success) NotifySuccess("Successfuly removed note from map " + TrackID);
        else NotifyError("Failed to remove note from map " + TrackID);
    }

    void DrawHiddenUnbeatenTableRow(int i) {
        UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(2, 0));
        UI::TableNextRow();

        DrawTableStartCols(i);

        UI::TableNextColumn();
        UI::Text(TagNames);
        AddSimpleTooltip(TagNames);

        DrawATCol();
        DrawWRCols();
        DrawTableEndCols();

        UI::TableNextColumn();
        UI::Text("\\$f60" + Icons::ExclamationTriangle);
        AddSimpleTooltip(Reason);

        UI::PopStyleVar();
    }

    void DrawATCol() {
        UI::TableNextColumn();
        if (AtSetByPlugin) {
            UI::Text("\\$ff0" + Time::Format(AuthorTime));
            AddSimpleTooltip("This AT was likely set by a plugin. This doesnt mean AT is impossible/cheated.");
        } else {
            UI::Text(Time::Format(AuthorTime));
        }
    }

    void DrawWRCols() {
        UI::TableNextColumn();
        UI::Text(WR >= 0 ? Time::Format(WR) : "--");

        // missing time
        UI::TableNextColumn();
        UI::Text(WR < 0 ? "--" : Time::Format(WR - AuthorTime));
    }

    void DrawBeatenTableRow(int i) {
        UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(2, 0));
        UI::TableNextRow();

        DrawTableStartCols(i);

        // No need to say AT is set by plugin
        UI::TableNextColumn();
        UI::Text(Time::Format(AuthorTime));

        UI::TableNextColumn();
        UI::Text(WR >= 0 ? Time::Format(WR) : "--");

        // missing time
        UI::TableNextColumn();
        UI::Text(ATBeatenUserDisplayName);

        DrawTableEndCols();
        UI::PopStyleVar();
    }

    // 3 cols
    void DrawTableStartCols(int i) {
        UI::TableNextColumn();
        if (Reported.Length > 0) {
            if (UI::Button("\\$f60" + Icons::ExclamationTriangle + tostring(i) + "." )){
                MapNotesDialog::OpenNew(this.Reported);
            };
            AddReportedTooltip();
        } else {
            UI::Text(tostring(i) + ".");
        }

        UI::TableNextColumn();
        auto btnLab = Icons::Play + " " + TrackID;
        if (lastPickedTrackID == TrackID ? UI::ButtonColored(btnLab, .3) :
            hasPlayed ? UI::ButtonColored(btnLab, S_PlayedMapColor) : UI::Button(btnLab)) {
            lastPickedTrackID = TrackID;
            startnew(CoroutineFunc(OnClickPlayMapCoro));
        }
        AddSimpleTooltip("Load Map " + TrackID + ": " + Track_Name);

        UI::SameLine();
        if (Together::DrawPlayTogetherButton(this, Icons::Play + Icons::BuildingO + "##" + TrackID, false)) {
            AddSimpleTooltip("Play this map in a club room. You must be in a room already.");
        }

        UI::TableNextColumn();
        UI::Text(Track_Name);

        UI::TableNextColumn();
        UI::Text(AuthorDisplayName);
    }

    // 2 cols
    void DrawTableEndCols() {
        // player count
        UI::TableNextColumn();
        UI::Text("" + NbPlayers);

        // links
        UI::TableNextColumn();
        DrawLinkButtons();
    }

    void DrawLinkButtons() {
        // tmx + tm.io
        if (UI::Button("TM.io##" + TrackID)) {
            OpenBrowserURL("https://trackmania.io/#/leaderboard/"+TrackUID+"?utm_source=unbeaten-ats-plugin");
        }
        UI::SameLine();
        if (UI::Button("TMX##" + TrackID)) {
            OpenBrowserURL("https://trackmania.exchange/maps/"+TrackID+"?utm_source=unbeaten-ats-plugin");
        }
    }

    void AddReportedTooltip() {
        if (UI::IsItemHovered()) {
            string msg = "This map has community notes:";
            for (uint j = 0; j < Reported.Length; j++) {
                const ReportedData@ rep = Reported[j];
                msg += "\n" + GetDisplayNameForWsid(rep.ReportedBy);
                if (rep.Reason == "") msg += ": <no reason>";
                else msg += ": \"" + rep.Reason + "\"";
            }
            ShowSimpleTooltip(msg, 700);
        }
    }
}

Json::Value@ g_TmxTags = null;
string[] tagLookup;

void PopulateTmxTags() {
    @g_TmxTags = TMX::GetTmxTags();
    tagLookup.Resize(g_TmxTags.Length + 1);
    for (uint i = 0; i < g_TmxTags.Length; i++) {
        // {Color, ID, Name}
        auto tag = g_TmxTags[i];
        int ix = tag['ID'];
        tagLookup[ix] = tag['Name'];
    }
}
