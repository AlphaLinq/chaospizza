# Pizzériadekorációk (#142)

A Kozmetika lista első „Pizzéria dekorálása” gombja nyitja az elhelyezőt. Négy fix hely választható: zászló, növény, neontábla, asztal. Mindegyikhez van ingyenes alapdarab és tipses változat. Az előnézet önmagában nem vásárol és nem helyez el; a fizetős darabot előbb megveszed, majd külön elhelyezed. A hely kiürítése megtartja a tulajdont. A díszek másoknak is látszanak, játékmeneti tulajdonságot nem adnak.

## Adat és jogosultság

A saját Config/Decorations katalógus a meglévő `profile.cosmetics.owned[id]` tulajdont és `cosmetics.equipped.decor_<slot>` elhelyezést használja. A v7 séma változtatás nélkül megőrzi ezeket. A ruházat `decor` és egyéb slotjai külön maradnak. Egy vétel egy tartós PlayerTransaction/DataService transaction: új tulajdon és levonás együtt, már meglevő darabra nincs második levonás. A kliens árat, pozíciót, tulajdonost vagy jutalmat nem küldhet.

A meglévő RequestPurchase csatorna új `decor:` namespace-e:
- `decor:buy.PlotFlagCheese`
- `decor:place.flag.PlotFlagCheese`
- `decor:clear.flag`

Szigorú katalógus-/hely-/tulajdon-/egyenleg-validálás, saját2/s burst4 korlát, pontos válaszkulcs és8s kliens-timeout. A DTO a Player.DecorationsState attribútumon csak a whitelistes tulajdont, kiválasztott helyeket, tips-egyenleget és ready állapotot publikálja. A szerver minden kérésnél újra ellenőriz. Elhelyezés csak a hívó saját pizzériáján történik; nincs UserId vagy CFrame paraméter.

## Modelladapter

A saját DecorMounts az `OwnerUserId`-vel azonosított PizzaMap-modell szemantikus `PizzeriaCounter` pontját használja. Négy, Configban megadott relatív offsethez DecorSlot attribútumos Attachmentet tesz. Ha már van szerveresen authorolt, megfelelő DecorSlot csatoló, azt használja. Claude PizzeriaService/MapLayout forrása érintetlen.

A szerver saját PlacedDecorations mappát rajzol. Minden part anchored, CanCollide/CanTouch/CanQuery/CastShadow=false; nincs Seat, prompt, fényforrás vagy fizikai hatás. Négy felszerelt alapdarab17part, konfigurált plafon24. Nincs animációs vagy minden-frame szervermunka. Újrarajzolás csak felszerelés-/csatolóváltozás vagy épület-újraépítés után; a korábbi saját mappa törlődik. A ViewportFrame ugyanazt a primitív-leírást használja az előnézethez.

## Publikus ellenőrzési pontok

`DecorationService.apply(player, action)` és `refresh(player)` a szolgáltatói API-k. A `decor [state|buy <id>|place <slot> <id>|clear <slot>]` DEV-parancs ugyanazt a mutációt használja. Példa:

```text
decor state
decor place flag PlotFlagClassic
tips 2000
decor buy PlotFlagCheese
decor place flag PlotFlagCheese
decor clear flag
pizzeria 6
pizzeria 1
```

A helyi UI a meglévő Cosmetics overlay része, annak a11y/gamepad rendszerével. A PizzaDecorationEditor PlayerGui attribútum true/nil a résznézetet nyitja/zárja; a DecorationPreview whitelistes item-ID-val csak előnézetet választ. Ezek nem szerveres játékmeneti szándékok és nem írnak profilt. Back/bezárás visszaállítja az eredeti panelrészeket és törli az előnézet modelljét; a régi Kozmetika render nem törli a TextButton belépőt.

## QA és korlátok

231 Luau teszt, formatter/lint/Rojo,0saját LSP-hiba. Studio62service/54controller:4csatoló/4modell/17part, minden ütközési tulajdonság megfelelő, az eredeti pult továbbra ütközik. Ingyenes elhelyezés, unowned elutasítás,2025→1775tips egyszeri250-es vétel, dupla vétel elutasítása, helycsere/törlés és6→1újraépítés után visszaálló dekorok ellenőrzöttek. A profile debugban az owned és decor_* ledger szerepel.

A HU/nagy betű/360px nézet TextBounds-ellenőrzése tiszta, a visszalépés az eredeti Items/Categories/Preview elemeket visszaadja. Három újranyitás után1belépő és1előnézetmodell marad. A fizetős előnézet nem változtatta a szerverállapotot. A screenshot-eszköz elakadt, a külső képernyőkép-hozzáférés sincs engedélyezve; képi jóváhagyás nem történt. Nem igazolt: natív érintés/egér/gamepad request-kör, többklienses megjelenítés, tényleges DataStore-reconnect és a díszek végső képi elrendezése minden épületszinten. Manuális próba ezekre szükséges. A Studio memória-mockot használt.
