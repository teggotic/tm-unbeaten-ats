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
    UnbeatenATMap@[] recentlyBeaten200k;
    UnbeatenATMap@[] recentlyBeaten300k;

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
        recentlyBeaten200k = {};
        recentlyBeaten300k = {};
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

        if (recentData.HasKey('below100k'))
            IngestRecentMaps(recentData['below100k']['tracks'], recentlyBeaten100k, keysRB);
        if (recentData.HasKey('below200k'))
            IngestRecentMaps(recentData['below200k']['tracks'], recentlyBeaten200k, keysRB);
        if (recentData.HasKey('below300k'))
            IngestRecentMaps(recentData['below300k']['tracks'], recentlyBeaten300k, keysRB);
    }

    void IngestRecentMaps(Json::Value@ mapList, UnbeatenATMap@[]@ target, string[]@ keysRB) {
        for (uint i = 0; i < mapList.Length; i++) {
            target.InsertLast(UnbeatenATMap(mapList[i], keysRB, true));
            if ((i+1) % 100 == 0) yield();
        }
    }

    bool get_LoadingDone() {
        return doneLoading && doneLoadingRecent;
    }

    bool hiddenFilters = false;

    UnbeatenATFilters@ filters = UnbeatenATFilters();
    UnbeatenATSorting@ sorting = UnbeatenATSorting();
    void DrawFilters() {
        if (hiddenFilters) {
            if (UI::Button("Show Filters")) {
                hiddenFilters = false;
            }
            return;
        }
        if (UI::Button("Hide Filters")) {
            hiddenFilters = true;
        }
        UI::SameLine();
        if (UI::ButtonColored("Reset filters", 0.0)) {
            filters.Reset();
            filters.MarkChanged();
        }

        filters.Draw();
        if (filters._changed) {
            startnew(CoroutineFunc(UpdateFiltered));
            filters._changed = false;
        }
        auto origSorting = UnbeatenATSorting(sorting);
        sorting.Draw();
        if (origSorting != sorting) {
            startnew(CoroutineFunc(UpdateSortOrder));
        }
    }

    int _updateCoroIdx = 0;

    void UpdateFiltered() {
        _updateCoroIdx++;  // used to detect if newer UpdateFiltered() already started
        auto idxx = _updateCoroIdx;
        filteredMaps.RemoveRange(0, filteredMaps.Length);
        filteredHiddenMaps.RemoveRange(0, filteredHiddenMaps.Length);
        filters.OnBeforeUpdate();
        uint lastPause = Time::Now;
        for (uint i = 0; i < maps.Length; i++) {
            if (lastPause + 4 < Time::Now) {
                yield();
                if (idxx != _updateCoroIdx) return;
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
                if (idxx != _updateCoroIdx) return;
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
    R300_400K = 8,
}

enum NotesFilter {
    None, OnlyWithNotes, OnlyWithoutNotes
}

funcdef void MarkChangedCB();

class UploadedDateFilter {
    int64 value = -1;
    string valueStr = "";
    bool success = true;

    void Validate(MarkChangedCB@ cb = null) {
        if (valueStr == "") {
            value = -1;
            success = true;
            if (cb !is null) cb();
        } else {
            try {
                auto newValue = Time::ParseFormatString("%Y-%m-%d", valueStr);
                if (newValue != value) {
                    value = newValue;
                    if (cb !is null) cb();
                }
                success = true;
            } catch {
                success = false;
            }
        }
    }

    void TryRestore(const string &in saved) {
        try {
            auto uploadedFrom = Json::Parse(saved);
            valueStr = string(uploadedFrom['valueStr']);
            Validate();
        } catch {}
    }

    string Save() {
        Json::Value saved = Json::Object();
        saved["valueStr"] = valueStr;
        return Json::Write(saved);
    }
}

namespace FilterSettings {
    [Setting hidden]
    IdRange FilterIdRange;

    [Setting hidden]
    bool ReverseOrder;

    [Setting hidden]
    bool FilterNbPlayers;

    [Setting hidden]
    bool ShouldPassAtCheck;

    [Setting hidden]
    int NbPlayers;

    [Setting hidden]
    uint NbPlayersOrd;

    [Setting hidden]
    int LengthFilterMinMs;

    [Setting hidden]
    int LengthFilterMaxMs;

    [Setting hidden]
    string UploadedFromRaw;

    [Setting hidden]
    string UploadedBeforeRaw;

    [Setting hidden]
    NotesFilter NotesFilter;

    [Setting hidden]
    string IdFilter;

    [Setting hidden]
    string AuthorFilter;

    [Setting hidden]
    string MapNameFilter;

    [Setting hidden]
    string BeatenByFilter;

    [Setting hidden]
    string TagsFilterRaw;

    [Setting hidden]
    bool TagsFilterStrict;

    [Setting hidden]
    string ExcludeTagsFilterRaw;

    [Setting hidden]
    bool ShowOnlyNotes;
}

class UnbeatenATFilters {
    UploadedDateFilter@ UploadedFrom;
    UploadedDateFilter@ UploadedBefore;

    int[] TagsFilter;
    int[] ExcludeTagsFilter;

    bool _changed = false;
    void MarkChanged() {
        _changed = true;
    }

    UnbeatenATFilters() {
        @UploadedFrom = UploadedDateFilter();
        UploadedFrom.TryRestore(FilterSettings::UploadedFromRaw);
        @UploadedBefore = UploadedDateFilter();
        UploadedBefore.TryRestore(FilterSettings::UploadedBeforeRaw);

        TagsFilter = {};
        RestoreIntArray(FilterSettings::TagsFilterRaw, TagsFilter);
        ExcludeTagsFilter = {};
        RestoreIntArray(FilterSettings::ExcludeTagsFilterRaw, ExcludeTagsFilter);
    }

    void RestoreIntArray(string &in saved, int[]@ &in arr) {
        try {
            auto arrJ = Json::Parse(saved);
            arr.RemoveRange(0, arr.Length);
            for (uint i = 0; i < arrJ.Length; i++) {
                arr.InsertLast(arrJ[i]);
            }
        } catch {}
    }

    string ArrayToJson(int[]@ arr) {
        Json::Value arrJ = Json::Array();
        for (uint i = 0; i < arr.Length; i++) {
            arrJ.Add(arr[i]);
        }
        return Json::Write(arrJ);
    }

    void UploadedFromChanged() {
        MarkChanged();
        FilterSettings::UploadedFromRaw = UploadedFrom.Save();
    }

    void UploadedBeforeChanged() {
        MarkChanged();
        FilterSettings::UploadedBeforeRaw = UploadedBefore.Save();
    }

    void TagsFilterChanged() {
        trace("TagsFilterChanged");
        MarkChanged();
        FilterSettings::TagsFilterRaw = Json::Write(TagsFilter);
    }

    void ExcludeTagsFilterChanged() {
        trace("ExcludeTagsFilterChanged");
        MarkChanged();
        FilterSettings::ExcludeTagsFilterRaw = Json::Write(ExcludeTagsFilter);
    }

    void Reset() {
        FilterSettings::FilterIdRange = IdRange::None;
        FilterSettings::ReverseOrder = false;
        FilterSettings::FilterNbPlayers = false;
        FilterSettings::ShouldPassAtCheck = false;
        FilterSettings::NbPlayers = 0;
        FilterSettings::NbPlayersOrd = Ord::LTE;
        FilterSettings::LengthFilterMinMs = 0;
        FilterSettings::LengthFilterMaxMs = -1;
        @UploadedFrom = UploadedDateFilter();
        FilterSettings::UploadedFromRaw = UploadedFrom.Save();
        @UploadedBefore = UploadedDateFilter();
        FilterSettings::UploadedBeforeRaw = UploadedBefore.Save();
        FilterSettings::NotesFilter = NotesFilter::None;
        FilterSettings::IdFilter = "";
        FilterSettings::AuthorFilter = "";
        FilterSettings::MapNameFilter = "";
        FilterSettings::BeatenByFilter = "";
        TagsFilter = {};
        FilterSettings::TagsFilterRaw = ArrayToJson(TagsFilter);
        FilterSettings::TagsFilterStrict = false;
        ExcludeTagsFilter = {};
        FilterSettings::ExcludeTagsFilterRaw = ArrayToJson(ExcludeTagsFilter);
        FilterSettings::ShowOnlyNotes = false;
    }

    bool Matches(const UnbeatenATMap@ map) {
        if (FilterSettings::FilterIdRange != IdRange::None) {
            bool isInRange = false;
            if (FilterSettings::FilterIdRange & IdRange::R000_100K > 0 &&      0 < map.TrackID && map.TrackID <= 100000) isInRange = true;
            if (FilterSettings::FilterIdRange & IdRange::R100_200K > 0 && 100000 < map.TrackID && map.TrackID <= 200000) isInRange = true;
            if (FilterSettings::FilterIdRange & IdRange::R200_300K > 0 && 200000 < map.TrackID && map.TrackID <= 300000) isInRange = true;
            if (FilterSettings::FilterIdRange & IdRange::R300_400K > 0 && 300000 < map.TrackID && map.TrackID <= 400000) isInRange = true;
            if (!isInRange) return false;
        }
        if (FilterSettings::ShowOnlyNotes && map.Reported.Length == 0) return false;
        if (FilterSettings::IdFilter.Length > 0 && !tostring(map.TrackID).StartsWith(FilterSettings::IdFilter)) return false;
        if (UploadedFrom.value > 0 && map.UploadedTimestamp < UploadedFrom.value) return false;
        if (UploadedBefore.value > 0 && map.UploadedTimestamp > UploadedBefore.value) return false;
        switch (FilterSettings::NotesFilter) {
            case NotesFilter::None: break;
            case NotesFilter::OnlyWithNotes:
                if (map.Reported.Length == 0) return false;
                break;
            case NotesFilter::OnlyWithoutNotes:
                if (map.Reported.Length > 0) return false;
                break;
        }
        if (map.AuthorTime < FilterSettings::LengthFilterMinMs) return false;
        if (FilterSettings::LengthFilterMaxMs > 0 && map.AuthorTime > FilterSettings::LengthFilterMaxMs) return false;
        if (FilterSettings::ShouldPassAtCheck && map.AtSetByPlugin) {
            if (map.Validation is null || !map.Validation.ValidationUploaded) return false;
        }
        if (FilterSettings::FilterNbPlayers) {
            if (FilterSettings::NbPlayersOrd == Ord::EQ && FilterSettings::NbPlayers != map.NbPlayers) return false;
            if (FilterSettings::NbPlayersOrd == Ord::LT && FilterSettings::NbPlayers >= map.NbPlayers) return false;
            if (FilterSettings::NbPlayersOrd == Ord::GT && FilterSettings::NbPlayers <= map.NbPlayers) return false;
            if (FilterSettings::NbPlayersOrd == Ord::LTE && FilterSettings::NbPlayers > map.NbPlayers) return false;
            if (FilterSettings::NbPlayersOrd == Ord::GTE && FilterSettings::NbPlayers < map.NbPlayers) return false;
        }
        if (!MatchString(authorSParts, map.AuthorDisplayName)) return false;
        if (!MatchString(mapNameSParts, map.Track_Name)) return false;
        if (!MatchString(beatenBySParts, map.ATBeatenUserDisplayName)) return false;
        if (TagsFilter.Length > 0) {
            if (FilterSettings::TagsFilterStrict) {
                for (uint i = 0; i < TagsFilter.Length; i++) {
                    if (map.Tags.Find(TagsFilter[i]) == -1) return false;
                }
            } else {
                bool found = false;
                for (uint i = 0; i < TagsFilter.Length; i++) {
                    if (map.Tags.Find(TagsFilter[i]) != -1) {
                        found = true;
                        break;
                    }
                }
                if (!found) return false;
            }
        }
        if (ExcludeTagsFilter.Length > 0) {
            for (uint i = 0; i < ExcludeTagsFilter.Length; i++) {
                if (map.Tags.Find(ExcludeTagsFilter[i]) != -1) return false;
            }
        }

        return true;
    }

    void DrawIdRangeFilter(const IdRange &in range, const string &in name) {
        bool inRange = TrackedCheckbox(name, FilterSettings::FilterIdRange & range > 0);
        if (inRange == (FilterSettings::FilterIdRange & range > 0)) return;

        if (inRange)
            FilterSettings::FilterIdRange = IdRange(FilterSettings::FilterIdRange | range);
        else
            FilterSettings::FilterIdRange = IdRange(FilterSettings::FilterIdRange & ~range);
    }

    void DrawTagsFilter(const string &in comboId, int[]@ tags, int maxAllowed = 0, MarkChangedCB@ cb = null) {
        string label;
        if (tags.Length == 0) {
            label = "No tags selected";
        } else if (tags.Length <= 3) {
            label = tagLookup[tags[0]];
            for (uint i = 1; i < tags.Length; i++) {
                label += ", " + tagLookup[tags[i]];
            }
        } else {
            label = tags.Length + " tags selected";
        }
        auto tooMany = maxAllowed != 0 && tags.Length > maxAllowed;
        if (tooMany) {
            UI::PushStyleColor(UI::Col::Text, vec4(0.8, 0.8, 0.3, 1.0));
        }
        if (UI::BeginCombo(comboId, label)) {
            for (uint i = 0; i < sortedTagList.Length; i++) {
                if (sortedTagList[i].Name == "") continue;

                const auto tag = sortedTagList[i];

                int idx = tags.Find(tag.ID);
                if (TrackedCheckbox(tagLookup[tag.ID], idx != -1)) {
                    if (idx == -1) {
                        tags.InsertLast(tag.ID);
                        if (cb !is null) cb();
                    }
                } else {
                    if (idx != -1) {
                        tags.RemoveAt(idx);
                        if (cb !is null) cb();
                    }
                }
            }
            UI::EndCombo();
        }
        if (tooMany) {
            UI::PopStyleColor();
            AddSimpleTooltip("Any map can have " + maxAllowed + " tags at maximum. You should probably remove some tags or switch to OR mode.");
        }
        UI::PushStyleColor(UI::Col::Button, vec4(1.0, 1.0, 1.0, 0.2));
        UI::BeginDisabled(tags.Length == 0);
        UI::SameLine();
        if (UI::Button("x##" + comboId)) {
            tags.RemoveRange(0, tags.Length);
            if (cb !is null) cb();
        }
        UI::EndDisabled();
        UI::PopStyleColor();
    }

    const bool TrackedCheckbox(const string &in name, bool &in value) {
        auto ret = UI::Checkbox(name, value);
        if (ret != value) MarkChanged();
        return ret;
    }

    const int TrackedInputInt(const string &in name, int &in value, bool &out changed, int step = 1) {
        auto ret = UI::InputInt(name, value, step);
        if (ret != value) {
            MarkChanged();
            changed = true;
        } else {
            changed = false;
        }
        return ret;
    }

    const string TrackedInputText(const string &in name, string &in value) {
        bool changed;
        auto ret = UI::InputText(name, value, changed);
        if (changed) MarkChanged();
        return ret;
    }

    void DrawUploadedDateFilter(const string &in label, UploadedDateFilter@ &in filter, MarkChangedCB@ cb) {
        UI::SetNextItemWidth(85);
        if (!filter.success) UI::PushStyleColor(UI::Col::Text, vec4(1.0, 0.3, 0.3, 1.0));
        bool filterChanged;
        filter.valueStr = UI::InputText("##" + label, filter.valueStr, filterChanged);
        if (!filter.success) {
            string msg = "Incorrect date format; Expected YYYY-MM-DD (e.g. 2026-01-01). Enter a valid date or clear the field.";
            if (filter.value != -1) msg += "\nUsing previous value of " + Time::FormatString("%Y-%m-%d", filter.value) + " instead.";
            AddSimpleTooltip(msg, 800);
            UI::PopStyleColor();
        } else {
            AddSimpleTooltip("YYYY-MM-DD format (e.g. 2026-01-01). Leave blank to not filter by uploaded date.", 600);
        }

        if (filterChanged) {
            filter.Validate(cb);
        }
    }

    void Draw(bool includeBeatenFilters = false) {
        const int LabelSize = 120;
        const int InputsSize = 300;

        {
            DrawIdRangeFilter(IdRange::R000_100K, "IDs 0-100k");
            UI::SameLine();
            DrawIdRangeFilter(IdRange::R100_200K, "IDs 100k-200k");
            UI::SameLine();
            DrawIdRangeFilter(IdRange::R200_300K, "IDs 200k-300k");
            UI::SameLine();
            DrawIdRangeFilter(IdRange::R300_400K, "IDs 300k-400k");

            UI::SameLine();
            FilterSettings::ShouldPassAtCheck = TrackedCheckbox("AT isn't plugin", FilterSettings::ShouldPassAtCheck);
            AddSimpleTooltip("Only show maps that passed \"Author Time Check\" plugin check.\nAlso shows maps where validation replay was submitted", 600);

            UI::SameLine();
            UI::SetNextItemWidth(80);
            FilterSettings::IdFilter = TrackedInputText("ID starts with", FilterSettings::IdFilter);

            UI::SameLine();
            FilterSettings::ShowOnlyNotes = TrackedCheckbox("Only with notes", FilterSettings::ShowOnlyNotes);
        }

        {
            UI::FieldName("Author Name:", LabelSize);
            UI::SetNextItemWidth(InputsSize);
            FilterSettings::AuthorFilter = TrackedInputText("##Author", FilterSettings::AuthorFilter);

            UI::SameLine();
            UI::SetCursorPos(UI::GetCursorPos() + vec2(50, 0));

            UI::FieldName("Map Name:", LabelSize);
            UI::SetNextItemWidth(InputsSize);
            FilterSettings::MapNameFilter = TrackedInputText("##MapName", FilterSettings::MapNameFilter);
        }

        {
            {
                UI::FieldName("AT (seconds):", LabelSize);
                AddSimpleTooltip("Filter by AT length");
                UI::FieldName("Min:", 50);
                UI::SetNextItemWidth(70);
                bool lengthFilterMinMsChanged;
                auto lengthFilterMinMs = TrackedInputInt("##LengthMin", int(FilterSettings::LengthFilterMinMs / 1000), lengthFilterMinMsChanged, 0);
                if (lengthFilterMinMsChanged) FilterSettings::LengthFilterMinMs = lengthFilterMinMs * 1000;
                AddSimpleTooltip("Leave at 0 to not filter by max length.");

                UI::SameLine();
                UI::SetCursorPos(UI::GetCursorPos() + vec2(50, 0));

                UI::FieldName("Max:", 50);
                UI::SetNextItemWidth(70);
                bool lengthFilterMaxMsChanged;
                auto lengthFilterMaxMs = TrackedInputInt("##LengthMax", int(FilterSettings::LengthFilterMaxMs / 1000), lengthFilterMaxMsChanged, 0);
                if (lengthFilterMaxMsChanged) FilterSettings::LengthFilterMaxMs = lengthFilterMaxMs * 1000;
                AddSimpleTooltip("Leave at 0 to not filter by max length.");
            }

            UI::SameLine();
            UI::SetCursorPos(UI::GetCursorPos() + vec2(50, 0));

            {
                UI::FieldName("Uploaded:", LabelSize);
                bool fromChanged, beforeChanged;
                UI::FieldName("From:", 50);
                DrawUploadedDateFilter("UploadedFrom", UploadedFrom, MarkChangedCB(this.UploadedFromChanged));

                UI::SameLine();
                UI::SetCursorPos(UI::GetCursorPos() + vec2(40, 0));

                UI::FieldName("To:", 50);
                UI::SameLine();
                DrawUploadedDateFilter("UploadedBefore", UploadedBefore, MarkChangedCB(this.UploadedBeforeChanged));
            }
        }

        {
            UI::FieldName("Tags: ", 54);
            FilterSettings::TagsFilterStrict = TrackedCheckbox("AND", FilterSettings::TagsFilterStrict);
            AddSimpleTooltip("If checked, map has to include all of the selected tags.\nOtherwise, map must have at least one of the selected tags.", 800);
            UI::SameLine();
            UI::SetNextItemWidth(InputsSize - 32);
            DrawTagsFilter("##Tags", TagsFilter, FilterSettings::TagsFilterStrict ? 3 : 0, MarkChangedCB(this.TagsFilterChanged));

            UI::SameLine();
            UI::SetCursorPos(UI::GetCursorPos() + vec2(50, 0));

            UI::FieldName("Exclude Tags: ", LabelSize);
            UI::SetNextItemWidth(InputsSize - 32);
            DrawTagsFilter("##ExcludeTags", ExcludeTagsFilter, 0, MarkChangedCB(this.ExcludeTagsFilterChanged));
        }

        if (includeBeatenFilters) {
            FilterSettings::BeatenByFilter = TrackedInputText("Beaten By", FilterSettings::BeatenByFilter);
        }

        // UI::SameLine();
        // ReverseOrder = UI::Checkbox("Reverse Order", ReverseOrder);
    }

    // for the ReverseOrder option, but not sure I want to do it this way
    // int TransformIx(int ix) {}

    string[]@ authorSParts = {};
    string[]@ mapNameSParts = {};
    string[]@ beatenBySParts = {};

    void OnBeforeUpdate() {
        @authorSParts = FilterSettings::AuthorFilter.ToLower().Replace(" ", "*").Split("*");
        @mapNameSParts = FilterSettings::MapNameFilter.ToLower().Replace(" ", "*").Split("*");
        @beatenBySParts = FilterSettings::BeatenByFilter.ToLower().Replace(" ", "*").Split("*");
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

class ValidationData {
    bool ValidationUploaded;
    string ValidationUrl;

    ValidationData(bool validationUploaded, const string &in validationUrl) {
        ValidationUploaded = validationUploaded;
        ValidationUrl = validationUrl;
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
    string TagsRaw;
    int[] Tags = {};
    string MapType;
    bool IsHidden = false;
    bool AtSetByPlugin = false;
    int64 UploadedTimestamp = 1769868872;
    string Reason = "";
    ReportedData@[] Reported = {};
    string TagNames;
    int ATBeatenTimestamp;
    string ATBeatenUser;
    ValidationData@ Validation = null;

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
        TagsRaw = GetData('Tags', TagsRaw);
        MapType = GetData('MapType', MapType);
        if (HasKey('IsHidden')) IsHidden = GetData('IsHidden', IsHidden);
        if (HasKey('Reason')) Reason = GetData('Reason', Reason);
        if (HasKey('AtSetByPlugin')) AtSetByPlugin = GetData('AtSetByPlugin', AtSetByPlugin);
        if (HasKey('Reported')) Reported = GetReportedData();
        if (HasKey('UploadedTimestamp')) UploadedTimestamp = GetData('UploadedTimestamp', UploadedTimestamp);
        if (HasKey('Validation')) @Validation = GetValidationData();
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

    void LoadValidationGhost() {
        if (Validation is null || Validation.ValidationUrl == "") return;
        LoadGhostFromUrl(TrackID, Validation.ValidationUrl, Validation.ValidationUrl);
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
        auto parts = TagsRaw.Split(",");
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
                Tags.InsertLast(tagId);
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

    ValidationData@ GetValidationData() {
        const auto row = GetData('Validation');
        return ValidationData(row[0], row[1]);
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

    void OnClickEditMapCoro() {
        EditMapNow(MapMonitor::MapUrl(TrackID));
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
        DrawTableEndCols(showHiddenReason: false);

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

        DrawTableEndCols(showHiddenReason: true);

        UI::PopStyleVar();
    }

    void DrawATCol() {
        UI::TableNextColumn();
        DrawATTime();
    }

    void DrawATTime() {
        if (Validation !is null && Validation.ValidationUploaded) {
            if (Validation.ValidationUrl != "") {
                UI::PushStyleColor(UI::Col::Button, vec4(1.0, 1.0, 1.0, 0.1));
                if (UI::Button("\\$0f0" + Time::Format(AuthorTime) + "##" + TrackID)) {
                    startnew(CoroutineFunc(this.LoadValidationGhost));
                }
                AddSimpleTooltip("Load AT ghost (you must open the map in solo)", 700);
                UI::PopStyleColor();
            } else {
                UI::Text("\\$0f0" + Time::Format(AuthorTime));
            }
            DrawValidationGhostWarning(Validation.ValidationUrl);
        } else if (AtSetByPlugin) {
            UI::Text("\\$ff0" + Time::Format(AuthorTime));
            AddSimpleTooltip("This AT was likely set by a plugin. This doesnt mean AT is impossible/cheated.");
        } else {
            UI::Text(Time::Format(AuthorTime));
        }
    }

    void DrawValidationGhostWarning(const string &in url) {
        if (url != "") {
            AddSimpleTooltip("Author uploaded validation replay proving map was actually driven legit.", 700);
        } else {
            AddSimpleTooltip("Author uploaded validation replay proving map was actually driven legit.\nHowever, they decided to not make ghost public.", 700);
        }
        AddSimpleTooltip("\\$fc0PLEASE NOTE, even though replay was validated using real physics engine:\n* physics could've changed since potentially making map impossible\n* drove replay on previous version of the map and blocked every path other then what they drove in validation.\n* run trackmania in slowmotion to validate\nNonetheless, this is the most accurate check we have at this point, superseding metadata based check.", 700);
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

        DrawTableEndCols(showHiddenReason: false);
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
    void DrawTableEndCols(bool showHiddenReason) {
        // player count
        UI::TableNextColumn();
        UI::Text("" + NbPlayers);

        // links
        UI::TableNextColumn();
        DrawLinkButtons();

        if (showHiddenReason) {
            UI::TableNextColumn();
            UI::Text("\\$f60" + Icons::ExclamationTriangle);
            AddSimpleTooltip(Reason);
        }

        UI::TableNextColumn();
        UI::AlignTextToFramePadding();
        if(UI::BeginMenu("More##" + TrackID)) {
            // tmx + tm.io
            if (UI::MenuItem("Open on TM.io##" + TrackID)) {
                OpenBrowserURL("https://trackmania.io/#/leaderboard/"+TrackUID+"?utm_source=unbeaten-ats-plugin");
            }
            if (UI::MenuItem("Open on TMX##" + TrackID)) {
                OpenBrowserURL("https://trackmania.exchange/maps/"+TrackID+"?utm_source=unbeaten-ats-plugin");
            }
            if (UI::MenuItem("Copy TMX id##" + TrackID)) {
                IO::SetClipboard(tostring(TrackID));
            }
            if (UI::MenuItem("Open in editor##" + TrackID)) {
                startnew(CoroutineFunc(OnClickEditMapCoro));
            }
            if (S_API_Choice == UnbeatenATsAPI::Teggots_API) {
                if (UI::MenuItem("Upload Validation Replay##" + TrackID)) {
                    OpenBrowserURL("https://map-monitor.teggot.name/static/upload-replay.html?mapId=" + TrackID);
                }
                UI::BeginDisabled(Validation is null || Validation.ValidationUrl == "");
                if (UI::MenuItem("Copy validation ghost URL##" + TrackID)) {
                    IO::SetClipboard(Validation.ValidationUrl);
                }
                UI::EndDisabled();
            }
            if (g_isUserTrusted) {
                if (UI::MenuItem("Add/Replace Note##" + TrackID)) {
                    OnReportMapClicked(this);
                }
                if (UI::MenuItem("Remove my Note##" + TrackID)) {
                    startnew(CoroutineFunc(RemoveMyCommunityNote));
                }
            }
            UI::EndMenu();
        }

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

dictionary g_loadingGhosts = {};

void LoadGhostFromUrl(const int trackId, const string &in filename, const string &in url) {
    if (g_loadingGhosts.Exists(url)) {
        return;
    }
    Notify("Loading ghost from for " + trackId);
    g_loadingGhosts[url] = true;
    try {
        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        auto dfm = ps.DataFileMgr;
        auto gm = ps.GhostMgr;
        auto task = dfm.Ghost_Download(filename, url);
        WaitAndClearTaskLater(task, dfm);
        if (task.HasFailed || !task.HasSucceeded) {
            NotifyError("Failed to download ghost :shrug:");
            g_loadingGhosts.Delete(url);
            return;
        }
        auto instId = gm.Ghost_Add(task.Ghost, true);
        NotifySuccess("Ghost loaded for " + trackId);
    } catch {
        warn("exception loading a ghost; exception: " + getExceptionInfo());
        NotifyError("Loading ghost failed for " + trackId + ".\nProbably because you are not on the map or on a server.");
    }
    g_loadingGhosts.Delete(url);
}

Json::Value@ g_TmxTags = null;
string[] tagLookup;
TmxTag@[] sortedTagList;

class TmxTag {
    int ID;
    string Name;

    TmxTag(int ID, const string &in Name) {
        this.ID = ID;
        this.Name = Name;
    }
}

void PopulateTmxTags() {
    @g_TmxTags = TMX::GetTmxTags();
    tagLookup.Resize(g_TmxTags.Length + 1);
    for (uint i = 0; i < g_TmxTags.Length; i++) {
        // {Color, ID, Name}
        auto tag = g_TmxTags[i];
        int ix = tag['ID'];
        tagLookup[ix] = tag['Name'];
        sortedTagList.InsertLast(TmxTag(ix, tag['Name']));
    }
    sortedTagList.Sort(_g_compareTmxTags);
}

bool _g_compareTmxTags(const TmxTag@ const &in a, const TmxTag@ const &in b) {
    return a.Name < b.Name;
}
