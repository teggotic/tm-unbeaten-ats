namespace UI {
    void AlignItemCenter() {
        UI::SetCursorPos(vec2(UI::GetWindowSize().x / 2, UI::GetCursorPos().y));
    }

    void FieldText(const string &in label, const int totalSize) {
        UI::AlignTextToFramePadding();
        auto cur = UI::GetCursorPos();
        UI::Text(label);
        UI::SetCursorPos(vec2(cur.y + totalSize, cur.y));
    }
}
