# Unity Android Build Support op de school-iMacs

Op de iMacs kun je in Unity Hub geen **Android Build Support** toevoegen, omdat je daarvoor admin-rechten nodig hebt. Dit script lost dat op zonder admin:

1. Het kopieert de Unity Editor uit `/Applications/Unity/Unity.app` (nu `6000.0.77f1`) naar je eigen map: `~/UnityEditors/6000.0.77f1`. De versie leest het script zelf uit.
2. Het downloadt Android Build Support, de Android SDK & NDK en OpenJDK rechtstreeks bij Unity en Google, en installeert ze in die kopie. Unity Hub kan dat zelf niet, omdat de editor niet via de Hub is geïnstalleerd.
3. Het stelt Unity Hub zo in dat de Hub de kopie vindt.

## Snel starten (één commando)

1. Sla eerst je werk op en sluit Unity en Unity Hub.
2. Open **Terminal**: druk op `Cmd + Spatie`, typ `Terminal` en druk op Enter.
3. Plak dit commando en druk op Enter:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/loos-glr/unity-android-build-imac-fix/main/fix_unity_android.command)"
```

4. Wacht tot je **`=== Klaar! ===`** ziet. Dat duurt meestal 10 tot 30 minuten, afhankelijk van het netwerk. Laat het Terminal-venster openstaan en zet de iMac niet in slaapstand.
5. Open Unity Hub. Onder **Installs** staat nu `6000.0.77f1` met Android. Staat hij er niet? Klik dan op **Locate** en kies `~/UnityEditors/6000.0.77f1/Unity.app`.
6. Open je project in Unity en ga naar **File → Build Profiles → Android → Switch Platform**.

Je hoeft dit maar één keer per account te doen. Als je het opnieuw draait, slaat het script het kopiëren over.

## Andere Unity-versie

Het script gebruikt standaard de Unity in `/Applications/Unity/Unity.app`. Staat er ook een versie in `/Applications/Unity/Hub/Editor` die je wilt gebruiken? Zet die versie achter het commando:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/loos-glr/unity-android-build-imac-fix/main/fix_unity_android.command)" _ 6000.0.77f1
```

Staat de versie er niet? Dan laat het script zien welke versies wel beschikbaar zijn.

## Alternatief: script downloaden

Download [`fix_unity_android.command`](fix_unity_android.command) en dubbelklik erop. Krijg je de melding dat het bestand niet geopend kan worden? Kies dan **rechtermuisklik → Open**. Als dat niet werkt, gebruik het commando hierboven.

## Problemen

| Melding | Oplossing |
|---|---|
| `Kan Unity ... niet vinden` | Deze versie staat niet op deze iMac. Kies een versie uit de lijst die het script toont. |
| `Te weinig schijfruimte` | Je hebt ongeveer 20 GB vrij nodig in je thuismap. Verwijder oude projecten of builds. |
| `Installeren van ... mislukt` of `Android onderdelen ontbreken` | Een download is mislukt, bijvoorbeeld door het netwerk. Draai het commando opnieuw; het script gaat verder waar het gebleven was. |
| `Kan de module-lijst niet ophalen` | Geen verbinding met Unity. Controleer of je internet hebt en probeer het opnieuw. |
| Editor staat niet in Unity Hub | Kies in Unity Hub **Installs → Locate** en selecteer `~/UnityEditors/<versie>/Unity.app`. |

Alles weer verwijderen: verwijder de map `~/UnityEditors`. Daar staan ook de tijdelijke downloads, in `~/UnityEditors/.downloads`.

## Voor docenten / beheer

- Het script heeft geen admin-rechten nodig en verandert niets in `/Applications`.
- Elke student krijgt een eigen kopie van de editor, inclusief Android, van ongeveer 20 GB. Houd daar rekening mee bij quota op thuismappen.
- Het script gebruikt de Unity Hub niet voor de installatie. Het haalt de module-lijst op via Unity's release-API (`services.api.unity.com`), dezelfde gegevens die de Hub gebruikt. Daarna downloadt het elk onderdeel (pkg, zip of dmg) en pakt het uit in `PlaybackEngines/AndroidPlayer`. Dat gebeurt zonder admin en met alleen standaard macOS-tools, dus geen Python of Xcode nodig.
- Per geïnstalleerd onderdeel komt er een markering in `~/UnityEditors/<versie>/.android-modules`. Wordt het script opnieuw gedraaid, dan slaat het die onderdelen over.
- Het script zet de installatiemap van Unity Hub voor die gebruiker op `~/UnityEditors`, zodat de editor in de Hub verschijnt.
- Het script kopieert `/Applications/Unity/Unity.app` en de mappen ernaast (behalve `Hub`). Het leest de versie uit de `Info.plist` van de app. Wordt Unity bijgewerkt, dan pakt het script de nieuwe versie vanzelf.
