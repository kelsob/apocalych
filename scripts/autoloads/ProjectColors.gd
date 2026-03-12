extends Node

## ProjectColors - Central color definitions for the project.
## Add as autoload (Project → Project Settings → Autoload) with path: res://scripts/autoloads/ProjectColors.gd
## Use via: ProjectColors.UI_FONT_SHADOW, ProjectColors.HEALTH_BAR_FILL, etc.

# --- UI / Theme ---
## Font shadow used across UI labels, buttons — #967B4C
const UI_FONT_SHADOW: Color = Color(0.588235, 0.482353, 0.298039, 1)

## Red accent for destructive/important actions — #B50000
const UI_ACCENT_RED: Color = Color(0.709804, 0.0, 0.0, 1)

## Brown text for event/dialogue body — #6E5933
const UI_TEXT_BROWN: Color = Color(0.432319, 0.349618, 0.201173, 1)

## Light parchment for panels and windows — #C4AD8C
const UI_PANEL_LIGHT: Color = Color(0.767578, 0.677628, 0.548698, 1)

## Darker parchment for muted elements — #493A1F
const UI_PANEL_DARK: Color = Color(0.286275, 0.227451, 0.121569, 1)

# --- Map ---
## Connection lines between nodes — #967B4C
const MAP_LINE: Color = Color(0.588, 0.482, 0.298)

## Player trail — #B50000
const MAP_TRAIL: Color = Color(0.709, 0.0, 0.0, 1)

## Path preview on hover — #FFE64D (60% alpha)
const MAP_PREVIEW_PATH: Color = Color(1.0, 0.9, 0.3, 0.6)

## Town marker fill — #FFE64D (80% alpha)
const MAP_TOWN_MARKER: Color = Color(1.0, 0.9, 0.3, 0.8)

## Town marker center — #CC991A
const MAP_TOWN_MARKER_CENTER: Color = Color(0.8, 0.6, 0.1, 1)

# --- Selection / Feedback ---
## Selection highlight on valid targets — #FFE633 (35% alpha)
const SELECTION_HIGHLIGHT: Color = Color(1.0, 0.9, 0.2, 0.35)

## Valid action outline — #4DE64D (25% alpha)
const VALID_OUTLINE: Color = Color(0.3, 0.9, 0.3, 0.25)

## Hover highlight — #66B3FF (20% alpha)
const HOVER_HIGHLIGHT: Color = Color(0.4, 0.7, 1.0, 0.2)

## Character card highlight when selected — #FFFFFF
const CHARACTER_HIGHLIGHT: Color = Color(1.25, 1.25, 1.0)

## Combat dimming for inactive sprites — #4D4D4D (70% alpha)
const COMBAT_DIM: Color = Color(0.3, 0.3, 0.3, 0.7)

## Pale gold for combat/UI highlights — #F2E08C
const PALE_GOLD: Color = Color(0.95, 0.88, 0.55)

## Preview green (e.g. blacksmith upgrade preview) — #59F259
const PREVIEW_GREEN: Color = Color(0.35, 0.95, 0.35)

# --- Health / Progress ---
## Health bar fill (full) — #33CC33
const HEALTH_BAR_FILL: Color = Color(0.2, 0.8, 0.2, 1)

## Health bar fill when low — #CC3333
const HEALTH_BAR_LOW: Color = Color(0.8, 0.2, 0.2, 1)

## Health bar background — #333333
const HEALTH_BAR_BG: Color = Color(0.2, 0.2, 0.2, 1)

## Event choice selected — manuscript green — #336B2E
const EVENT_CHOICE_SELECTED: Color = Color(0.200, 0.420, 0.180, 1)

## Event choice rejected — ghosted parchment ink
const EVENT_CHOICE_REJECTED: Color = Color(0.831, 0.749, 0.600, 0.4)

# --- Lunar cycle ---
## Light colors for moon phase label modulation. Cool blue (new) → warm gold (full) → cool blue (waning).
## All contrast well on dark backgrounds.
const LUNAR_PHASE_COLORS: Array[Color] = [
	Color(0.69, 0.78, 0.94),   # 0 New Moon — #B0C7F0 cool pale blue
	Color(0.78, 0.84, 0.94),   # 1 Waxing Crescent — #C7D6F0
	Color(0.85, 0.88, 0.90),   # 2 First Quarter — #D9E0E6 pale silver
	Color(0.94, 0.90, 0.65),   # 3 Waxing Gibbous — #F0E6A6 soft gold
	Color(0.96, 0.91, 0.47),   # 4 Full Moon — #F5E878 warm golden yellow
	Color(0.94, 0.90, 0.70),   # 5 Waning Gibbous — #F0E6B3
	Color(0.82, 0.88, 0.92),   # 6 Last Quarter — #D1E0EB pale cool
	Color(0.72, 0.82, 0.94)    # 7 Waning Crescent — #B8D1F0 cool blue
]
