###### English version [here](https://github.com/johan-perso/escive/blob/main/README.md).

# eScive

eScive est une application mobile qui vise à être un client tiers pour les trottinettes électriques dotées de fonctionnalités Bluetooth, proposant une interface alternative avec plus de fonctionnalités et sans systèmes de télémétrie comme ceux inclus dans quelques apps officielles (souvent de marques chinoises 👀).

Pour l'instant, le projet cible surtout les modèles "i10" de la marque iScooter, mais est codé d'une façon à permettre l'ajout d'autres modèles et d'autres marques dans le futur.
La communication entre les appareils est basée sur le reverse engineering des paquets envoyés via les protocoles utilisant le BLE, et directement à partir du code source décompilé des apps officielles (mdrrr jme cache tlm pas).

| ![Accueil / Onboarding](https://r2.johanstick.fr/illustrationsdevs/escive/home_onboarding.png) | ![Accueil / compteur de vitesse](https://r2.johanstick.fr/illustrationsdevs/escive/home_speedometer.png) |
| --- | --- |

## Installation

### Android

~~Vous pouvez télécharger l'application depuis le [Play Store](https://play.google.com/store/apps/details?id=fr.johanstick.escive) si votre appareil le supporte.~~

L'application est toujours en phase de développement intensif et n'est pas encore disponible au téléchargement, ni via le Play Store, ni via un fichier APK fourni.
Vous pouvez suivre les commits ici pour être au courant de l'avancement du développement et de sa future sortie, qui se fera d'abord sur GitHub puis sur le Play Store.

### iOS

L'application n'est pas encore disponible sur iOS, et ne le sera sûrement pas pour quelque temps : j'ai préféré privilégier un support Android pour réduire le temps de développement, surtout en raison des fonctionnalités natives (widgets, bluetooth, ...), plus compliquées à implémenter et à tester.
Cependant, l'app peut être compilée et installée sur un iPhone/iPad en exécutant un premier build via Xcode puis en faisant un build final via la commande `flutter build ios` : certaines fonctionnalités seront restreintes et les autres ne seront pas aussi optimisées.

## Licence

MIT © [Johan](https://johanstick.fr). [Soutenez ce projet](https://johanstick.fr/#donate) si vous souhaitez m'aider 💙