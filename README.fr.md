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

## Protocole

Il est possible d'ouvrir l'app avec une action qui s'effectuera dès que possible depuis une URL débutant par `escive://`, cela permet par exemple la création d'automatisations *(KWGT, Automate / Raccourcis)* pour faciliter encore plus l'utilisation d'eScive.

| Chemin                                                      | Description                                                         |
| ----------------------------------------------------------- | ------------------------------------------------------------------- |
| [app](escive://app)                                         | Ouvre l'app sans action                                             |
| [controls/lock](escive://controls/lock)                     | Verrouille le véhicule actuellement associé                         |
| [controls/unlock](escive://controls/unlock)                 | Déverrouille le véhicule actuellement associé                       |
| [controls/toggle](escive://controls/toggle)                 | Verrouille ou déverrouille selon l'état actuel                      |
| [controls/led/on](escive://controls/led/on)                 | Allume le phare                                                     |
| [controls/led/off](escive://controls/led/off)               | Éteint le phare                                                     |
| [controls/led/toggle](escive://controls/led/toggle)         | Bascule l'état du phare                                             |
| [controls/speed/1](escive://controls/speed/1)               | Définit le mode de vitesse sur le mode n°1                          |
| [controls/speed/2](escive://controls/speed/2)               | Définit le mode de vitesse sur le mode n°2                          |
| [controls/speed/3](escive://controls/speed/3)               | Définit le mode de vitesse sur le mode n°3                          |
| [controls/speed/4](escive://controls/speed/4)               | Définit le mode de vitesse sur le mode n°4                          |

## Licence

MIT © [Johan](https://johanstick.fr). [Soutenez ce projet](https://johanstick.fr/#donate) si vous souhaitez m'aider 💙