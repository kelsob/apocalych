# Implementation Plan: Larger Logical Map, Zoom 1 = 1:1 View

## Goal
- Map world is larger than the screen (e.g. 2× or 4×)
- **Zoom = 1** = closest view, showing a portion of the map at 1:1 (no upscaling)
- No zoom-in past 1 (only zoom-out)
- Avoid blur when zoomed (content is always rendered at or above 1:1)

## Current System (Summary)

### Coordinate Flow
1. **map_size** (Vector2, scene override 1280×780): Ellipse semi-axes for Poisson sampling. Nodes are generated in this abstract shape.
2. **size** (Control rect): MapGenerator fills Main → runtime size ≈ viewport (1280×720).
3. **center_points_at_origin**: Shifts nodes so their center aligns with `size/2`.
4. **Result**: Nodes end up roughly in 0..1280, 0..720. Camera uses `size` for limits.

### Zoom Semantics (Current)
- `zoom = 1`: See entire map (current_viewport_size = map_size). Position forced to center. Pan disabled.
- `zoom > 1`: Zoomed IN (see less of map).
- Scene overrides: `zoom_min = 1.0`, `zoom_max = 4.0` (MapGenerator.tscn line 219–220). So currently only zoom-in is possible.

### Key Files
| File | Role |
|------|------|
| `scripts/2d/MapGenerator2D.gd` | Map generation, centering, bake, camera setup |
| `scripts/2d/CameraController2D.gd` | Pan/zoom, `set_map_limits()` |
| `scripts/2d/StaticMapRenderer.gd` | Bakes static map to texture |
| `scripts/2d/WaterOverlay.gd` | Rivers/coast overlay (uses world coords) |
| `scenes/2d/MapGenerator.tscn` | Scene structure, GameCamera zoom_min/max override |
| `scenes/2d/Main.tscn` | Layout, MapGenerator placement |

---

## Implementation Strategy

**Approach: No SubViewport.** Use a `world_scale` factor. Content stays in MapGenerator’s coordinate space but is laid out in `logical_map_size = size * world_scale`. The camera uses this larger size for limits; zoom 1 shows a viewport-sized window at 1:1.

### New Semantics
- `world_scale = 2` → logical map 2560×1440 (for 1280×720 display)
- `zoom = 1`: See 1280×720 of map at 1:1 (closest view)
- `zoom = 0.5`: See full 2560×1440 (zoomed out)
- `zoom_min = 1/world_scale`, `zoom_max = 1.0`

---

## Script Changes

### 1. MapGenerator2D.gd

#### New export
```gdscript
@export_range(1.0, 4.0) var world_scale: float = 2.0  # Logical map = display * this
```

#### Helper (add near top of file)
```gdscript
func get_logical_map_size() -> Vector2:
    return size * world_scale
```

#### Replace `size` with `get_logical_map_size()` where map bounds/center are used

| Location | Current | New |
|----------|---------|-----|
| `center_points_at_origin()` ~949 | `screen_center = size / 2.0` | `screen_center = get_logical_map_size() / 2.0` |
| `vertically_center_nodes()` ~1035 | `screen_center_y = size.y / 2.0` | `screen_center_y = get_logical_map_size().y / 2.0` |
| `bake_static_map()` ~6109 | `static_map_viewport.size = size * map_resolution_scale` | `... = get_logical_map_size() * map_resolution_scale` |
| `position_map_decorations()` ~6458 | `map_bounds = size` | `map_bounds = get_logical_map_size()` |
| `_resize_background_viewport()` ~373 | `viewport_size := size * map_resolution_scale` | `viewport_size := get_logical_map_size() * map_resolution_scale` |
| `generate_map()` camera setup ~612 | `game_camera.set_map_limits(size)` | `game_camera.set_map_limits(get_logical_map_size(), Vector2(1.0 / world_scale, 1.0))` |
| `find_river_flow_direction()` ~5594 | `map_center = size/2` | `map_center = get_logical_map_size()/2` |

#### Scale content after centering
Add a new step **after** `vertically_center_nodes()` and **before** `generate_delaunay_connections()`:

```gdscript
func scale_content_to_logical_map():
    if world_scale <= 1.0 or map_nodes.size() == 0:
        return
    var logical_center = get_logical_map_size() / 2.0
    for node in map_nodes:
        var node_center = node.position + (node.size / 2.0)
        var offset = node_center - logical_center
        node.position = (node.position + offset * (world_scale - 1.0)) - (node.size / 2.0)  # scale from center, preserve node size
```
Simpler approach: scale node centers from logical center, then convert back to position:
```gdscript
for node in map_nodes:
    var node_center = node.position + (node.size / 2.0)
    var scaled_center = logical_center + (node_center - logical_center) * world_scale
    node.position = scaled_center - (node.size / 2.0)
```
- Call from `generate_map()` after `vertically_center_nodes()`, before step 7 (Delaunay).
- **Note**: Ellipse `map_size` (1280×780) may not match display aspect; scaled content can slightly overflow logical bounds. Consider using a fit scale or accepting minor overflow.

Actually: centering uses `screen_center = get_logical_map_size()/2`. So nodes are centered at (1280, 720) for world_scale=2. The nodes are generated in the ellipse (map_size = 1280×780). After center_points_at_origin with screen_center = (1280, 360), the offset would place nodes around that center. The ellipse 1280×780 centered at (1280, 360) would span roughly (640, 0) to (1920, 720). So we'd have content in that region. For a 2560×1440 logical map, that's the left half and top half. To fill the full logical map we need to scale. After centering, multiply all positions by world_scale:  
`pos_new = (pos - logical_center) * world_scale + logical_center`  
Actually simpler: `pos_new = pos * world_scale` if we center at origin first then scale then add center. The current flow: center to screen_center, then rotate, then vertically center. If we use logical_map_size/2 as screen_center, after centering nodes are around (logical_map_size/2). The node distribution from Poisson has a certain spread (in map_size ellipse). For world_scale 2, we want that spread to be 2× larger. So: after all centering, scale positions from center:  
`for node in map_nodes: node.position = (node.position - logical_center) * world_scale + logical_center`  
That would blow up the layout. Good.

#### Background layer size
`_background_layer_container` and its `display_rect` show the baked texture. The baked texture covers the full logical map. The container currently fills MapGenerator (1280×720). For the camera to show the correct region, the background needs to cover the logical map. Set the background viewport’s internal content to `get_logical_map_size()`; the display rect can stay full-rect of MapGenerator since the camera will pan/zoom the whole canvas. The _background_viewport renders the baked map. It’s sized to `get_logical_map_size() * map_resolution_scale`. The ColorRect and TextureRect inside are the same size. The display_rect shows that texture and fills the container. The container fills MapGenerator. So we're showing a `logical_map_size * map_resolution_scale` texture in a `size` rect. That would scale the full map into the visible area—but the camera controls what we see of the MapGenerator’s canvas. The _background_layer_container is a child of MapGenerator at z_index -2. It has anchors full rect, so it’s 1280×720. When the camera looks at (1280, 720), we see world (640,360) to (1920,1080). The background rect is at (0,0) size (1280,720)—it only covers the top-left quarter of the logical map. We need the background to cover (0,0) to (2560,1440). So:

- `_background_layer_container` must have `custom_minimum_size = get_logical_map_size()` and fill based on that, OR
- We use a different approach: the background is in a SubViewport that’s the size of the logical map, and we display it… Actually the simpler fix: don’t use “fill parent” for the background. Give the container `custom_minimum_size = get_logical_map_size()`. So `_background_layer_container.custom_minimum_size = get_logical_map_size()`. The container would then be 2560×1440. The display_rect fills the container. So we’d have a 2560×1440 display showing the baked texture. The baked texture is `logical_map_size * map_resolution_scale`. The TextureRect stretches it to fill. So we’d show the full map. The MapGenerator’s layout might clip—MapGenerator has size 1280×720 from its parent. A child with custom_minimum_size 2560×1440 would overflow. Control children can overflow; they just extend beyond the parent’s bounds. So we’d have a 2560×1440 background. When the camera views different regions, we’d see the correct parts. Good.

Set in `_setup_background_layer()` or `_resize_background_viewport()`:
```gdscript
_background_layer_container.custom_minimum_size = get_logical_map_size()
```
And ensure the display_rect/TextureRect fills the container. The container’s size will be at least logical_map_size. We need to also call this when we have world_scale—but get_logical_map_size uses size which may not be ready in _setup_background_layer. So we’d need to call _resize_background_viewport when size changes, and set the container’s custom_minimum_size there. Actually _resize_background_viewport already runs on NOTIFICATION_RESIZED. So in _resize_background_viewport we’d add:
```gdscript
if _background_layer_container:
    _background_layer_container.custom_minimum_size = get_logical_map_size()
```

### 2. CameraController2D.gd

#### Update `set_map_limits`
```gdscript
func set_map_limits(map_size: Vector2, zoom_max_min: Vector2 = Vector2(-1, -1)):
```
- If `zoom_max_min.x >= 0`: set `zoom_min = zoom_max_min.x`
- If `zoom_max_min.y >= 0`: set `zoom_max = zoom_max_min.y`
- When `zoom_max_min == Vector2(0.5, 1.0)`, zoom will be clamped to [0.5, 1.0].

#### “Fully zoomed out” semantics
Currently: `zoom.x == 1.0 and zoom.y == 1.0` → force center, disable pan.  
New: “fully zoomed out” = zoom at minimum (e.g. 0.5 for world_scale 2). Replace the literal `1.0` with `zoom_min`:

```gdscript
if zoom.x <= zoom_min + 0.001 and zoom.y <= zoom_min + 0.001:
```

(Use a small epsilon for float comparison.)

#### Initial zoom
When `set_map_limits` is called with new zoom bounds, if current zoom is outside [zoom_min, zoom_max], clamp it. Default to zoom = 1 if it’s in range (closest view), otherwise zoom_min (full map).

---

## Scene / Node Changes (Manual)

Per project rules, these are not edited by the AI. You must apply them manually.

### MapGenerator.tscn
1. **GameCamera node**
   - Set `zoom_min` = `0.5` (for world_scale 2; use 0.25 for world_scale 4).
   - Set `zoom_max` = `1.0`.
   - Note: Script will override these in `set_map_limits()` when you pass the zoom range. The scene values act as fallbacks before the first `set_map_limits` call.

2. **MapGenerator root**
   - Add `world_scale` property via the exported variable (will appear in Inspector when script is updated). Set to `2.0` (or 4.0) as desired.

---

## Systems to Verify (No Expected Code Changes)

| System | How it uses size/bounds | Expected behavior |
|--------|-------------------------|-------------------|
| **Party spawning** | Uses `map_nodes` positions | Positions already in logical space; should work |
| **Travel path** | Interpolates between node positions | Same |
| **Mouse/reveal** | `get_local_mouse_position` | Camera transforms; should remain correct |
| **MapDetails, frame** | Anchored to MapGenerator | May only cover part of logical map; consider keeping fixed to viewport |
| **ViewportFX** | Full rect overlay | Stays full rect; fine |
| **WaterOverlay** | Draws from passed data | Receives coords from bake; already in map space, will be logical |
| **EventWindow / node click** | Uses node positions | Should work |
| **LocationDetailDisplay** | Positioned in MapUI | Unchanged |

---

## Testing Checklist
- [ ] Map generates with nodes spread over logical map size.
- [ ] Zoom 1 shows a viewport-sized region at 1:1.
- [ ] Zoom out to zoom_min shows full map.
- [ ] Pan works when zoomed in; disabled when zoomed out.
- [ ] Node click, hover, travel, party spawn work.
- [ ] Static map bake covers full logical map.
- [ ] Background layer shows correct region when panning.
- [ ] WaterOverlay aligns with map.
- [ ] No regression when `world_scale = 1` (optional compatibility path).

---

## Rollback
A recent git commit exists. Use `git revert` or `git checkout` if needed.

---

## Compatibility
- `map_resolution_scale` stays as-is; it controls baking resolution.
- For `world_scale = 1`, logical_map_size = size; behavior matches current system (with zoom flipped: zoom 1 = closest, zoom_min would be 1 so no zoom-out).
