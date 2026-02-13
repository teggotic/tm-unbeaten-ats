namespace UI {
    void FieldName(const string &in label, const int totalSize) {
        UI::AlignTextToFramePadding();
        auto cur = UI::GetCursorPos();
        UI::Text(label);
        UI::SetCursorPos(vec2(cur.x + totalSize, cur.y));
    }
}
