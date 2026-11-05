# Magyar és angol felület

A saját UI-k angol forrásszövegeihez a `Config/Strings.hu` magyar szótár tartozik. A `Util/Localize` tiszta, determinisztikus megjelenítési réteg: az adatokat/odds számokat/RemoteEvent kulcsokat nem írja át. Ismeretlen nyelv és ismeretlen szöveg esetén az angol forrás marad.

A `LocalizationController` a RobloxLocaleId alapján automatikusan választ nyelvet. Csak a Codex ScreenGui-kat figyeli, a TextBox felhasználó által beírt tartalmát nem fordítja, csak a placeholdert. Forrásszöveget tárol, ezért frissülő számlálók és nyelvváltás után is visszafordítható. A profil megtekintési sorában a felhasználónevet megőrzi.

Studio Client QA: `game.Players.LocalPlayer.PlayerGui:SetAttribute("UILocaleOverride", "hu")`; angolhoz `"en"`, fióknyelvhez `nil`. Ez csak helyi megjelenítési override, nincs jutalom- vagy szerveradat-hatása.

Claude HUD/Event/Order szövegei a fájltulajdonlás miatt változatlanok. Bekötési API: `require(Shared.Util.Localize).new(require(Shared.Config.Strings))(englishSource, locale)`. Új feliratnál a teljes angol mondatot és magyar fordítását a szótárba kell felvenni; a számokat tartalmazó mondatoknál külön sablonfordítás ajánlott. A generic szócsere fallback nem helyettesít szerkesztett lokalizációt.
