# WarLegend RaidTool

Addon WoW **Forever** (interface 16001) de la guilde **War Legend** : groupes de raid, loot council (avec le
nombre de loots reçus), buffs, ready check, checklist, inspection, suivi d'auras, CD de raid, préparation, présences,
rerolls, outils de guilde (inactifs, métiers, recrutement, recrues en essai, stock des persos banque),
export pour simulateurs (SimulationCraft, MythicSim, OXM), cadres PvP, chrono de cimetière (style Capping),
historique et records des premades de BG, liste de summon.
Commande : `/wl` (`/wl help` affiche toutes les commandes). Langues : français / anglais.

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

## Commandes

`/wl` peut aussi s'écrire `/wlrt` ou `/warlegend`. `[preset]` = nom d'un preset de groupes (sans nom : le preset sélectionné).

**Général**

| Commande | Effet |
|---|---|
| `/wl` | Ouvre / ferme la fenêtre principale. |
| `/wl help` | Affiche toutes les commandes dans le chat. |
| `/wl minimap` | Affiche / cache le bouton de la minicarte. |
| `/wl bugs` | Ouvre l'onglet Bugs (erreurs Lua récentes). |
| `/wl perf` | Mémoire et CPU utilisés par l'addon. |
| `/wl reset [données]` | Sans nom : liste les données sauvegardées. Avec un nom : remet ce module à zéro (puis recharge). |
| `/wl rl` | Bascule `/rl` entre le vrai `/reload` de Blizzard et la fenêtre d'EllesmereUI. |
| `/wl logdebug` | Active / coupe le débogage du journal de combat automatique. |

**Raid : groupes et marques**

| Commande | Effet |
|---|---|
| `/wl apply [preset]` | Applique le preset : marques + groupes. |
| `/wl marks [preset]` | Pose seulement les marques du preset. |
| `/wl groups [preset]` | Range seulement les groupes du preset. |
| `/wl clear` | Enlève toutes les marques. |
| `/wl list` | Liste les presets enregistrés. |
| `/wl assist [preset]` | Crée ma macro d'assist d'après le preset. |

**Raid : ready check et loot**

| Commande | Effet |
|---|---|
| `/rc` | Lance un vrai ready check (chef / assistant), sinon ouvre la fenêtre de vérification. |
| `/wl rc` | Ouvre la fenêtre de vérification (prêt, durabilité). |
| `/wl loot` | Ouvre le Loot Council. |
| `/wl loot vote` | Ouvre la fenêtre de vote. |
| `/wl loot add [objet]` | Ajoute un objet (lien) à la liste des objets à attribuer. |
| `/wl loot test` | Lance une session de test. |
| `/wl sr` | Ouvre l'onglet des soft-res. |
| `!sr [objet]` *(chuchotement)* | Un joueur réserve un objet en chuchotant le chef de loot (si l'option est cochée). `!sr` seul : voir ses réserves. |

**Outils**

| Commande | Effet |
|---|---|
| `/wl sim` | Export SimulationCraft. `/wl sim oxm` : format OXM, `/wl sim json` : JSON (MythicSim). |
| `/wl summon` | Ouvre la liste de summon. |
| `/wl trials` | Recrues en essai (selon le rang choisi) : depuis quand, nombre de raids, rappel à la fin de l'essai. |
| `/wl bank` | Stock et or de mes persos banque (ceux de mon compte au rang « Banque »), avec recherche. |
| `/wl bg` | Historique de mes premades de BG, stats par joueur, records par BG (victoires les plus rapides). |
| `/wl gy` | Active / coupe le test du chrono de cimetière (fausses vagues). |
| `/wl pvp` | Réglages des cadres PvP. |
| `/wl pvpcheck` | Vérifie si les restrictions d'addons sont actives dans ce champ de bataille. |

Les erreurs éventuelles s'affichent dans BugSack. Version actuelle : voir `WarLegendRaidTool.toc`.
