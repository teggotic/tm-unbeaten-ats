class ModalWindow {
    string modalId;

    bool isVisible = true;
    vec2 initialSize = vec2(500, 200);

    int windowFlags = UI::WindowFlags::NoSavedSettings | UI::WindowFlags::NoResize | UI::WindowFlags::NoMove;

    ModalWindow(const string &in id) {
        modalId = id;
    }

    void Render() {
        UI::OpenPopup(modalId);

        UI::SetNextWindowSize(int(initialSize.x), int(initialSize.y));
        if (UI::BeginPopupModal(modalId, windowFlags)) {
            Draw();
            UI::EndPopup();
        }
    }

    void Close()
    {
        isVisible = false;
        UI::CloseCurrentPopup();
    }

    bool ShouldClose()
    {
        return !isVisible;
    }

    void Draw() {}
}
