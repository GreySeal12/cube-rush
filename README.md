# Cube Rush

Jeu d'arcade 3D low-poly pour mobile : un cube kawaii avance tout seul sur des
plateformes en zigzag, **un tap change sa direction**. Il faut rester sur le
chemin jusqu'à la couronne dorée. 10 niveaux, 4 mondes, 100 % hors ligne.

- Moteur : **Godot 4.7.2** (GDScript uniquement), renderer **Mobile**
- Cible : **Android** (arm64-v8a, minSdk 24), portrait uniquement
- Aucun asset externe : tout est construit avec des primitives (BoxMesh,
  CylinderMesh, SphereMesh) et des couleurs unies
- Aucune requête réseau, aucune permission Android, aucun SDK tiers

---

## 1. Prérequis

| Outil | Version | Pour quoi faire |
|---|---|---|
| [Godot](https://godotengine.org/download) | 4.7.2 stable (version « standard », pas .NET) | Éditer et lancer le jeu |
| Modèles d'export Godot (*export templates*) | exactement la même version que l'éditeur (4.7.2) | Exporter l'APK |
| JDK (OpenJDK) | 17 ou plus récent (testé avec 21) | Signature de l'APK |
| Android SDK | *platform-tools* + *build-tools* (et *cmdline-tools*) | `adb`, `apksigner` |

Installer les modèles d'export : dans Godot, **Éditeur > Gérer les modèles
d'export… > Télécharger et installer**.

Installer l'Android SDK : le plus simple est d'installer
[Android Studio](https://developer.android.com/studio) puis, dans *SDK Manager*,
de cocher *Android SDK Platform-Tools*, *Android SDK Build-Tools* et
*Android SDK Command-line Tools*.

Indiquer les chemins à Godot : **Éditeur > Paramètres de l'éditeur > Export >
Android** :
- *Java SDK Path* : dossier du JDK (ex. `C:\Program Files\Eclipse Adoptium\jdk-21`
  ou `/usr/lib/jvm/java-21-openjdk-amd64`)
- *Android SDK Path* : dossier du SDK (ex. `%LOCALAPPDATA%\Android\Sdk` ou `~/Android/Sdk`)

Godot crée automatiquement un keystore de debug au premier lancement de l'éditeur.

## 2. Lancer le jeu sur PC

1. Ouvrir Godot, **Importer**, choisir le fichier `project.godot` de ce dossier.
2. Appuyer sur **F5** (ou le bouton ▶).

En ligne de commande :

```bash
godot --path .
```

Commandes sur PC : **clic gauche** ou **Espace** = tap. Le premier tap fait
démarrer le cube, les suivants le font tourner. **Échap/retour** n'est pas
utilisé sur PC ; le bouton pause est en haut à droite.

## 3. Valider les niveaux (garantie de jouabilité)

Le script de validation génère chaque niveau à partir de `data/levels.json`,
vérifie qu'il est **déterministe** (même seed ⇒ même niveau), contrôle des
règles simples (fenêtre de virage, écart entre deux virages, hauteur et durée
des sauts) puis **simule une partie complète avec le vrai moteur du cube** :
un « bot » qui tape au centre de chaque virage, puis 0,06 s trop tôt, trop tard
et au hasard. Chaque niveau doit être réussi dans tous les cas.

```bash
./tools/validate.sh            # Linux / macOS (godot dans le PATH)
./tools/validate.sh /chemin/vers/godot
```

Ou directement (Windows inclus) :

```bash
godot --headless --path . --import
godot --headless --path . --script res://tools/validate_levels.gd
```

La première commande n'est utile qu'une fois après un clone (elle crée le
cache des classes). Code de sortie : 0 si tout est jouable, 1 sinon.

Exemple de sortie :

```
Niv | Vitesse | Larg. | Virages | Fenêtre | Durée  | Détails
  1 |     3.5 |     3 |       6 |  0.86 s |  17.5 s | OK
  ...
 10 |     5.8 |     3 |      17 |  0.52 s |  22.3 s | OK  gaps=4, max_gap=3, crumble=34, ...
RÉSULTAT : tous les niveaux sont jouables.
```

Si un niveau échoue après une modification, **corrigez la configuration ou le
générateur**, pas le validateur.

## 4. Générer un APK de debug

### Depuis l'éditeur

1. **Projet > Exporter…** : le preset **Android** est déjà configuré
   (`export_presets.cfg`).
2. S'il affiche une erreur en rouge, c'est presque toujours un chemin
   (JDK / SDK) manquant dans les paramètres de l'éditeur, ou des modèles
   d'export absents.
3. Cliquer **Exporter le projet…**, choisir `build/cube-rush-debug.apk`,
   **cocher « Exporter avec débogage »**, valider.

### En ligne de commande

```bash
mkdir -p build
godot --headless --path . --export-debug "Android" build/cube-rush-debug.apk
```

## 5. Installer sur un téléphone via USB

1. Sur le téléphone : **Paramètres > À propos du téléphone**, taper 7 fois sur
   **Numéro de build** pour activer les *Options pour les développeurs*.
2. Dans **Options pour les développeurs**, activer **Débogage USB**.
3. Brancher le téléphone, accepter l'autorisation de débogage qui s'affiche.
4. Vérifier qu'il est détecté puis installer :

```bash
adb devices
```

```bash
adb install -r build/cube-rush-debug.apk
```

(`adb` se trouve dans `platform-tools` du SDK Android.)

Alternative : avec le téléphone branché, l'icône Android apparaît en haut à
droite de l'éditeur Godot (*déploiement en un clic*). Remarque : ce mode de
déploiement utilise le débogage à distance, ce qui peut ajouter des
autorisations réseau à l'APK de test ; l'APK exporté comme ci-dessus n'en a aucune.

## 6. APK de release (signé)

Créer une fois pour toutes un keystore (à conserver précieusement, hors du dépôt) :

```bash
keytool -genkeypair -v -keystore cuberush-release.keystore -alias cuberush -keyalg RSA -keysize 2048 -validity 10000
```

Puis renseigner le keystore dans **Projet > Exporter > Android > Keystore >
Release**, ou passer par des variables d'environnement (rien n'est écrit dans
le projet) :

```bash
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/chemin/cuberush-release.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=cuberush
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=motdepasse
godot --headless --path . --export-release "Android" build/cube-rush-release.apk
```

Pour le Play Store, il faudra plutôt un fichier `.aab` (activer *Use Gradle
Build* et *Export Format = AAB* dans le preset, ce qui demande d'installer le
modèle de build Android : **Projet > Installer le modèle de build Android**).

### Changer le nom du package

Dans **Projet > Exporter > Android > Package > Unique Name** (ou la ligne
`package/unique_name` de `export_presets.cfg`) : remplacer
`com.exemple.cuberush` par votre identifiant (ex. `com.monstudio.cuberush`).

## 7. Structure du projet

```
project.godot            Paramètres (portrait, renderer Mobile, autoloads)
export_presets.cfg       Preset d'export Android
data/levels.json         LES 10 NIVEAUX + les 4 palettes de couleurs
scenes/
  main_menu.tscn         Menu principal
  level_select.tscn      Grille des niveaux
  game.tscn              Scène de jeu (caméra, lumière, fond, HUD…)
  ui/hud.tscn            « Niveau N », chutes, bouton pause
  ui/pause_menu.tscn     Reprendre / Recommencer / Menu
  ui/level_complete.tscn « NIVEAU TERMINÉ ! », étoiles, Suivant
scripts/
  game_manager.gd        Autoload : changements d'écran, règle des étoiles
  save_manager.gd        Autoload : sauvegarde (user://save.cfg)
  player/player_motor.gd Mouvement du cube (logique pure, déterministe)
  player/player.gd       Affichage et animations du cube
  level/level_generator.gd  Génération du niveau depuis la config
  level/level_data.gd       Niveau généré (requêtes « sol ? piège ? »)
  level/level_validator.gd  Contrôles + simulation du bot
  level/level_database.gd   Lecture de data/levels.json
  platforms/platform_base.gd     Classe de base commune
  platforms/static_platform.gd   Sol fixe
  platforms/jump_pad.gd          Tremplin (avant un trou)
  platforms/crumble_platform.gd  Sol qui s'effondre après le passage
  platforms/moving_platform.gd   Pont en va-et-vient
  platforms/retracting_platform.gd  Plateforme qui se rétracte
  platforms/rotating_platform.gd    Panneau qui pivote
  platforms/pillar_trap.gd       Pilier (obstacle)
  platforms/spike_trap.gd        Pointes fixes ou périodiques
  game/                  Scène de jeu, caméra, couronne, fabrique de maillages
  ui/                    Écrans, style, étoiles et icônes dessinées en code
tools/
  validate_levels.gd     Validation en ligne de commande
  validate.sh            Raccourci (import + validation)
```

### Comment ça marche (en bref)

- **Mouvement déterministe** : le cube avance à vitesse constante vers +X ou
  -Z, simulé par pas fixes de 1/120 s (`PlayerMotor`). Pas de moteur physique.
- **Le temps d'arrivée ne dépend que de la position** : comme le cube va
  toujours soit vers +X soit vers -Z, la quantité `x - z` augmente exactement
  de `vitesse` par seconde, quels que soient les virages. Le générateur s'en
  sert pour synchroniser plateformes mobiles, intermittentes et pointes :
  elles sont « sûres » quand un joueur bien centré passe, avec une marge
  `timing_margin`. Un joueur décalé (virage trop tôt / trop tard) arrive en
  avance ou en retard… et peut tomber.
- **Logique séparée de l'affichage** : chaque plateforme répond à
  « est-ce que je porte le cube au temps t ? » et « est-ce que je le tue ? ».
  Le jeu et le validateur utilisent exactement le même code.

## 8. Régler la difficulté

Tout se règle dans **`data/levels.json`**, sans toucher au code. Après chaque
modification, relancez la validation.

| Champ | Effet |
|---|---|
| `seed` | Graine du hasard. Changez-la pour obtenir un autre tracé avec les mêmes réglages. |
| `speed` | Vitesse du cube (cases/s). +0,2 se sent nettement. |
| `width` | Largeur du chemin en cases (2 = serré, 3 = confortable ; les piliers et pointes latérales demandent 3). |
| `path_length` | Longueur du parcours (en cases). Durée ≈ `path_length / speed`. |
| `segment_min` / `segment_max` | Longueur des lignes droites entre deux virages. Petit = virages serrés et fréquents. |
| `timing_margin` | Tolérance (s) des éléments synchronisés. Plus petit = il faut être plus précis dans ses virages. |
| `gaps` | Trous avec tremplin : `chance` (part des segments), `min`/`max` (taille du trou en cases). |
| `crumble` | Sol fragile : `chance` (part des segments), `delay` (s avant effondrement). |
| `moving` | Ponts mobiles : `chance`, `length` (cases), `away_time` (s écarté), `travel_time` (s de trajet). |
| `intermittent` | Plateformes qui se rétractent / pivotent : `chance`, `rows_min`/`rows_max`, `hidden_time`, `types` (`"retract"`, `"rotate"`). |
| `pillars` | Piliers sur les côtés : `chance` par rangée. |
| `spikes` | `row_chance` (rangées de pointes périodiques, part des segments), `static_chance` (pointes fixes sur les côtés, par rangée), `up_time` (s sorties). |
| `stars_max_deaths` | `[a, b]` : 3 étoiles si chutes ≤ a, 2 étoiles si chutes ≤ b, sinon 1. |
| `theme` | `ciel`, `neon`, `foret` ou `volcan` (palettes dans `themes`). |

La somme des `chance` des particularités (`gaps`, `moving`, `intermittent`,
`spikes.row_chance`) doit rester inférieure à 1 (un segment n'a qu'une
particularité).

**Règle des étoiles** : le temps de parcours est toujours le même (vitesse
constante), on compte donc les **chutes** avant de réussir le niveau.
Voir `GameManager.compute_stars()`.

Autres réglages, dans le code (constantes en haut des fichiers) :

| Où | Quoi |
|---|---|
| `PlayerMotor.GRAVITY` | Gravité (hauteur des sauts et vitesse de chute). |
| `PlayerMotor.HAZARD_HALF` | Taille de la « boîte de collision » contre les pièges (plus petit = plus indulgent). |
| `CameraFollow.view_width` | Zoom de la caméra (largeur visible en cases). |
| `game.gd : RESTART_DELAY` | Durée de l'animation de chute avant redémarrage. |
| `LevelValidator.*` | Exigences du validateur (fenêtre de virage minimale, imprécision simulée…). |

### Ajouter un niveau

Copier un bloc de `levels` dans `data/levels.json`, changer `id`, `name` et
`seed`, ajuster les valeurs puis lancer la validation. La grille de sélection
et le déblocage s'adaptent automatiquement au nombre de niveaux.

## 9. Performances mobiles

- Renderer **Mobile** (Vulkan) avec repli automatique sur OpenGL ES 3 si
  Vulkan est absent (`rendering_device/fallback_to_opengl3`).
- Une seule lumière directionnelle, **aucune ombre dynamique**, pas de
  post-traitement, éclairage calculé par sommet, maillages et matériaux partagés.
- Les rangées de sol consécutives sont fusionnées en un seul bloc
  (≈ 15 à 110 maillages par niveau) ; seuls les éléments animés proches du
  cube sont mis à jour.
- Anti-aliasing MSAA 2× (`anti_aliasing/quality/msaa_3d`) : passez-le à
  « Disabled » si un téléphone peine.
- Si le renderer Mobile pose problème sur un appareil, passez en
  **Compatibility** : **Projet > Paramètres > Rendu > Renderer > Rendering
  Method (Mobile) = gl_compatibility**.

## 10. Ce qui a été vérifié, et ce qui ne l'a pas été

Vérifié dans l'environnement de développement (Linux, sans téléphone) :
- Import du projet et exécution sans erreur avec Godot 4.7.2.
- Validation des 10 niveaux (déterminisme + simulations du bot) : OK.
- Rendu du jeu, des menus et des 4 thèmes avec le renderer Mobile (Vulkan
  logiciel), sur des écrans 720×1280 et 720×1560.
- Parties complètes jouées automatiquement, chutes et redémarrages.
- Export d'un APK de debug et d'un APK de release signés (arm64-v8a) ;
  manifeste contrôlé : minSdk 24, portrait, **aucune permission**.

**Non testé** : l'installation et le jeu sur un vrai téléphone Android
(aucun appareil ni émulateur disponible), donc ni les 60 FPS réels, ni le
ressenti tactile, ni l'affichage autour des encoches. À faire en priorité lors
du premier essai sur appareil.

## 11. Évolutions prévues (hors périmètre de cette version)

L'architecture laisse la place pour : skins (le cube est construit dans
`player.gd`), sons et musique (`game.gd : _on_step_events()` et les
événements `just_jumped` / `just_landed` de `PlayerMotor`), nouveaux mondes
(ajouter une palette dans `themes`), iOS (aucun code spécifique Android hormis
le bouton retour, ignoré ailleurs).
