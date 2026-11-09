# Magyar és angol felületszövegek

A saját LocalizationController a Config/Localization képernyőlistáján dolgozik. A korábbi tíz saját menü mellett a FeatureTips és WhatsNew is ide tartozik (#289). A nyelv alapból a RobloxLocaleId: hu kezdetű locale magyar, más angol fallback. Fejlesztői próbához PlayerGui.UILocaleOverride használható; törlése visszaadja a fiók beállítását.

A Config/Strings az angol forráshoz rendeli a magyar szöveget. A dekorációk külön listája csak ismert ikon + szóköz + pontos szótári mondat esetén ad külön prefixfordítást. Így például a `🍕 Pick your order!` felirat végi felkiáltójel mellett is fordul, az ikon és a szóközök megmaradnak. Az angol mód mindig az eredeti producer-szöveget adja. Az új megoldás nem ad általános ikonfelismerést vagy felhasználónév-fordítást.

A tiszta Util/LocalizedText külön tárolja a producer forrását és az utoljára kirajzolt szöveget. A saját Text-írás után később érkező property signal így nem teszi a magyar szöveget angol forrássá. Nyelvváltáskor az esetleges még feldolgozatlan producer-írást is megőrzi. A vezérlő csak eltérő szöveget ír vissza, nem pollol; destroy szétkapcsolja a property/destroy/locale/descendant figyelőket és visszaadja a producer-szöveget.

TextLabel és TextButton esetén Text, TextBox esetén kizárólag PlaceholderText fordul. A beírt Text érintetlen. A listán kívüli ScreenGui és a Roblox CoreGui nem célpont. A többi Claude HUD fordítását ez a feladat nem állítja teljesnek; a két új panel a meglévő felületét használja, controllerük és a szerveres flow változatlan.

## #289 Ellenőrzés

A tiszta regresszió mind a9FeatureTip és7WhatsNew sor/cím/gomb fedését, ikon/szóköz/punctuation/fallback eseteket, késleltetett saját signal és gyors producer-/nyelvváltás állapotát ellenőrzi. A teljes projekt279Luau és11Python tesztje sikeres az integrált ágon.

Ugyanazon megtartott Studio,76service/67controller: valódi whatsnew és micro cart here API, illetve a szerver által küldött Vote-tipp. A magyar szöveg megjelent, az EN/HU váltás eredeti szövegre visszaállt. Két korlátozott felületellenőrzési körben desktop és324fizikai px-re szűkített panel szerepelt; ez méret-fixture, nem telefon-emuláció.

A rövidebb magyar újdonságok címe/sorai és a megfigyelt tipp minden TextFits értéke true, TextBounds a kereten belül. A324px panelben a title270.5×24a292×34keretben, a hét sor legfeljebb292×16a292×28keretben; a tipp törzse145×60a204×82keretben. Rejtett, ideiglenes UI-fixture: producer Got it→Értem, új Let's go!→Gyerünk!, EN→Let's go!, gyors producer/locale írás→Értem. A TextBox beírt Got it szövege megmaradt, csak placeholder változott; nem kezelt ScreenGui szövege változatlan. Mindhárom fixture törölve.

Az eredeti angol újdonságpanel324px méreten az öt hosszú sorát elvágja (Line1/2/3/4/6 TextFits=false). A fix380px authored panel nem is követ egy keskenyebb viewportot. Ez a Claude-tulajdonú [#290 layout-hiba](https://github.com/AlphaLinq/chaospizza/issues/290); az angol forrást nem rövidítettem vagy írtam felül. TextBounds önmagában nem bizonyít teljes olvashatóságot, TextFits is kell.

A képernyőfelvételi hozzáférés false, screenshot nem készült; nincs képi jóváhagyás. Fizikai mobil/gamepad, tényleges magyar Roblox-fiók és natív gombkattintás nem ellenőrzött. A Studio-próba UILocaleOverride-ot használt. Megmaradt az ismert #274 debugnév-ütközés és régi asset-type üzenet; saját új runtimehiba nem volt.
