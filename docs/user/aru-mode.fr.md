# Mode ARU

!!! note "Implémentation précoce"
    Le mode ARU crée actuellement une Session de déploiement planifiée et récupérable, enregistre les cycles planifiés, exécute l'inférence en direct pendant les cycles actifs, enregistre les clips de détection conservés lorsque ce mode d'enregistrement est sélectionné et affiche des contrôles de notification de premier plan sur Android. Le comportement en arrière-plan sur iOS doit encore être validé sur le terrain.

Le mode ARU (Autonomous Recording Unit) est le flux de travail pour les déploiements acoustiques planifiés sur site fixe.

## Flux de configuration actuel

- **Déploiement et audio** : saisissez le nom de déploiement, l'ID ARU/station, l'observateur, le site fixe, le mode d'enregistrement, le format d'enregistrement et les règles de conservation des clips de détection. La configuration réutilise le sélecteur de microphone partagé et affiche l'aperçu météo lorsque la recherche météo est autorisée.
- **Planning** : choisissez la durée du cycle, l'intervalle de répétition, la manière dont le déploiement doit se terminer et un seuil d'arrêt batterie faible. Vous pouvez arrêter manuellement, arrêter après un nombre fixe de cycles planifiés ou arrêter à une date et une heure fixes. Les cycles réguliers sont ancrés aux limites de l'horloge, donc un cycle de 10 minutes toutes les heures commence à l'heure pile plutôt que relativement au moment où vous avez lancé la configuration. Le test d'une minute est activé par défaut, démarre immédiatement et ne consomme pas le nombre de cycles planifiés.
- **Prêt** : vérifiez le planning et le stockage audio estimé, puis démarrez le déploiement.

Au démarrage, une Session `SessionType.aru` est immédiatement enregistrée avec les métadonnées du planning ARU afin que l'état des cycles puisse être récupéré plus tard.

Les exports JSON et ZIP incluent les métadonnées du déploiement ARU. Les exports ZIP regroupent les fichiers d'enregistrement par cycle enregistrés sous `aru_cycles/`.

## Déploiement actif

L'écran ARU actif indique si le déploiement est en attente, en enregistrement ou terminé. Sa mise en page utilise quatre onglets : **État** pour l'état courant du déploiement et les détections, **Spectrogramme** pour vérifier que l'audio arrive tout en gardant les détections dessous, **Planning** pour les 10 prochains horaires de cycle planifiés et **Résumé** pour le temps écoulé, la durée audio enregistrée et les totaux de détections. Sur Android, les déploiements actifs affichent une notification de premier plan avec les actions Arrêter et Ouvrir.

L'arrêt d'un déploiement ouvre Session Review pour le déploiement enregistré lorsque les cycles sont groupés dans une session. Lorsque la configuration enregistre chaque cycle comme une Session séparée, l'arrêt ouvre la dernière Session de cycle.

Sur iOS, cette implémentation précoce doit être traitée comme un flux de premier plan jusqu'à ce que l'audio planifié et le comportement en arrière-plan aient été validés sur iOS.

## Encore prévu

- Validation du comportement en arrière-plan sur iOS.
- Prise en charge complète de la lecture et du spectrogramme dans Session Review pour les enregistrements ARU segmentés.
