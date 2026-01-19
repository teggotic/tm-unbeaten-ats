Json::Value@ FetchLiveEndpoint(const string &in route) {
    NadeoServices::AddAudience("NadeoLiveServices");
    while (!NadeoServices::IsAuthenticated("NadeoLiveServices")) yield();

    trace("[FetchLiveEndpoint] Requesting: " + route);
    auto req = NadeoServices::Get("NadeoLiveServices", route);
    req.Start();
    while(!req.Finished()) { yield(); }
    return Json::Parse(req.String());
}

Json::Value@ FetchClubEndpoint(const string &in route) {
    NadeoServices::AddAudience("NadeoLiveServices");
    while (!NadeoServices::IsAuthenticated("NadeoLiveServices")) yield();

    trace("[FetchLiveEndpoint] Requesting: " + route);
    auto req = NadeoServices::Get("NadeoLiveServices", route);
    req.Start();
    while(!req.Finished()) { yield(); }
    return Json::Parse(req.String());
}

Json::Value@ CallLiveApiPath(const string &in path) {
    AssertGoodPath(path);
    return FetchLiveEndpoint(NadeoServices::BaseURLLive() + path);
}

Json::Value@ CallCompApiPath(const string &in path) {
    AssertGoodPath(path);
    return FetchClubEndpoint(NadeoServices::BaseURLMeet() + path);
}

Json::Value@ CallClubApiPath(const string &in path) {
    AssertGoodPath(path);
    return FetchClubEndpoint(NadeoServices::BaseURLMeet() + path);
}

Json::Value@ CallMapMonitorApiPath(const string &in path) {
    AssertGoodPath(path);
    // auto token = MM_Auth::GetCachedToken();
    auto url = MM_API_ROOT + path;
    trace("[CallMapMonitorApiPath] Requesting: " + url);
    auto req = Net::HttpRequest();
    req.Url = MM_API_ROOT + path;
    req.Headers['User-Agent'] = 'MapInfo/Openplanet-Plugin/contact=@XertroV';
    // req.Headers['Authorization'] = 'openplanet ' + token;
    req.Method = Net::HttpMethod::Get;
    req.Start();
    while(!req.Finished()) { yield(); }
    return Json::Parse(req.String());
}

Json::Value@ AuthMapMonitor(const string &in token) {
    auto url = MM_API_ROOT + "/auth/openplanet";
    trace("[CallMapMonitorApiPath] Requesting: " + url);
    auto req = Net::HttpRequest();
    req.Url = url;
    req.Headers['User-Agent'] = 'MapInfo/Openplanet-Plugin/contact=@XertroV';
    req.Headers['Content-Type'] = 'application/json';
    req.Method = Net::HttpMethod::Post;
    auto body = Json::Object();
    body["token"] = token;
    req.Body = Json::Write(body);
    req.Start();
    while(!req.Finished()) { yield(); }
    return Json::Parse(req.String());
}

Json::Value@ CallMapMonitorApiPathAuthorized(const string &in path, const Net::HttpMethod &in method) {
    AssertGoodPath(path);
    auto url = MM_API_ROOT + path;
    trace("[CallMapMonitorApiPath] Requesting: " + url);
    auto token = MapMonitor::GetAuthToken();
    auto req = Net::HttpRequest();
    req.Url = MM_API_ROOT + path;
    req.Headers['User-Agent'] = 'MapInfo/Openplanet-Plugin/contact=@XertroV';
    req.Headers['Authorization'] = 'Bearer ' + token;
    req.Method = method;
    req.Start();
    while(!req.Finished()) { yield(); }
    return Json::Parse(req.String());
}

// Ensure we aren't calling a bad path
void AssertGoodPath(string &in path) {
    if (path.Length <= 0 || !path.StartsWith("/")) {
        throw("API Paths should start with '/'!");
    }
}

// Length and offset get params helper
const string LengthAndOffset(uint length, uint offset) {
    return "length=" + length + "&offset=" + offset;
}


Net::HttpRequest@ PluginRequest(const string &in url) {
    auto r = Net::HttpRequest();
    r.Url = url;
    r.Headers['User-Agent'] = "TM_Plugin:" + Meta::ExecutingPlugin().Name + " / contact=@XertroV,m@xk.io / client_version=" + Meta::ExecutingPlugin().Version;
    return r;
}

Net::HttpRequest@ PluginPostRequest(const string &in url) {
    auto r = PluginRequest(url);
    r.Method = Net::HttpMethod::Post;
    return r;
}

Net::HttpRequest@ PluginGetRequest(const string &in url) {
    auto r = PluginRequest(url);
    r.Method = Net::HttpMethod::Get;
    return r;
}
