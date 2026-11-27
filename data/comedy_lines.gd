class_name ComedyLines
extends RefCounted

## Centralized Mad-Science Sci-Fi Comedy Registry for TimeDefense.
## Tone: Deadpan Chrono-Science Bureaucracy, Reckless Engineering Optimism,
## Polite Ship AI Disclaimers, and Salty Intercepted Alien Comms.
## Edit or add lines right here anytime to expand the banter pool!

const SPEAKERS: Dictionary = {
	"vex": {
		"tag": "VEX",
		"role": "Chrono-Tactician",
		"color": Color(0.38, 0.96, 1.0),
	},
	"os": {
		"tag": "C.H.R.O.N.O.-OS",
		"role": "Ship AI",
		"color": Color(1.0, 0.86, 0.38),
	},
	"krag": {
		"tag": "WARLORD KRAG",
		"role": "Intercepted Alien Comms",
		"color": Color(1.0, 0.44, 0.58),
	},
}

# --- All 27 Tower Flavor Taglines (6 Base + 21 Combined) ---
const TOWER_FLAVOR: Dictionary = {
	"blaster": "Pointy metal, delivered enthusiastically.",
	"mortar": "Accuracy is overrated when the crater is big enough.",
	"laser": "Melts standard bugs. Completely defeated by anything shiny.",
	"slow": "Puts aliens in a temporal waiting room with terrible hold music.",
	"railgun": "Shoots targets so hard they age 40 years mid-air.",
	"annihilator": "Technically an anti-ship cannon. Legally a 'lawn ornament.'",
	"blaster+blaster": "We doubled the barrels and removed the safety latch. You're welcome.",
	"blaster+mortar": "For when you can't decide between shrapnel and more shrapnel.",
	"blaster+laser": "Auto-picks whichever beam hurts more. Science calls it 'rude.'",
	"blaster+slow": "Freezes their boots, then politely perforates their armor.",
	"blaster+railgun": "Fires needles faster than most planets spin.",
	"blaster+annihilator": "Shreds boss plating like a blender chewing on a toaster.",
	"mortar+mortar": "Drops a bomb that drops smaller bombs. Geometry has gone too far.",
	"mortar+laser": "Superheated mortar shells. Great for bugs and impromptu barbecues.",
	"mortar+slow": "Flash-freezes an entire zip code in one convenient shell.",
	"mortar+railgun": "Launches localized gravity wells. Please secure loose mugs.",
	"mortar+annihilator": "Cracks armor wide open with a noise audible from orbit.",
	"laser+laser": "The longer it stares, the hotter it gets. Do not make eye contact.",
	"laser+slow": "A cozy glowing snowglobe that gently microwaves everyone inside.",
	"laser+railgun": "Draws one neat glowing line through your entire problem.",
	"laser+annihilator": "Turns solid alien titanium into decorative puddles.",
	"slow+slow": "Technically a miniature black hole. Legally a 'speed bump.'",
	"slow+railgun": "Stops time just long enough to calculate an insultingly accurate shot.",
	"slow+annihilator": "Holds bosses completely still so the big gun doesn't miss.",
	"railgun+railgun": "Shoots straight through three aliens and a mild paradox.",
	"railgun+annihilator": "Voided warranties across four separate timelines.",
	"annihilator+annihilator": "Bolted two anti-ship cannons together. Recoil moved the planet 3mm.",
}

# --- All 10 Alien Field-Manual Quips ---
const ENEMY_FLAVOR: Dictionary = {
	"crawler": "Basically an aggressive space roomba with too many teeth.",
	"rusher": "Skipped leg day? Never. Skipped armor day? Always.",
	"brute": "Six hundred pounds of bad attitude and discount plating.",
	"blitzer": "Polished its shell to a mirror finish purely to spite Laser users.",
	"juggernaut": "Four tons of shiny chrome. Loves long walks straight into your Citadel.",
	"colossus": "Like a Juggernaut, except someone left it in the growth-ray overnight.",
	"stalker": "Thinks it's invisible. Technically right until a turret puts on glasses (Rng Lv2).",
	"mender": "The guy who brings snacks to an invasion and heals his buddies.",
	"carrier": "A cursed alien piñata packed with Blitzers and Rushers. Bring splash!",
	"conduit": "Projects a smug -35% shield bubble. Everyone hates this guy.",
}

# --- Planetary Travel-Brochure Lore for Maps ---
const LEVEL_LORE: Dictionary = {
	1: "Sector Travel Guide: Voted #1 Flattest Trench in the Quadrant. Great starter acoustics.",
	2: "Sector Travel Guide: Tall canyon lanes! Blitzers love the downhill breeze.",
	3: "Sector Travel Guide: Scenic central islands. Elevated optics give turrets +8% range.",
	4: "Sector Travel Guide: Designed by an architect who really liked cinnamon rolls.",
	5: "Sector Travel Guide: Safety inspectors visited once and immediately turned around.",
}

# --- Meta-Research R&D Notes ---
const RESEARCH_FLAVOR: Dictionary = {
	"rapid_cycling": "R&D Note: Replaced cooling fluid with espresso. Rate of fire improved.",
	"reinforced_shots": "R&D Note: Heavier slugs. We had to bolt the pads down twice.",
	"extended_optics": "R&D Note: Duct-taped binoculars to every turret. Surprisingly effective.",
	"efficient_manipulator": "R&D Note: Stopped kicking the reactor to reset cooldowns.",
	"hive_breaker": "R&D Note: Bigger capacitor, louder hum, zero safety certification.",
}

# --- Reactive 3-Voice Chrono-Comms Banter Pools ---
const BANTER: Dictionary = {
	"rewind": [
		{"speaker": "os", "text": "Timeline rewound. If you bump into yourself from 30 seconds ago, do not make eye contact."},
		{"speaker": "vex", "text": "Temporal do-over! Nobody saw that first attempt. Technically it never happened."},
		{"speaker": "krag", "text": "Wait... didn't we ALREADY march down this trench?! Stop messing with the clock!"},
		{"speaker": "os", "text": "Paradox side effect detected: aliens now arrive 5% more armored and mildly confused."},
	],
	"pause": [
		{"speaker": "vex", "text": "Aliens frozen for 8 seconds! Please refrain from drawing mustaches on the Juggernauts."},
		{"speaker": "os", "text": "Temporal Stasis engaged. Your turrets remain active because physics signed a waiver."},
		{"speaker": "krag", "text": "WHY CAN'T I MOVE MY LEGS?! WHO HIT THE PAUSE BUTTON?!"},
		{"speaker": "vex", "text": "Freeze frame! Nothing says 'fair fight' like shooting statues for eight straight seconds."},
	],
	"haste": [
		{"speaker": "os", "text": "Turrets overclocked +50%. Local laws of thermodynamics have filed a formal complaint."},
		{"speaker": "vex", "text": "HASTE active! Coffee levels in the ammo feed are now technically illegal."},
		{"speaker": "os", "text": "Warning: Extreme dakka may cause aliens to jog 5% faster out of sheer panic."},
		{"speaker": "krag", "text": "Slow down those guns! That fire rate isn't even regulation!"},
	],
	"surge": [
		{"speaker": "os", "text": "CHRONO SURGE! Good news: the reactor didn't explode. Bad news: turrets are -5% slower."},
		{"speaker": "vex", "text": "Ouch — Reactor Surged! Pop ANY Time Power every 5 waves to vent that pressure safely!"},
		{"speaker": "krag", "text": "Ha! Your fancy time-box sneezed! Now march faster, minions!"},
	],
	"combine": [
		{"speaker": "vex", "text": "Science says you shouldn't bolt two turrets together. Science isn't being invaded."},
		{"speaker": "os", "text": "Tower fusion complete. Engineering called — they're crying, mostly from pride."},
		{"speaker": "krag", "text": "Hold on, did those two tiny cannons just glue themselves into a BIGGER cannon?!"},
		{"speaker": "vex", "text": "Mad science unlocked! One shared upgrade track, twice the questionable safety specs."},
	],
	"apex_t4": [
		{"speaker": "os", "text": "Tier-4 Milestone online. Manual advises wearing sunglasses indoors."},
		{"speaker": "vex", "text": "Ooh, Tier-4 upgrade! Now we're cooking with completely unapproved isotopes."},
		{"speaker": "krag", "text": "Why is that turret glowing like a miniature sun? That seems unnecessary."},
	],
	"apex_t5": [
		{"speaker": "os", "text": "APEX TIER-5 ONLINE. Warranty voided across four separate dimensions."},
		{"speaker": "vex", "text": "FULL APEX OVERDRIVE! Tell Warlord Krag to start updating his résumé!"},
		{"speaker": "krag", "text": "OKAY NO, THAT'S OVERKILL! WHO APPROVED A TIER-5 DOOMSDAY TURRET?!"},
	],
	"hive_charge": [
		{"speaker": "os", "text": "Charging Hive Destroyer. Please look away unless you prefer seeing in fewer colors."},
		{"speaker": "vex", "text": "Big orbital delete-beam charging! Hold the line for 30 seconds — Haste can't rush this beauty!"},
		{"speaker": "krag", "text": "Hey! What's that giant humming noise pointing straight at my Hive?!"},
	],
	"hive_fire": [
		{"speaker": "krag", "text": "HEY! I JUST painted that Hive! Do you know how hard it is to get matching slime-green?!"},
		{"speaker": "os", "text": "Direct hit on Alien Hive. Structural integrity rating downgraded to 'crispy.'"},
		{"speaker": "vex", "text": "BOOM! Orbital delete-beam delivered! One step closer to clocking out early."},
	],
	"boss_wave": [
		{"speaker": "krag", "text": "Behold my unstoppable chrome Juggernauts! ...Wait, why do you have so many Piercing turrets?!"},
		{"speaker": "vex", "text": "Big metal nightmares incoming! Stack Piercing (180%), Slow bubbles & PAUSE!"},
		{"speaker": "os", "text": "Boss class detected. Recommending maximum prejudice and zero hesitation."},
	],
	"cloak_wave": [
		{"speaker": "krag", "text": "Hahaha! Deploy the invisible Phase Stalkers! Surely none of your turrets have Range Lv2!"},
		{"speaker": "vex", "text": "Cloaked Stalkers ahead! Give any turret fancy glasses (Range Lv2) to ruin their stealth montage."},
		{"speaker": "os", "text": "Optical anomaly detected. Lasers, Chrono Slow, Railguns & Range Lv2+ can see right through it."},
	],
	"exam_wave": [
		{"speaker": "krag", "text": "Time for my signature formation! I stayed up all night drawing arrows on a whiteboard for this!"},
		{"speaker": "os", "text": "High-density signature wave ahead. Please verify your splash damage insurance is current."},
		{"speaker": "vex", "text": "Signature Exam Wave! Survive this and I'll personally nominate you for Commander of the Month."},
	],
	"close_call": [
		{"speaker": "vex", "text": "Whew! That alien nearly signed the Citadel guestbook."},
		{"speaker": "os", "text": "Target neutralized 2 meters from the front door. Carpet remains mostly unsinged."},
		{"speaker": "krag", "text": "SO CLOSE! One more step and you would've gotten a slightly dented doorframe!"},
	],
	"leak": [
		{"speaker": "os", "text": "Uninvited alien entered the Citadel. Someone please revoke its visitor pass."},
		{"speaker": "vex", "text": "Hey, they're tracking space-mud on the carpet! Tighten up the kill-box!"},
		{"speaker": "krag", "text": "YES! One made it inside! Quick, steal their coffee machine!"},
	],
	"sell": [
		{"speaker": "os", "text": "Turret recycled for 75% scrap. Don't worry, it didn't have feelings. Probably."},
		{"speaker": "vex", "text": "Liquidating hardware! Out with the old, in with something way more irresponsible."},
	],
	"refinery": [
		{"speaker": "os", "text": "Refinery online. Remember: Refineries only pump cash during active combat — no loitering."},
		{"speaker": "vex", "text": "Passive income humming! Upgrade Refinery Tech in the right panel to turn this into a Temporal Bank."},
	],
	"refinery_tech": [
		{"speaker": "os", "text": "Refinery Tech upgraded. Economists are baffled and slightly impressed."},
		{"speaker": "vex", "text": "Cha-ching! Now we can actually afford those shiny Tier-5 Apex toys."},
	],
}

static var _banter_cursors: Dictionary = {}


static func get_tower_flavor(tower_type: String) -> String:
	return str(TOWER_FLAVOR.get(tower_type, "Precision Chrono-Science hardware (warranty expired)."))


static func get_enemy_flavor(enemy_type: String) -> String:
	return str(ENEMY_FLAVOR.get(enemy_type, "Unregistered extraterrestrial trespasser."))


static func get_level_lore(level_id: int) -> String:
	return str(LEVEL_LORE.get(level_id, "Uncharted Chrono Sector. Bring extra batteries."))


static func get_research_flavor(node_key: String) -> String:
	return str(RESEARCH_FLAVOR.get(node_key, "R&D Note: Passed 2 out of 5 safety checks."))


static func pick_banter(category: String) -> Dictionary:
	var pool: Array = BANTER.get(category, [])
	if pool.is_empty():
		return {}
	var idx: int = int(_banter_cursors.get(category, 0)) % pool.size()
	_banter_cursors[category] = (idx + 1) % pool.size()
	var item: Dictionary = pool[idx]
	var spk_key: String = str(item.get("speaker", "vex"))
	var spk: Dictionary = SPEAKERS.get(spk_key, SPEAKERS["vex"])
	return {
		"speaker": spk_key,
		"tag": str(spk["tag"]),
		"color": spk["color"],
		"text": str(item.get("text", "")),
	}


static func get_end_of_run_review(outcome: String, m: Object) -> Dictionary:
	var rew: int = int(m.stats["powers_used"].get("rewind", 0))
	var pau: int = int(m.stats["powers_used"].get("pause", 0))
	var has: int = int(m.stats["powers_used"].get("haste", 0))
	var total_p: int = rew + pau + has
	if outcome == "won":
		if m.lives >= Balance.PLAYER_STARTING_LIVES:
			return {
				"badge": "FLAWLESS VICTORY — WARLORD KRAG HAS BLOCKED YOUR NUMBER",
				"note": "C.H.R.O.N.O.-OS: Zero leaks, zero mercy. Citadel carpet remains pristine.",
			}
		if m.surge_count == 0 and total_p > 0:
			return {
				"badge": "CERTIFIED RESPONSIBLE TIME-BENDER",
				"note": "VEX: Zero Surges AND you blew up the Hive! HR is framing your timesheet.",
			}
		if rew >= 3:
			return {
				"badge": "TEMPORAL DÉJÀ VU CHAMPION",
				"note": "C.H.R.O.N.O.-OS: Rewound %d times, yet somehow won on the first try (legally)." % rew,
			}
		return {
			"badge": "CERTIFIED HIVE VAPORIZER",
			"note": "VEX: Alien Hive downgraded to smoking crater. Great shift, Commander!",
		}
	if outcome == "stalled":
		return {
			"badge": "PEACEFUL COEXISTENCE AWARD (NOT AUTHORIZED)",
			"note": "VEX: You survived all 45 waves, but forgot to zap the Alien Hive! Charge that Hive Destroyer next run!",
		}
	# Defeat awards
	if m.wave_number == 10:
		return {
			"badge": "TRAMPLED BY CHROME",
			"note": "WARLORD KRAG: 'My Juggernauts send their regards!'  |  VEX: 'Stack Piercing + Slow + PAUSE next time!'",
		}
	if m.wave_number == 11:
		return {
			"badge": "AMBUSHED BY INVISIBLE NINJAS",
			"note": "VEX: 'Cloaked Phase Stalkers got us! Remember: Range Lv2 (+CAMO) or Lasers/Slow/Railguns expose them!'",
		}
	if m.surge_count >= 2:
		return {
			"badge": "CHRONO-REACTOR SNEEZE VICTIM",
			"note": "C.H.R.O.N.O.-OS: %d Surges slowed your turrets. Pop any Time Power every 5 waves to vent pressure." % m.surge_count,
		}
	if rew >= 3:
		return {
			"badge": "GROUNDHOG DAY VETERAN",
			"note": "C.H.R.O.N.O.-OS: %d Rewinds stacked extra alien armor. Sometimes advancing beats looping!" % rew,
		}
	return {
		"badge": "TEMPORARY TACTICAL SETBACK",
		"note": "VEX: Good news — you kept your Meta-Research! Upgrade in the Lab and show Krag who's boss.",
	}
