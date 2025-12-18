# Emote Preview System - Quick Reference

## What is it?
The preview system shows what an emote looks like **before** you play it on your character, making it easier to find the right emote.

## How to Use
1. Open emote menu (default: **F5** or **/em**)
2. Navigate to any emote
3. **Hold E key** while selecting an emote
4. Preview appears in front of you showing the emote
5. Preview automatically disappears after 5 seconds

## Key Files

| File | Purpose |
|------|---------|
| `client/modules/preview.lua` | Main preview system logic |
| `client/menu.lua` | Menu integration (triggers preview) |
| `shared/data/config.lua` | Preview enable/disable setting |
| `scully_emotemenu.cfg` | Configuration file |

## Main Functions

### `preview.showEmote(data)`
**Location**: `client/modules/preview.lua` (Line 78)
- **What**: Main function that displays the preview
- **Input**: Emote data table
- **Does**: Creates preview ped, plays animation, manages props, auto-cleanup after 5 seconds

### `preview.createPreviewPed(previewModel)`
**Location**: `client/modules/preview.lua` (Line 23)
- **What**: Creates the preview character model
- **Input**: Optional specific ped model (for animal emotes)
- **Does**: Clones player's ped or creates specific model, positions it in front of camera

### `preview.finish()`
**Location**: `client/modules/preview.lua` (Line 5)
- **What**: Cleanup function
- **Does**: Deletes preview ped and all attached props

## How It Works (Simple)

```
1. Player holds E + selects emote
   ↓
2. Check if preview is enabled
   ↓
3. Create preview ped (clone of player)
   ↓
4. Position ped in front of camera view
   ↓
5. Load and play animation
   ↓
6. Create and attach props (if any)
   ↓
7. Wait 5 seconds
   ↓
8. Auto-cleanup and delete preview
```

## Key Features

### Positioning
- Preview appears at screen coordinates (0.65, 0.65) - slightly right and down from center
- Uses **smoothing buffer** (last 5 positions averaged) for smooth movement
- Follows camera rotation to always face the player

### Entity Properties
- **Collision**: Disabled (doesn't block player)
- **Transparency**: 254/255 (slightly see-through)
- **Invincible**: Yes (can't be damaged)
- **Duration**: 5 seconds auto-cleanup

### Supported Features
- ✅ Regular emotes
- ✅ Prop emotes (items like phones, drinks)
- ✅ Animal emotes (shows random animal model)
- ✅ Animations with variants
- ✅ Secondary animations
- ✅ NSFW permission checks

## Configuration

**File**: `scully_emotemenu.cfg`

```cfg
setr scully_emotemenu:enableEmotePreview "true"
```

**Values**:
- `"true"` = Preview enabled
- `"false"` = Preview disabled

## Code Locations

### Preview Trigger (Menu)
**File**: `client/menu.lua`

**Main Menu**: Lines 292-297
```lua
if Config.enableEmotePreview and IsControlPressed(0, 38) then
    preview.showEmote(args.emotes[scrollIndex])
    return
end
PlayEmote(args.emotes[scrollIndex])
```

**Search Menu**: Lines 205-210
```lua
if Config.enableEmotePreview and IsControlPressed(0, 38) then
    preview.showEmote(args.emotes[scrollIndex])
    return
end
PlayEmote(args.emotes[scrollIndex])
```

### Control ID
- **E Key** = Control ID 38
- Check: `IsControlPressed(0, 38)`

## Important Variables

| Variable | Purpose | Location |
|----------|---------|----------|
| `preview.ped` | The preview ped entity | `preview.lua` |
| `preview.props` | Array of prop entities | `preview.lua` |
| `preview.id` | Preview ID counter (prevents conflicts) | `preview.lua` |
| `Config.enableEmotePreview` | Enable/disable setting | `config.lua` |

## Performance Notes

✅ **Good Practices**:
- Models freed with `SetModelAsNoLongerNeeded()`
- Animation dictionaries removed with `RemoveAnimDict()`
- Automatic cleanup after 5 seconds
- Preview ID system prevents conflicts
- Position buffer limited to 5 entries

⚠️ **Limitations**:
- Only 1 preview at a time
- Preview visible only to you (client-side)
- Cannot interact with preview ped
- 5-second maximum duration

## Troubleshooting

**Preview not showing?**
1. Check if `enableEmotePreview` is `"true"` in config
2. Make sure you're **holding** E key, not just pressing
3. Verify the animation dictionary exists

**Preview appears in wrong location?**
- This is normal - it appears at screen coordinates (0.65, 0.65)
- Move your camera to adjust where it appears
- The ped will follow your camera smoothly

**Preview stays too long?**
- Auto-cleanup happens after 5 seconds (hardcoded)
- New preview will replace old one automatically

## For Developers

### Adding Preview to Custom Menu
```lua
local preview = require 'client.modules.preview'

-- In your menu callback
if Config.enableEmotePreview and IsControlPressed(0, 38) then
    preview.showEmote(yourEmoteData)
    return
end
-- ... normal emote play logic
```

### Emote Data Structure
```lua
{
    Label = "Dance",
    Command = "dance",
    Dictionary = "anim@amb@nightclub@dancers@...",
    Animation = "dance_hi_11_v2_male^1",
    Options = {
        Flags = { Loop = true },
        Props = { ... },  -- Optional
        SecondaryEmote = { ... }  -- Optional
    },
    PedTypes = { 'small_dogs' }  -- Optional (for animals)
}
```

## Related Documentation
- Full documentation: `docs/EMOTE_PREVIEW_SYSTEM.md`
- Emote structure: Check emote files in `shared/data/emotes/`
- Config options: `scully_emotemenu.cfg`
