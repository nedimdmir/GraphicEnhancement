#pragma once
#include "graphicenhancement/engine/EngineController.h"
#include "graphicenhancement/engine/PresetLibrary.h"
#include <filesystem>
#include <functional>
#include <string>
#include <vector>

namespace graphicenhancement::ui {
// The interface the user interface talks to.
//
// The QML front end must not hold EngineController, D3D12 objects, decoded
// frames or the audio clock, and it must not poll a 70-field snapshot at a
// fixed rate. This facade:
//   * exposes one snapshot per change, tagged with a counter the UI compares
//     (so a binding updates only what moved);
//   * turns commands into queued actions and never blocks the UI thread;
//   * owns the user-facing services: preset library, recent files, the last
//     capture session.
//
// It is deliberately free of Win32 and Qt so the same code serves both the
// transitional Win32 shell and the QML front end.
class PlayerUiFacade {
public:
    // A snapshot plus the counter the UI uses to skip unchanged data.
    struct Frame {
        graphicenhancement::engine::PlayerSnapshot snapshot;
        uint64_t revision = 0;      // increments whenever `snapshot` changed
        bool changed = false;
    };

    explicit PlayerUiFacade(graphicenhancement::engine::EngineController& engine,
                            std::filesystem::path dataDirectory = {});

    // --- snapshot -----------------------------------------------------------
    // Cheap: compares the engine's snapshot against the last one handed out and
    // only reports a change when something actually differs.
    Frame poll();
    const graphicenhancement::engine::PlayerSnapshot& last() const { return last_; }
    uint64_t revision() const { return revision_; }

    // --- commands ----------------------------------------------------------
    // Applied to the engine's desired settings, keeping the facade's copy in
    // step so the UI can show the pending value before the engine confirms it.
    bool applySettings(const graphicenhancement::engine::EnhancementSettings& settings,
                       std::optional<graphicenhancement::engine::ChainRuntimeOrder> order = std::nullopt);
    graphicenhancement::engine::EnhancementSettings pendingSettings() const { return pending_; }
    void setPending(graphicenhancement::engine::EnhancementSettings settings) {
        settings.content=graphicenhancement::engine::currentContentRate(settings.content);
        pending_ = std::move(settings);
    }
    // True while the engine has not yet applied what the UI asked for.
    bool applying() const;

    // --- presets -----------------------------------------------------------
    graphicenhancement::engine::PresetLibrary& presets() { return presets_; }
    const graphicenhancement::engine::PresetLibrary& presets() const { return presets_; }
    bool applyPreset(size_t index);
    // Saves the settings the UI is currently showing (pending, not applied -
    // the user saves what they see).
    bool savePreset(const graphicenhancement::engine::PresetEntry& entry, bool replace);
    // Loads the preset library (once), then migrates the older single-purpose
    // stores into it, so nobody loses their presets. Never overwrites an
    // existing name.
    bool importLegacyStores();

    // --- recent files ------------------------------------------------------
    struct RecentEntry {
        std::wstring path;
        std::wstring label;
        bool exists = false;
        bool operator==(const RecentEntry&) const = default;
    };
    void noteRecentFile(const std::wstring& path);
    const std::vector<RecentEntry>& recentFiles() const { return recent_; }
    // Drops entries whose file no longer exists (checked lazily, not on every
    // poll: the list is short and the check is a filesystem call).
    void refreshRecentFiles();
    // Persists the empty list, keeping existing entries if saving fails.
    bool clearRecentFiles();

    // --- shell preferences --------------------------------------------------
    // Reduced motion turns off the springs and transitions. Default page is what
    // the app opens on (home / minimal / professional). Both persist here so they
    // survive a restart, and both are preferences rather than enhancement settings:
    // they never affect the picture.
    bool reducedMotion() const { return reducedMotion_; }
    void setReducedMotion(bool value) { reducedMotion_ = value; savePreferences(); }
    const std::wstring& defaultPage() const { return defaultPage_; }
    void setDefaultPage(std::wstring value) { defaultPage_ = std::move(value); savePreferences(); }

    // --- last capture session ----------------------------------------------
    struct CaptureSession {
        std::wstring devicePath;
        std::wstring formatKey;
        std::wstring presetName;
        double fps = 0;
        bool valid = false;
        bool operator==(const CaptureSession&) const = default;
    };
    // Records what the user last captured with, including the preset in use, so
    // the home screen can offer "continue last session" in one click.
    void noteCaptureSession(const CaptureSession& session);
    const CaptureSession& lastCaptureSession() const { return captureSession_; }
    bool hasCaptureSession() const { return captureSession_.valid; }

    // --- persistence -------------------------------------------------------
    bool loadPreferences();
    bool savePreferences();
    bool loadChainSession(graphicenhancement::engine::ChainSession&);
    bool saveChainSession(const graphicenhancement::engine::ChainSession&);
    const std::wstring& error() const { return error_; }

private:
    graphicenhancement::engine::EngineController& engine_;
    graphicenhancement::engine::PresetLibrary presets_;
    bool presetsLoaded_ = false;
    std::filesystem::path dataDirectory_;
    graphicenhancement::engine::ChainSessionStore chainSessionStore_;
    graphicenhancement::engine::PlayerSnapshot last_{};
    graphicenhancement::engine::EnhancementSettings pending_{};
    uint64_t pendingFgRevision_=0;
    uint64_t pendingNrRevision_=0;
    graphicenhancement::engine::NrRuntime requestedNrRuntime_=graphicenhancement::engine::NrRuntime::Ampere;
    graphicenhancement::engine::FrameGenerationBackend requestedFgBackend_=graphicenhancement::engine::FrameGenerationBackend::Dlss;
    uint32_t requestedFgMultiplier_=1;
    uint32_t requestedVfgQuality_=1;
    uint64_t revision_ = 0;
    bool haveLast_ = false;
    std::vector<RecentEntry> recent_;
    CaptureSession captureSession_{};
    bool reducedMotion_ = false;
    std::wstring defaultPage_ = L"home";
    std::wstring error_;
    std::filesystem::path preferencesPath() const;
    bool savePreferencesLocked();
};
}
