# Emote Preview System Documentation

## Overview

The emote preview system in `scully_emotemenu` allows players to preview what an emote looks like before actually playing it on their character. This feature makes it easier for players to find and select the right emote without having to try each one individually.

## How It Works

### Activation
Players can preview an emote by:
1. Opening the emote menu (default: F5 or `/em` command)
2. Navigating to any emote category
3. **Holding the E key (Control ID: 38)** while selecting an emote

When the preview is triggered, instead of playing the emote on the player's character, a preview ped (character model) appears in front of the player showing the emote.

### Configuration
The preview system can be enabled/disabled via the configuration file:
- **Config File**: `scully_emotemenu.cfg`
- **Setting**: `setr scully_emotemenu:enableEmotePreview "true"`
- **Values**: `"true"` to enable, `"false"` to disable

## Core Components

### 1. Preview Module (`client/modules/preview.lua`)

This is the main script that controls the entire preview functionality. It contains three primary functions:

#### **Function: `preview.finish()`**
- **Purpose**: Cleans up and removes the preview when it's done
- **What it does**:
  - Deletes all prop entities attached to the preview ped
  - Deletes the preview ped itself
  - Ensures no entities are left behind after preview

#### **Function: `preview.createPreviewPed(previewModel)`**
- **Purpose**: Creates the preview character model that displays the emote
- **Parameters**: 
  - `previewModel` (optional): Specific ped model to use for preview (used for animal emotes)
- **How it works**:
  1. **Ped Creation**:
     - If a specific model is provided (e.g., for animal emotes), it creates a new ped with that model
     - Otherwise, it clones the player's current ped to show how the emote looks on them
  
  2. **Ped Configuration**:
     - Disables collision so the preview ped doesn't block the player
     - Makes the ped invincible so it can't be damaged
     - Blocks temporary events so the ped stays in the emote
     - Sets transparency to 254 (slightly transparent)
  
  3. **Positioning System**:
     - Creates a continuous thread that updates the preview ped's position
     - Uses camera raycasting to position the ped in front of the player's view
     - Calculates position using `GetWorldCoordFromScreenCoord(0.65, 0.65)` - places it slightly right and down from center screen
     - Implements a **smoothing buffer** system:
       - Stores the last 5 position calculations
       - Averages these positions to create smooth movement
       - Prevents jittery or jumpy preview positioning
  
  4. **Rotation**:
     - Rotates the preview ped to face the player's camera
     - Uses inverted camera rotation for proper facing direction
     - Adds 180 degrees to the camera's Z rotation so the ped faces the player

#### **Function: `preview.showEmote(data)`**
- **Purpose**: Main function that displays the emote preview
- **Parameters**: 
  - `data`: The emote data table containing all emote information
- **Complete Workflow**:

  1. **Cleanup Previous Preview**:
     - Checks if a preview already exists and removes it
  
  2. **Model Selection**:
     - For animal emotes (with `PedTypes`), randomly selects an appropriate animal model
     - For regular emotes, uses the player's current character model
  
  3. **Preview ID Tracking**:
     - Increments a preview ID counter
     - Used to prevent multiple previews from interfering with each other
     - Ensures only the latest preview can clean itself up
  
  4. **Ped Creation**:
     - Creates the preview ped using `createPreviewPed()`
     - Initializes an empty props table
  
  5. **Animation Dictionary Handling**:
     - Handles both single animations and random animation arrays
     - For arrays, randomly selects one animation from the list
     - Requests and loads the animation dictionary from the game
  
  6. **Validation**:
     - Verifies the animation dictionary exists
     - For NSFW emotes with "limited" mode, checks player permissions
     - Deletes preview ped and shows error if validation fails
  
  7. **Options Processing**:
     - **Duration**: Sets how long the animation plays
     - **Delay**: Waits specified time before starting
     - **Movement Flags**: Determines if player can move during emote
       - Stuck (50): Character frozen in place
       - Move (51): Can move while doing emote
       - Loop (1): Animation loops continuously
  
  8. **Props Creation**:
     - If emote has props (items like phones, drinks, etc.):
       - Loads the prop model
       - Creates the prop object
       - Disables collision on the prop
       - Attaches prop to the correct bone on the preview ped
       - Uses placement coordinates and rotation from emote data
       - Sets prop transparency to match preview ped
       - Stores prop reference for cleanup
  
  9. **Animation Playback**:
     - Plays the main animation on the preview ped
     - Applies movement flags and duration
     - Removes animation dictionary from memory after starting
  
  10. **Secondary Emote**:
      - Some emotes have secondary animations
      - Loads and plays the secondary animation if it exists
  
  11. **Auto-Cleanup Timer**:
      - Waits 5 seconds (5000 milliseconds)
      - After 5 seconds, checks if this is still the latest preview
      - If yes, automatically cleans up and removes the preview
      - This prevents previews from staying visible indefinitely

### 2. Menu Integration (`client/menu.lua`)

The preview system is integrated into the menu at two key points:

#### **Main Emote Menu** (Lines 292-294)
```lua
if Config.enableEmotePreview and IsControlPressed(0, 38) then
    preview.showEmote(args.emotes[scrollIndex])
    return
end
```
- Checks if preview is enabled in config
- Checks if E key (Control 38) is pressed
- Shows preview instead of playing the emote
- Returns early to prevent emote from playing on player

#### **Search Results Menu** (Lines 205-208)
```lua
if Config.enableEmotePreview and IsControlPressed(0, 38) then
    preview.showEmote(args.emotes[scrollIndex])
    return
end
```
- Same logic applies when searching for emotes
- Ensures preview works in search results too

#### **Menu Option Descriptions**
The menu shows "Hold E and select to preview" in the emote descriptions (Lines 140, 181):
```lua
description = ('/%s %s - %s'):format(command, emote.Command, locale('hold_to_preview'))
```

### 3. Configuration (`shared/data/config.lua`)

```lua
enableEmotePreview = GetConvar('scully_emotemenu:enableEmotePreview', 'true') == 'true'
```
- Reads the preview setting from the server configuration
- Defaults to `true` if not specified
- Can be changed in `scully_emotemenu.cfg`

## Technical Details

### Positioning Algorithm

The preview positioning uses a sophisticated smoothing system:

1. **Ray Casting**:
   - `GetWorldCoordFromScreenCoord(0.65, 0.65)` casts a ray from screen coordinates
   - Screen coords 0.65, 0.65 is slightly right and down from center (center is 0.5, 0.5)
   - Ray extends 4 units (`* 4.0`) into the world from the camera

2. **Smoothing Buffer**:
   - Maintains array of last 5 position calculations
   - Adds new position to buffer each frame
   - Removes oldest position when buffer exceeds 5 entries
   - Calculates average of all buffered positions
   - This creates smooth movement without jitter

3. **Rotation**:
   - Gets camera rotation with `GetGameplayCamRot(2)`
   - Inverts X rotation (`camRot.x * -1`) for proper pitch
   - Adds 180° to Z rotation (`camRot.z + 180.0`) so ped faces camera

### Entity Management

The preview system carefully manages entities to prevent memory leaks:

1. **Props Array**: Stores all prop entities for cleanup
2. **Preview ID System**: Prevents race conditions when switching previews quickly
3. **Auto-Cleanup**: 5-second timer ensures previews don't persist
4. **Collision**: Disabled on both ped and props to prevent physics issues
5. **Transparency**: Set to 254 (not 255) to make it clear this is a preview

### Control Flow

```
Player Opens Menu
    ↓
Player Hovers Over Emote
    ↓
Player Holds E Key
    ↓
Check if Preview Enabled (Config)
    ↓
Get Emote Data
    ↓
Cleanup Any Existing Preview
    ↓
Create Preview Ped (clone or specific model)
    ↓
Load Animation Dictionary
    ↓
Validate Animation & Permissions
    ↓
Process Emote Options (duration, flags, etc.)
    ↓
Create and Attach Props (if any)
    ↓
Play Animation on Preview Ped
    ↓
Play Secondary Animation (if any)
    ↓
Wait 5 Seconds
    ↓
Auto-Cleanup Preview
```

## Special Cases

### Animal Emotes
- Emotes with `PedTypes` defined will use a random animal model
- Randomly selects from the specified animal categories
- Shows what the emote looks like on different creatures

### NSFW Emotes
- If NSFW mode is set to "limited"
- Checks player's `allowNSFWEmotes` state
- Prevents preview if player doesn't have permission

### Prop Emotes
- Props are fully rendered in previews
- Attached to correct bone with proper placement
- Support prop variations (variant system)
- Match the transparency of the preview ped

### Synchronized Emotes
- Preview only shows the player's portion
- Doesn't show the other player's animation
- Still useful for seeing what your character will do

## User Experience

### Visual Feedback
1. **Semi-transparent ped**: Makes it clear this is a preview, not a real character
2. **Positioned in view**: Appears where player is looking
3. **Smooth movement**: Follows camera smoothly without jitter
4. **Automatic cleanup**: Disappears after 5 seconds automatically

### Menu Instructions
- Every emote shows "Hold E and select to preview"
- Available in all supported languages through locale system
- Works in both main menu and search results

## Performance Considerations

1. **Entity Cleanup**: Ensures all preview entities are deleted properly
2. **Model Memory**: Uses `SetModelAsNoLongerNeeded()` after creating entities
3. **Animation Cleanup**: Removes animation dictionaries with `RemoveAnimDict()`
4. **Thread Management**: Preview positioning thread stops when ped is deleted
5. **Buffer Limit**: Position buffer limited to 5 entries to prevent memory growth

## Limitations

1. **Single Preview**: Only one preview can be active at a time
2. **5-Second Duration**: Preview automatically closes after 5 seconds
3. **No Interaction**: Preview ped cannot be interacted with (collision disabled)
4. **Client-Side Only**: Preview is only visible to the player previewing

## Summary

The emote preview system is a well-designed feature that:
- Provides visual feedback before committing to an emote
- Uses efficient entity management and cleanup
- Integrates seamlessly with the menu system
- Supports all emote types including props, animals, and special animations
- Offers smooth positioning through buffered calculations
- Respects configuration settings and player permissions

The core script (`client/modules/preview.lua`) handles all the heavy lifting, while the menu system (`client/menu.lua`) provides the user interface integration through simple control checks.
