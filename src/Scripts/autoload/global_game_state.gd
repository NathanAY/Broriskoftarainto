extends Node

## Default character used when the player starts without choosing one in the menu.
const DEFAULT_CHARACTER := "res://src/Assets/character/multitasker/Multitasker.tres"

var starting_weapons: Array[String] = []
var starting_items: Array[String] = []
var starting_character: Variant = DEFAULT_CHARACTER # store resource path (String) or loaded Resource
var current_character: Character = null # store resource path (String) or loaded Resource
