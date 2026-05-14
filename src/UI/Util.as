namespace UI {
    void FieldName(const string &in label, const int totalSize
) {
        const int sz = totalSize * UI::GetScale();
        // UI::AlignTextToFramePadding();
        auto cur = UI::GetCursorPos();
        UI::Text(label);
        UI::SameLine();
        if (UI::GetCursorPos().x > cur.x + totalSize) return;
        UI::SetCursorPos(vec2(cur.x + totalSize, cur.y));
    }

    array<Field@> g_fieldStack = {};

    class Field {
        vec2 Start;
        int TotalSize;
        Field (vec2 start, int totalSize) {
            Start = start;
            TotalSize = totalSize;
        }
    }

    void BeginField(const int totalSize) {
        const int sz = totalSize;
        auto cur = UI::GetCursorPos();
        g_fieldStack.InsertLast(Field(cur, sz));
    }

    void EndField() {
        auto f = g_fieldStack[g_fieldStack.Length - 1];
        auto cur = f.Start;
        auto totalSize = f.TotalSize;
        g_fieldStack.RemoveLast();
        UI::SameLine();
        if (UI::GetCursorPos().x > cur.x + totalSize) return;
        UI::SetCursorPos(vec2(cur.x + totalSize, cur.y));
    }

    array<vec2> g_measureStack = {};

    void MeasureStart() {
        g_measureStack.InsertLast(UI::GetCursorPos());
    }

    vec2 MeasureEnd(const string &in label = "") {
        auto m = g_measureStack[g_measureStack.Length - 1];
        auto now = UI::GetCursorPos();
        g_measureStack.RemoveLast();
        auto res = now - m;
        // trace(label + " " + tostring(now) + " - " + tostring(m) + " = " + tostring(res));
        return res;
    }

    vec2 MeasureEndNewLine(const string &in label = "") {
        UI::SameLine();
        auto ret = MeasureEnd(label);
        UI::NewLine();
        return ret;
    }
}
