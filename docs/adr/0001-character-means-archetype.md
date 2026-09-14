# Character means the archetype, Player means the runtime entity

The glossary treats *Character* as the playable archetype (Rogue/Warrior/Tank, `CharacterData`),
and *Player* as the runtime combat entity the human controls. The code class `Character`
(`Scripts/character.gd`) and scene `Systems/Character.tscn` are the Player; only
`CharacterData` resources are Characters. We chose the player-facing "choose your character"
meaning over code alignment and deliberately did **not** rename the class, to avoid a
project-wide churn while the archetype system is still new. Future work should rename
`class_name Character` to `Player` when it can be done in one sweep.