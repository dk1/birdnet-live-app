# Mode ARU

!!! note "Implémentation initiale"
    Le mode ARU crée actuellement une session de déploiement planifiée et récupérable, et suit les cycles d'enregistrement prévus. L'enregistrement audio par cycle et les notifications de premier plan Android sont raccordés dans cette version initiale; l'inférence, les clips de détection seuls et la lecture complète en revue sont encore en développement.

Le mode ARU (Autonomous Recording Unit) est le flux de travail pour les déploiements acoustiques planifiés sur site fixe.

## Configuration actuelle

- **Déploiement et audio** : saisissez le nom de déploiement, l'ID ARU/station, l'observateur, le site fixe et le mode d'enregistrement. La configuration réutilise le sélecteur de microphone partagé et affiche l'aperçu météo lorsque la recherche météo est autorisée. L'enregistrement de clips de détection seuls et les contrôles de conservation des clips restent masqués jusqu'à ce que l'inférence planifiée soit raccordée de bout en bout.
- **Planning** : choisissez la durée du cycle, l'intervalle de répétition, la manière dont le déploiement doit se terminer et un seuil d'arrêt batterie faible. Vous pouvez arrêter manuellement, arrêter après un nombre fixe de cycles ou arrêter à une date et une heure fixes. Le cycle de test optionnel d'une minute reste prévu, mais il demeure masqué tant qu'il ne fonctionne pas de bout en bout.
- **Prêt** : vérifiez le planning et le stockage audio estimé, puis démarrez le déploiement.

Au démarrage, une session `SessionType.aru` est immédiatement enregistrée avec les métadonnées du planning ARU afin que l'état des cycles puisse être récupéré plus tard.

Les exports JSON et ZIP incluent les métadonnées du déploiement ARU. Si une version ultérieure enregistre des fichiers audio par cycle dans la session, l'export ZIP regroupe ces fichiers sous `aru_cycles/`.

## Déploiement actif

L'écran ARU actif indique si le déploiement est en attente, en enregistrement ou terminé. La mise en page suit maintenant Survey : ligne d'état compacte, onglets supérieurs pour le planning, le spectrogramme en direct et le résumé, une barre de statistiques et un flux de détections persistant en dessous. Ce flux affiche les détections du cycle courant pendant l'enregistrement et les détections récentes du déploiement pendant l'attente. Sur Android, les déploiements actifs affichent une notification de premier plan avec les actions Arrêter et Ouvrir.

Sur iOS, cette implémentation initiale doit être considérée comme un flux de premier plan jusqu'à ce que l'audio planifié et le comportement en arrière-plan soient validés sur iOS.

## Encore prévu

- Inférence et création de clips de détection seuls pendant les cycles d'enregistrement planifiés.
- Validation du comportement en arrière-plan sur iOS.
- Prise en charge complète de la lecture et du spectrogramme dans Session Review pour les enregistrements ARU segmentés.
