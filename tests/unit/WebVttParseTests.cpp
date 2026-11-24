// WebVTT cues written back to back (no blank line between them) used to lose
// every second cue: the next timing line was read and thrown away.
#include "graphicenhancement/engine/Subtitles.h"

#include <filesystem>
#include <fstream>
#include <iostream>

int main() {
    using namespace graphicenhancement::engine;
    const auto path = std::filesystem::temp_directory_path() / "graphicenhancement-webvtt-test.vtt";
    {
        std::ofstream file(path, std::ios::binary | std::ios::trunc);
        file << "WEBVTT\n\n"
                "00:00:01.000 --> 00:00:02.000\nfirst\n"
                "00:00:03.000 --> 00:00:04.000\nsecond\n"
                "00:00:05.000 --> 00:00:06.000\nthird\n";
    }
    const auto track = loadSubtitleFile(path.wstring());
    std::error_code ignored;
    std::filesystem::remove(path, ignored);

    int failures = 0;
    auto check = [&](bool ok, const char* label) {
        failures += !ok;
        std::cout << (ok ? "PASS " : "FAIL ") << label << '\n';
    };
    check(track.cues.size() == 3, "all three back-to-back cues are kept");
    if (track.cues.size() == 3) {
        check(track.cues[0].text == L"first" && track.cues[1].text == L"second" && track.cues[2].text == L"third",
              "cue text stays with its own timing");
        check(track.cues[1].begin > 2.99 && track.cues[1].begin < 3.01, "second cue timing parsed");
    }
    std::cout << "failures=" << failures << '\n';
    return failures ? 1 : 0;
}
