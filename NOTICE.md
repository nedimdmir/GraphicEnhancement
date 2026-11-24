# Notice

Graphic Enhancement is a modified version of **Veyra**
(<https://github.com/Likely7/Veyra-NRVideo>), imported at upstream commit
`bc59d457ce0b87141f3db2ebafb0f4812b1cea39` and distributed under the GNU General Public
License, version 3 (see [LICENSE](LICENSE)).

Copyright of the original work remains with the Veyra authors and the contributors and
third parties named in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and
[licenses/](licenses).

## Modifications (2026-11-24)

- Renamed the product, identifiers, files and folders from `Veyra` / `veyra` to
  `GraphicEnhancement` / `graphicenhancement`, and replaced the logo, wordmark and app icon.
  In THIRD_PARTY_NOTICES.md and licenses/, "Veyra" refers to this program's upstream and
  paths such as `include/veyra/...` now live under `include/graphicenhancement/...`.
- Removed upstream promotional material: author social links, donation/sponsor page and
  images, community QR codes, promo videos, trending badges and the author's dated
  development notes and release notes.
- Pointed update, feedback and release links at
  <https://github.com/nedimdmir/GraphicEnhancement>. Automatic updates stay off unless a
  build sets its own `GRAPHICENHANCEMENT_UPDATE_PUBLIC_KEY`.
- Bug fixes and test changes listed in [README.md](README.md#changes-compared-to-upstream).
