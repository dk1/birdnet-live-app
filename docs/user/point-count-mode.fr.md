# Mode Point d'écoute

Le mode Point d'écoute est le flux de travail stationnaire et minuté de BirdNET Live.

## Comment l'ouvrir

Depuis l'accueil, appuyez sur la carte **Mode Point d'écoute** avec l'icône :material-map-marker:.

## Flux de configuration

La configuration du point d'écoute comporte quatre étapes.

### 1. Durée et localisation

Choisissez :

- l'une des durées proposées
- la position GPS actuelle avec :material-crosshairs-gps:
- des coordonnées manuelles avec :material-map-marker-plus:
- aucune localisation avec :material-map-marker-off:
- le sélecteur de carte avec :material-map:

L'écran de configuration actualise le GPS lorsque vous revenez de la boîte de
dialogue d'autorisation du système ou des paramètres de l'application : une
autorisation de localisation nouvellement accordée met donc à jour les
coordonnées sans avoir à relancer l'assistant. Cette même section comporte aussi
une carte météo. Si l'accès à la météo est désactivé, la carte demande le
consentement **Autoriser la recherche météo** ; une fois activée, elle donne un
aperçu du site avec une icône météo, la température et le vent uniquement. Le
même instantané Open-Meteo mis en cache est réutilisé lors de l'enregistrement
du point d'écoute.

### 2. Paramètres d'inférence

Choisissez les réglages d'analyse propres à la session, comme la durée de la
fenêtre, la fréquence d'inférence, le seuil de confiance et le mode de filtre
d'espèces. Ils partent de vos paramètres globaux, mais peuvent être ajustés pour
ce comptage sans modifier vos valeurs par défaut.

### 3. Conseils de terrain

Cet écran présente une courte liste de vérification dans l'application à parcourir avant de commencer.

### 4. Prêt

L'écran prêt récapitule la durée sélectionnée et vous permet de démarrer avec :material-play:.

## Écran du point d'écoute en direct

L'écran du point d'écoute en direct se concentre sur un tableau de bord minuté.

### Barre supérieure

- :material-stop: — arrêter le point d'écoute prématurément
- :material-timer: — afficher le temps restant
- :material-tune: — ouvrir les paramètres du Point d'écoute

### Principaux indicateurs

- barre de progression du compte à rebours
- barre d'informations compacte avec les détections actuelles, le nombre d'espèces uniques et le nombre total de détections
- vue du spectrogramme
- liste des détections

## Après le comptage

Lorsque le point d'écoute se termine, BirdNET Live enregistre la session et ouvre le [Résumé de la session](session-review.md).
