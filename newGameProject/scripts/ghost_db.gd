class_name GhostDB
extends RefCounted
## The data behind every ghost and piece of evidence. Behaviours live in scripts/ghosts/.

enum Ev { EMF, FREEZING, SPIRIT_BOX, MOTION, SALT, PHOTO, BLUE_FLAME, HANDPRINTS, EVP }

const EVIDENCE := {
	Ev.EMF: {"name": "EMF Level 5", "hint": "EMF Reader peaks at 5 near the ghost or just after it acts."},
	Ev.FREEZING: {"name": "Freezing Temps", "hint": "Thermometer reads below 0 C in the ghost's room."},
	Ev.SPIRIT_BOX: {"name": "Spirit Box Voice", "hint": "A voice answers through the static when you are close."},
	Ev.MOTION: {"name": "Motion Trip", "hint": "A placed Motion Detector trips, and the field log records it."},
	Ev.SALT: {"name": "Salt Footprints", "hint": "Footprints appear in a salt pile the ghost walks over."},
	Ev.PHOTO: {"name": "Figure on Film", "hint": "A figure shows up in Camera photos. Check them in this notebook."},
	Ev.BLUE_FLAME: {"name": "Blue Flame", "hint": "A lit Candle burns blue when the ghost is close."},
	Ev.HANDPRINTS: {"name": "UV Handprints", "hint": "A UV Light shows glowing handprints on doors the ghost has touched."},
	Ev.EVP: {"name": "EVP Recording", "hint": "Play back a Tape Recorder made near the ghost. A voice is on the tape."},
}

## Stats: speed is metres per second, the other three run from 0 to 1.
## bait is the item that holds this ghost in place once it is inside a tuned trap.
const TYPES: Array[Dictionary] = [
	{
		"id": "mourner", "name": "Mourner", "script": "res://scripts/ghosts/mourner.gd",
		"speed": 1.3, "aggressiveness": 0.12, "passiveness": 0.95, "activeness": 0.35,
		"color": Color(0.55, 0.7, 1.0), "height": 1.65,
		"evidence": [Ev.SPIRIT_BOX, Ev.FREEZING, Ev.BLUE_FLAME],
		"bait": "spirit_box", "bait_text": "Set the trap in its own room and keep a Spirit Box switched on nearby. It stays to listen.",
		"about": "Grieves in one room and never leaves it by choice. You can hear it weeping. It rarely hunts, and gives up the moment it loses sight of you.",
	},
	{
		"id": "rattler", "name": "Rattler", "script": "res://scripts/ghosts/rattler.gd",
		"speed": 2.1, "aggressiveness": 0.35, "passiveness": 0.2, "activeness": 1.0,
		"color": Color(0.9, 0.75, 0.35), "height": 1.3,
		"evidence": [Ev.EMF, Ev.MOTION, Ev.SALT],
		"bait": "motion_detector", "bait_text": "Set a switched-on Motion Detector near the trap. It can't leave a sensor alone.",
		"about": "A constant tantrum of slammed doors and thrown objects, in bursts. Each burst winds it up until it hunts, and it keeps throwing things at you during the chase.",
	},
	{
		"id": "gloam", "name": "Gloam", "script": "res://scripts/ghosts/gloam.gd",
		"speed": 3.4, "aggressiveness": 0.55, "passiveness": 0.45, "activeness": 0.5,
		"color": Color(0.25, 0.2, 0.4), "height": 2.0,
		"evidence": [Ev.PHOTO, Ev.FREEZING, Ev.SALT],
		"bait": "flashlight", "bait_text": "Hold your Flashlight beam on it while it is inside the trap.",
		"about": "Lives in the dark and puts out lights wherever it goes. Very fast in darkness, but it crawls in lit rooms or under a flashlight beam. It will only hunt you if you are in the dark.",
	},
	{
		"id": "watcher", "name": "Watcher", "script": "res://scripts/ghosts/watcher.gd",
		"speed": 4.6, "aggressiveness": 0.5, "passiveness": 0.6, "activeness": 0.15,
		"color": Color(0.85, 0.85, 0.8), "height": 1.9,
		"evidence": [Ev.PHOTO, Ev.MOTION, Ev.EMF],
		"bait": "camera", "bait_text": "Fire the Camera flash at it while it is inside the trap.",
		"about": "Barely touches the house. It stalks you instead, and only moves while you are not looking at it. Unseen it is the fastest ghost there is; keep your eyes on it and it can't move at all.",
	},
	{
		"id": "drifter", "name": "Drifter", "script": "res://scripts/ghosts/drifter.gd",
		"speed": 1.7, "aggressiveness": 0.4, "passiveness": 0.05, "activeness": 0.55,
		"color": Color(0.45, 0.9, 0.8), "height": 1.75,
		"evidence": [Ev.MOTION, Ev.BLUE_FLAME, Ev.SPIRIT_BOX],
		"bait": "salt", "bait_text": "Pour Salt near the trap. Salt anchors it and stops it from slipping away.",
		"about": "Never stops moving and has no home room. It floats straight through walls, even during a hunt, and senses you through them too. It is slow, but no route is safe from it.",
	},
	{
		"id": "cinder", "name": "Cinder", "script": "res://scripts/ghosts/cinder.gd",
		"speed": 1.8, "aggressiveness": 0.6, "passiveness": 0.35, "activeness": 0.6,
		"color": Color(1.0, 0.45, 0.15), "height": 1.7,
		"evidence": [Ev.EMF, Ev.BLUE_FLAME, Ev.SALT],
		"bait": "candle", "bait_text": "Put a lit Candle near the trap. It can't resist a flame.",
		"about": "Burning instead of cold: its room reads hot on a Thermometer. It leaves scorch marks and seeks out candles to swallow them. It gets faster the longer a hunt lasts, but a lit candle will distract it.",
	},
	{
		"id": "howler", "name": "Howler", "script": "res://scripts/ghosts/howler.gd",
		"speed": 3.8, "aggressiveness": 0.5, "passiveness": 0.4, "activeness": 0.4,
		"color": Color(0.7, 0.3, 0.75), "height": 2.1,
		"evidence": [Ev.SPIRIT_BOX, Ev.SALT, Ev.PHOTO],
		"bait": "emf_reader", "bait_text": "Keep an EMF Reader switched on near the trap. Its whine draws it in.",
		"about": "Completely blind and hunts by sound. Running, doors and noisy equipment bring it straight to you at full speed. If you crouch and keep quiet, it can pass right beside you.",
	},
	{
		"id": "fury", "name": "Fury", "script": "res://scripts/ghosts/fury.gd",
		"speed": 2.4, "aggressiveness": 1.0, "passiveness": 0.05, "activeness": 0.6,
		"color": Color(0.9, 0.12, 0.12), "height": 1.95,
		"evidence": [Ev.FREEZING, Ev.EMF, Ev.PHOTO],
		"bait": "smudge_stick", "bait_text": "Burn a Smudge Stick near the trap. The smoke weakens it enough to hold.",
		"about": "Pure hostility. It hunts no matter how calm you are, seeks you out between hunts, and speeds up the longer it can see you. Smudge only holds it off for half as long.",
	},
	{
		"id": "gaunt", "name": "Gaunt", "script": "res://scripts/ghosts/gaunt.gd",
		"speed": 2.2, "aggressiveness": 0.6, "passiveness": 0.4, "activeness": 0.35,
		"color": Color(0.6, 0.75, 0.45), "height": 2.05,
		"evidence": [Ev.EVP, Ev.FREEZING, Ev.MOTION],
		"bait": "thermos", "bait_text": "Set an open Thermos down near the trap as an offering. It can't pass up a meal.",
		"about": "Feeds on fear. It drifts towards you and drains your sanity quickly when close. It starts out sluggish, but the less sanity you have left, the faster it moves.",
	},
	{
		"id": "changeling", "name": "Changeling", "script": "res://scripts/ghosts/changeling.gd",
		"speed": 2.4, "aggressiveness": 0.5, "passiveness": 0.5, "activeness": 0.5,
		"color": Color(0.8, 0.8, 0.85), "height": 1.8,
		"evidence": [Ev.EVP, Ev.PHOTO, Ev.HANDPRINTS],
		"bait": "tape_recorder", "bait_text": "Keep a Tape Recorder recording or playing near the trap. It can't resist copying a voice.",
		"about": "Every minute or so it takes on another ghost's stats and habits, and its colour changes to match. What was safe a minute ago may get you killed now, so its evidence is the only thing you can trust.",
	},
	{
		"id": "busybody", "name": "Busybody", "script": "res://scripts/ghosts/busybody.gd",
		"speed": 2.0, "aggressiveness": 0.2, "passiveness": 0.4, "activeness": 0.8,
		"color": Color(0.85, 0.55, 0.65), "height": 1.6,
		"evidence": [Ev.EVP, Ev.EMF, Ev.SPIRIT_BOX],
		"bait": "permit_folder", "bait_text": "Leave a Permit Folder near the trap. It has to read the paperwork.",
		"about": "A nosy neighbour who never stopped. It rarely hunts, but it makes a racket on purpose, flings open the front door, and draws the street's attention. People outside get suspicious fast.",
	},
	{
		"id": "warden", "name": "Warden", "script": "res://scripts/ghosts/warden.gd",
		"speed": 2.3, "aggressiveness": 0.55, "passiveness": 0.5, "activeness": 0.6,
		"color": Color(0.55, 0.5, 0.45), "height": 2.0,
		"evidence": [Ev.HANDPRINTS, Ev.SALT, Ev.EMF],
		"bait": "iron_ward", "bait_text": "Plant an Iron Ward close to the trap, but not on top of it. Iron binds it in place.",
		"about": "Jams doors shut so you can't get through them. When it hunts, it seals the doors around you first, so know your second way out before it starts.",
	},
	{
		"id": "magpie", "name": "Magpie", "script": "res://scripts/ghosts/magpie.gd",
		"speed": 2.8, "aggressiveness": 0.35, "passiveness": 0.3, "activeness": 0.7,
		"color": Color(0.5, 0.65, 0.95), "height": 1.4,
		"evidence": [Ev.HANDPRINTS, Ev.BLUE_FLAME, Ev.MOTION],
		"bait": "dowsing_rods", "bait_text": "Hold your Dowsing Rods near the trap. It wants those shiny rods.",
		"about": "A thief. It takes equipment you've set down and leaves it in another room, though it won't touch the trap. If your detector vanished, go looking. It is quick but not very dangerous.",
	},
	{
		"id": "pallid", "name": "Pallid", "script": "res://scripts/ghosts/pallid.gd",
		"speed": 2.7, "aggressiveness": 0.6, "passiveness": 0.45, "activeness": 0.4,
		"color": Color(0.8, 0.5, 1.0), "height": 1.85,
		"evidence": [Ev.HANDPRINTS, Ev.FREEZING, Ev.SPIRIT_BOX],
		"bait": "uv_light", "bait_text": "Hold your UV Light beam on it while it is inside the trap.",
		"about": "Invisible to the naked eye, even while hunting, and its footsteps are faint. Only a UV Light beam shows it. Listen hard, and don't assume an empty hallway is empty.",
	},
]

const ITEM_SCRIPTS := [
	"res://scripts/items/flashlight.gd",
	"res://scripts/items/salt.gd",
	"res://scripts/items/candle.gd",
	"res://scripts/items/camera.gd",
	"res://scripts/items/smudge_stick.gd",
	"res://scripts/items/thermometer.gd",
	"res://scripts/items/emf_reader.gd",
	"res://scripts/items/spirit_box.gd",
	"res://scripts/items/motion_detector.gd",
	"res://scripts/items/ghost_trap.gd",
	"res://scripts/items/uv_light.gd",
	"res://scripts/items/tape_recorder.gd",
	"res://scripts/items/dowsing_rods.gd",
	"res://scripts/items/iron_ward.gd",
	"res://scripts/items/thermos.gd",
	"res://scripts/items/permit_folder.gd",
]


static func by_id(id: String) -> Dictionary:
	for t in TYPES:
		if t.id == id:
			return t
	return {}
