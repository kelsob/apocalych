extends Node

## ProjectColors - Central color definitions for the project.
## Add as autoload (Project → Project Settings → Autoload) with path: res://scripts/autoloads/ProjectColors.gd
## Use via: ProjectColors.UI_FONT_SHADOW, ProjectColors.HEALTH_BAR_FILL, etc.

# --- UI / Theme ---
## Font shadow used across UI labels, buttons
const UI_FONT_SHADOW: Color = Color("#967B4C")

## Red accent for destructive/important actions
const UI_ACCENT_RED: Color = Color("#B50000")

## Brown text for event/dialogue body
const UI_TEXT_BROWN: Color = Color("#6E5933")

## Light parchment for panels and windows
const UI_PANEL_LIGHT: Color = Color("#C4AD8C")

## Darker parchment for muted elements
const UI_PANEL_DARK: Color = Color("#493A1F")

# --- Map ---
## Connection lines between nodes
const MAP_LINE: Color = Color("#967B4C")

## Player trail
const MAP_TRAIL: Color = Color("#B50000")

## Path preview on hover (60% alpha)
const MAP_PREVIEW_PATH: Color = Color("#FFE64D99")

## Town marker fill (80% alpha)
const MAP_TOWN_MARKER: Color = Color("#FFE64DCC")

## Town marker center
const MAP_TOWN_MARKER_CENTER: Color = Color("#CC991A")

# --- Selection / Feedback ---
## Selection highlight on valid targets (35% alpha)
const SELECTION_HIGHLIGHT: Color = Color("#FFE63359")

## Valid action outline (25% alpha)
const VALID_OUTLINE: Color = Color("#4DE64D40")

## Hover highlight (20% alpha)
const HOVER_HIGHLIGHT: Color = Color("#66B3FF33")

## Character card highlight when selected — HDR value, kept as float
const CHARACTER_HIGHLIGHT: Color = Color(1.25, 1.25, 1.0)

## Combat dimming for inactive sprites (70% alpha)
const COMBAT_DIM: Color = Color("#4D4D4DB3")

## Pale gold for combat/UI highlights
const PALE_GOLD: Color = Color("#F2E08C")

## Preview green (e.g. blacksmith upgrade preview)
const PREVIEW_GREEN: Color = Color("#59F259")

# --- Health / Progress ---
## Health bar fill (full)
const HEALTH_BAR_FILL: Color = Color("#33CC33")

## Health bar fill when low
const HEALTH_BAR_LOW: Color = Color("#CC3333")

## Health bar background
const HEALTH_BAR_BG: Color = Color("#333333")

## Event choice selected — manuscript green
const EVENT_CHOICE_SELECTED: Color = Color("#336B2E")

## Event choice rejected — ghosted parchment ink (40% alpha)
const EVENT_CHOICE_REJECTED: Color = Color("#D4BF9966")

# --- Item Rarity ---
## Common — clean off-white
const RARITY_COMMON: Color = Color("#E8E8E8")

## Uncommon — vivid forest green
const RARITY_UNCOMMON: Color = Color("#1EFF00")

## Rare — bright sapphire blue
const RARITY_RARE: Color = Color("#0070FF")

## Epic — rich arcane purple
const RARITY_EPIC: Color = Color("#A335EE")

## Legendary — blazing amber-orange
const RARITY_LEGENDARY: Color = Color("#FF8000")

## Convenience array indexed by Item.Rarity enum (COMMON=0 … LEGENDARY=4)
const RARITY_COLORS: Array[Color] = [
	Color("#E8E8E8"),   # 0 Common
	Color("#1EFF00"),   # 1 Uncommon
	Color("#0070FF"),   # 2 Rare
	Color("#A335EE"),   # 3 Epic
	Color("#FF8000"),   # 4 Legendary
]

# --- Lunar cycle ---
## Light colors for moon phase label modulation. Cool blue (new) → warm gold (full) → cool blue (waning).
## All contrast well on dark backgrounds.
const LUNAR_PHASE_COLORS: Array[Color] = [
	Color("#B0C7F0"),   # 0 New Moon — cool pale blue
	Color("#C7D6F0"),   # 1 Waxing Crescent
	Color("#D9E0E6"),   # 2 First Quarter — pale silver
	Color("#F0E6A6"),   # 3 Waxing Gibbous — soft gold
	Color("#F5E878"),   # 4 Full Moon — warm golden yellow
	Color("#F0E6B3"),   # 5 Waning Gibbous
	Color("#D1E0EB"),   # 6 Last Quarter — pale cool
	Color("#B8D1F0"),   # 7 Waning Crescent — cool blue
]
