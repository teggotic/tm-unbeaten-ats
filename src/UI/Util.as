namespace UI {
    void FieldName(const string &in label, const int totalSize
) {
        // UI::AlignTextToFramePadding();
        auto cur = UI::GetCursorPos();
        UI::Text(label);
        UI::SameLine();
        if (UI::GetCursorPos().x > cur.x + totalSize) return;
        UI::SetCursorPos(vec2(cur.x + totalSize, cur.y));
    }
}
