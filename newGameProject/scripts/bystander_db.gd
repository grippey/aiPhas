class_name BystanderDB
extends RefCounted
## Who shows up outside the house and what they want to hear. Each person trusts
## one tone of answer and distrusts another. Their greeting hints at which.

const PEOPLE: Array[Dictionary] = [
	{
		"name": "Pat", "shirt": Color(0.55, 0.4, 0.55), "likes": "official", "hates": "joke",
		"loves_emote": "salute", "hates_emote": "dance",
		"greeting": "Pat, from next door. I've lived on this street for forty years and nobody told me about any work on this house. Who signed off on this?",
	},
	{
		"name": "Robin", "shirt": Color(0.25, 0.5, 0.45), "likes": "honest", "hates": "official",
		"loves_emote": "thumbs_up", "hates_emote": "salute",
		"greeting": "Whoa, are you, like, a real ghost hunter? Everybody says this place is haunted. Just tell me the truth!",
	},
	{
		"name": "Morgan", "shirt": Color(0.6, 0.5, 0.3), "likes": "reassure", "hates": "honest",
		"loves_emote": "wave", "hates_emote": "taunt",
		"greeting": "Sorry to bother you. My kids can hear noises from their bedroom and they're scared. Please tell me everything is okay.",
	},
	{
		"name": "Sam", "shirt": Color(0.3, 0.35, 0.5), "likes": "official", "hates": "reassure",
		"loves_emote": "salute", "hates_emote": "shrug",
		"greeting": "Thirty years on the force, retired. I know a brush-off when I hear one, so let's see some credentials and a straight answer.",
	},
	{
		"name": "Jo", "shirt": Color(0.6, 0.35, 0.25), "likes": "joke", "hates": "official",
		"loves_emote": "dance", "hates_emote": "salute",
		"greeting": "Ha! Walking the dog at midnight and I find this. Go on then, what's the story? Make it a good one.",
	},
]

## Each question has one answer per tone: official, reassure, honest and joke.
const QUESTIONS: Array[Dictionary] = [
	{
		"line": "What's all that banging coming from in there?",
		"official": "Scheduled structural survey. We have to test the old joists.",
		"reassure": "Just old pipes settling. It's nothing to worry about.",
		"honest": "Something in there doesn't want to leave. I'm handling it.",
		"joke": "The house is learning the drums. It's not going well.",
	},
	{
		"line": "Why are you going in there in the middle of the night?",
		"official": "Night survey. The readings are only accurate after dark.",
		"reassure": "It's quieter for everyone this way. I'll be done soon.",
		"honest": "It's most active at night, so that's when I can catch it.",
		"joke": "The daytime shift was too scared to do it.",
	},
	{
		"line": "Is somebody hurt in there? I thought I heard a scream.",
		"official": "No casualties on site. It's all in my incident report.",
		"reassure": "Nobody's hurt, I promise. Everyone is perfectly fine.",
		"honest": "That wasn't a person. That's why I'm here.",
		"joke": "That was me. I found a spider.",
	},
	{
		"line": "Are you even allowed to be in there?",
		"official": "Yes. The property manager contracted my firm directly.",
		"reassure": "Of course. The owners know all about it.",
		"honest": "The owners called me because they won't go back inside.",
		"joke": "Nobody else wants to be, so I got it by default.",
	},
	{
		"line": "The lights keep flickering in there. What's going on?",
		"official": "We've isolated the circuits for an electrical inspection.",
		"reassure": "It's just some bad wiring. I'm sorting it out now.",
		"honest": "Lights do that when it's close. That's how I track it.",
		"joke": "It's a very slow disco.",
	},
	{
		"line": "Should I be worried? Should I call somebody?",
		"official": "No need. The relevant authorities are already notified.",
		"reassure": "No, there's nothing to worry about. Get some rest.",
		"honest": "Stay out of the house and you'll be safe. I've got this.",
		"joke": "Only if you know a really good plumber.",
	},
]

## Asked by someone already on the phone with the police.
const CALLER_QUESTIONS: Array[Dictionary] = [
	{
		"line": "I've got the police on the line right now. Give me one good reason to hang up.",
		"official": "Tell them it's a licensed job. They can check my paperwork.",
		"reassure": "It really is fine. Please, just tell them it was a false alarm.",
		"honest": "If they walk in there, someone gets hurt. Let me finish.",
		"joke": "Ask them if they've ever arrested a ghost.",
	},
	{
		"line": "They're asking me what's happening. What am I supposed to tell them?",
		"official": "Tell them it's an authorized survey and give them my name.",
		"reassure": "Tell them you checked and everything's all right.",
		"honest": "Tell them it's almost over, and that nobody should come in.",
		"joke": "Tell them the house has apologised and won't do it again.",
	},
]

const REPLIES := {
	"liked": ["Okay. That makes sense to me.", "Well, thank you for being straight with me.", "Right. That's what I needed to hear.", "Huh. All right, I can accept that."],
	"neutral": ["Hm. I suppose so.", "If you say so.", "Maybe. Go on.", "That doesn't really answer me, but fine."],
	"hated": ["Do you think I'm stupid?", "No. I don't buy that at all.", "That's not funny, and it's not an answer.", "Now I'm even more worried."],
}

const TONES := ["official", "reassure", "honest", "joke"]
