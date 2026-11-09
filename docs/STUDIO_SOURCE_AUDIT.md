# Egy megtartott Studio: forrásaudit (#282)

A Studio példányát tartsd meg a tesztek között. Az Edit modellbe mindig egyetlen, ismert build forrásai kerüljenek. A különböző verziójú közös munkamappát szolgáló Rojo és a kézi Edit-szinkron együtt duplikátumokat/eltérő kódot hagyhat; a startup szolgáltatásszáma önmagában nem bizonyít megfelelő forrást.

A csak standard libraryt használó `tools/studio_source_audit.py` a Rojo build LuaSourceContainerjeinek osztályát, névútvonalát, UTF8-bájthosszát és djb2-32 hashét hasonlítja egy élő Edit snapshothoz. A manifest és snapshot nem tartalmaz forrásszöveget. A névútvonal szegmenslista, ezért a névben szereplő pont sem keveredik mappahatárral. A hatókör a projekt három gyökere: Shared, Server, Client; a Studio pluginja/CoreScripts és játékos runtime-másolatok kívül maradnak.

```sh
rojo build -o /tmp/pizza-qa.rbxlx
python3 tools/studio_source_audit.py prepare /tmp/pizza-qa.rbxlx \
  --manifest /tmp/pizza-qa-manifest.json --script /tmp/pizza-qa-audit.luau
```

Állítsd le a Playt, válaszd ki a már megnyitott, saját Studio azonosítóját. A generált Luau-t `execute_luau` **Edit** környezetében futtasd; a visszaadott JSON-t mentsd `/tmp/pizza-qa-snapshot.json`-ba. A generátor nem kapcsolódik hálózathoz és nem nyit Studiot. A snippet csak olvas, kötegenként yieldel, nem require-ol játékmodult, nem szinkronizál/töröl/indít/publikál. A felhasználó és más agent közben ne módosítsa a tesztelt forrásokat: egy több lépéses snapshot nem atomi zárolás.

```sh
python3 tools/studio_source_audit.py compare \
  /tmp/pizza-qa-manifest.json /tmp/pizza-qa-snapshot.json
# Gépi, részletes metadata-riport:
python3 tools/studio_source_audit.py compare \
  /tmp/pizza-qa-manifest.json /tmp/pizza-qa-snapshot.json --json
```

Exit0: minden kezelt script egy példányban, megfelelő osztállyal/hosszal/hashsel. Exit1: hiányzó, eltérő vagy extra script/duplikált teljes path. A duplikátum akkor is hiba, ha az első példány forrása helyes; a mappaszintű azonos nevű gyökereket is végigjárja. Exit2: hibás bemenet/fájl/séma. A készülő manifest, snippet és build útvonala eltérő kell legyen, hogy a build ne íródjon felül.

A riport nem javít automatikusan. Előbb azonosítsd a helyes forrást és az esetleges régi Rojo folyamatot; csak jóváhagyott buildet tölts az Edit modellbe a támogatott szinkronnal. Más agent/user folyamatát vagy eltérő, nem saját scriptmásolatot ne törölj az audit nevében. Javítás után új snapshot és compare szükséges. Az audit sikeressége forrásegyezés, nem játék-/UI-/teljesítmény- vagy release-QA.

Az eszköz regressziói:

```sh
python3 -m unittest discover -s tools -p test_studio_source_audit.py -v
```

A #282 valódi próbáján először298egyező/6hiányzó/12eltérő/0extra/0duplikált scriptet talált; az approved build18moduljának Edit-szinkronja után316egyező és minden hibatípus0. Ugyanaz az egy Studio maradt; a szinkron nem módosította a másik agent fájljait.
