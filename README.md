# Unity Android Build Support op de school-iMacs

Op de iMacs kun je in Unity Hub geen **Android Build Support** toevoegen, omdat je daarvoor admin-rechten nodig hebt. Dit script lost dat op zonder admin:

1. Het kopieert de Unity Editor uit `/Applications/Unity/Unity.app` (nu `6000.0.77f1`) naar je eigen map: `~/UnityEditors/6000.0.77f1`. De versie leest het script zelf uit.
2. Het stelt Unity Hub zo in dat de Hub die kopie gebruikt.
3. Het installeert Android Build Support, de Android SDK & NDK en OpenJDK in die kopie.

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
| `Te weinig schijfruimte` | Je hebt ongeveer 15 GB vrij nodig in je thuismap. Verwijder oude projecten of builds. |
| `Android onderdelen ontbreken` | De download is mislukt, bijvoorbeeld door het netwerk. Draai het commando opnieuw. |
| Editor staat niet in Unity Hub | Kies in Unity Hub **Installs → Locate** en selecteer `~/UnityEditors/<versie>/Unity.app`. |

Alles weer verwijderen: verwijder de map `~/UnityEditors`.

## Voor docenten / beheer

- Het script heeft geen admin-rechten nodig en verandert niets in `/Applications`.
- Elke student krijgt een eigen kopie van de editor, inclusief Android, van ongeveer 10 tot 15 GB. Houd daar rekening mee bij quota op thuismappen.
- Het script zet de installatiemap van Unity Hub voor die gebruiker op `~/UnityEditors`.
- Het script kopieert `/Applications/Unity/Unity.app` en de mappen ernaast (behalve `Hub`). Het leest de versie uit de `Info.plist` van de app. Wordt Unity bijgewerkt, dan pakt het script de nieuwe versie vanzelf.
