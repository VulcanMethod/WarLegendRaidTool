# WarLegend RaidTool

Addon WoW **Forever** (interface 16001) de la guilde **War Legend** : groupes de raid, loot council, buffs,
ready check, checklist, inspection, suivi d'auras, CD de raid, préparation, rerolls, outils de guilde,
export pour simulateurs (SimulationCraft, MythicSim, OXM), chrono de cimetière, liste de summon.
Commande : `/wl`. Langues : français / anglais.

> L'addon est réservé aux membres de la guilde **War Legend** (message affiché sinon).
> Droits réservés : utilisation libre, pas de redistribution modifiée sans accord.

## Installation

Il faut **trois dossiers** dans `World of Warcraft\_classic_beta_\Interface\AddOns\` :

```
AddOns\
├── WarLegendRaidTool\        noyau (toujours chargé)
├── WarLegendRaidTool_Raid\   modules de raid (chargés à la demande, comme BigWigs)
└── WarLegendRaidTool_PvP\    cadres ennemis / alliés en champ de bataille (chargés à la demande)
```

Le plus simple : télécharger le zip de la dernière **Release** (les trois dossiers sont à la racine) et le
décompresser dans `AddOns`. Avec **WowUp** : *Obtenir des addons → Installer depuis une URL* → adresse de ce dépôt.

## Premier lancement

1. Vérifier que les trois addons sont cochés dans la liste des addons.
2. `/wl` ouvre la fenêtre. Le chargement des modules de raid se fait tout seul (groupe, donjon, `/wl`),
   celui des cadres PvP en entrant dans un champ de bataille (réglages : `/wl pvp`).
3. Raccourci de rechargement : Échap → Options → Raccourcis → AddOns → WarLegend RaidTool.

Les erreurs éventuelles s'affichent dans BugSack. Version actuelle : voir `WarLegendRaidTool.toc`.
