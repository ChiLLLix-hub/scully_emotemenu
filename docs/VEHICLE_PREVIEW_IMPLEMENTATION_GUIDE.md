# Vehicle Preview System - Complete Implementation Guide

## Overview

This guide provides everything you need to create a standalone vehicle preview system with rotation and color controls, based on the emote preview architecture. Use this to build your own FiveM resource from scratch.

---

## Project Setup

### 1. Create Resource Structure

```
vehicle_preview/
├── fxmanifest.lua
├── config.lua
├── client/
│   ├── main.lua
│   └── preview.lua
└── README.md
```

### 2. fxmanifest.lua

```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Your Name'
description 'Vehicle Preview System with Rotation and Color Controls'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/preview.lua',
    'client/main.lua'
}
```

### 3. config.lua

```lua
Config = {}

-- Preview positioning
Config.ScreenPosX = 0.65  -- Screen X coordinate (0.0 to 1.0)
Config.ScreenPosY = 0.65  -- Screen Y coordinate (0.0 to 1.0)
Config.Distance = 6.0     -- Distance from camera (units)
Config.BufferSize = 5     -- Smoothing buffer size

-- Preview appearance
Config.Transparency = 200 -- Entity alpha (0-255, lower = more transparent)
Config.PreviewDuration = 30000 -- Auto-cleanup timer (milliseconds)

-- Controls
Config.RotateLeftKey = 174   -- LEFT ARROW
Config.RotateRightKey = 175  -- RIGHT ARROW
Config.RotateSpeed = 2.0     -- Degrees per frame

-- Color presets (R, G, B)
Config.Colors = {
    {255, 0, 0},     -- Red (Key 1)
    {0, 255, 0},     -- Green (Key 2)
    {0, 0, 255},     -- Blue (Key 3)
    {255, 255, 0},   -- Yellow (Key 4)
    {255, 0, 255},   -- Magenta (Key 5)
    {0, 255, 255},   -- Cyan (Key 6)
    {255, 255, 255}, -- White (Key 7)
    {0, 0, 0},       -- Black (Key 8)
}

-- Key mappings for colors (157 = 1, 158 = 2, etc.)
Config.ColorKeys = {157, 158, 160, 164, 165, 159, 162, 163}
```

---

## Core Implementation

### 4. client/preview.lua - The Preview Engine

```lua
local VehiclePreview = {}
VehiclePreview.vehicle = nil
VehiclePreview.active = false
VehiclePreview.id = 0
VehiclePreview.manualRotation = 0.0
VehiclePreview.currentColorIndex = 1

---Cleanup and remove preview vehicle
function VehiclePreview.finish()
    if VehiclePreview.vehicle and DoesEntityExist(VehiclePreview.vehicle) then
        DeleteEntity(VehiclePreview.vehicle)
    end
    
    VehiclePreview.vehicle = nil
    VehiclePreview.active = false
    VehiclePreview.manualRotation = 0.0
end

---Create preview vehicle entity
---@param vehicleModel string|number Vehicle model name or hash
---@return number|nil vehicle The created vehicle entity
function VehiclePreview.createPreviewVehicle(vehicleModel)
    -- Get vehicle hash
    local vehicleHash = type(vehicleModel) == "string" and GetHashKey(vehicleModel) or vehicleModel
    
    -- Validate model
    if not IsModelValid(vehicleHash) or not IsModelAVehicle(vehicleHash) then
        print("^1[Vehicle Preview] Invalid vehicle model: " .. tostring(vehicleModel))
        return nil
    end
    
    -- Request model
    RequestModel(vehicleHash)
    local timeout = 0
    while not HasModelLoaded(vehicleHash) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end
    
    if not HasModelLoaded(vehicleHash) then
        print("^1[Vehicle Preview] Failed to load vehicle model")
        return nil
    end
    
    -- Get player position
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    
    -- Create vehicle
    local vehicle = CreateVehicle(vehicleHash, coords.x, coords.y, coords.z, 0.0, false, false)
    
    -- Configure vehicle properties
    SetEntityCollision(vehicle, false, false) -- Disable collision
    SetEntityInvincible(vehicle, true) -- Make invincible
    SetVehicleDoorsLocked(vehicle, 2) -- Lock doors
    FreezeEntityPosition(vehicle, true) -- Freeze position to prevent physics
    SetVehicleEngineOn(vehicle, false, true, true) -- Turn off engine
    SetEntityAlpha(vehicle, Config.Transparency, false) -- Set transparency
    SetVehicleNumberPlateText(vehicle, "PREVIEW") -- Set plate text
    
    -- Disable lights and extras
    SetVehicleLights(vehicle, 1) -- Force lights off
    SetVehicleInteriorlight(vehicle, false)
    
    -- Clean up model
    SetModelAsNoLongerNeeded(vehicleHash)
    
    return vehicle
end

-- Make VehiclePreview globally accessible for main.lua
_G.VehiclePreview = VehiclePreview

---Start positioning and control thread
---@param vehicle number The vehicle entity to control
---@param previewId number The preview ID for cleanup tracking
function VehiclePreview.startControlThread(vehicle, previewId)
    local buffers = {}
    
    CreateThread(function()
        while DoesEntityExist(vehicle) and VehiclePreview.active and VehiclePreview.id == previewId do
            Wait(0)
            
            -- Calculate position using camera raycast
            local screenX, screenY = Config.ScreenPosX, Config.ScreenPosY
            local worldVector, normalVector = GetWorldCoordFromScreenCoord(screenX, screenY)
            
            if worldVector and normalVector then
                -- Calculate position in front of camera
                local buffer = worldVector + normalVector * Config.Distance
                
                -- Add to smoothing buffer
                buffers[#buffers + 1] = buffer
                
                -- Maintain buffer size
                if #buffers > Config.BufferSize then
                    table.remove(buffers, 1)
                end
                
                -- Calculate average position
                local previewCoords = vector3(0.0, 0.0, 0.0)
                for i = 1, #buffers do
                    previewCoords = previewCoords + buffers[i]
                end
                previewCoords = previewCoords / #buffers
                
                -- Update vehicle position
                SetEntityCoords(vehicle, previewCoords.x, previewCoords.y, previewCoords.z, false, false, false, false)
                
                -- Apply rotation (manual rotation only, don't follow camera)
                SetEntityRotation(vehicle, 0.0, 0.0, VehiclePreview.manualRotation, 2, false)
            end
            
            -- Rotation controls
            if IsControlPressed(0, Config.RotateLeftKey) then
                VehiclePreview.manualRotation = VehiclePreview.manualRotation + Config.RotateSpeed
                if VehiclePreview.manualRotation >= 360.0 then
                    VehiclePreview.manualRotation = VehiclePreview.manualRotation - 360.0
                end
            elseif IsControlPressed(0, Config.RotateRightKey) then
                VehiclePreview.manualRotation = VehiclePreview.manualRotation - Config.RotateSpeed
                if VehiclePreview.manualRotation < 0.0 then
                    VehiclePreview.manualRotation = VehiclePreview.manualRotation + 360.0
                end
            end
            
            -- Color controls
            for i, keyCode in ipairs(Config.ColorKeys) do
                if IsControlJustPressed(0, keyCode) then
                    local color = Config.Colors[i]
                    if color then
                        SetVehicleCustomPrimaryColour(vehicle, color[1], color[2], color[3])
                        SetVehicleCustomSecondaryColour(vehicle, color[1], color[2], color[3])
                        VehiclePreview.currentColorIndex = i
                        
                        -- Show notification
                        SetNotificationTextEntry("STRING")
                        AddTextComponentString(string.format("Color: R:%d G:%d B:%d", color[1], color[2], color[3]))
                        DrawNotification(false, false)
                    end
                end
            end
        end
    end)
end

---Display on-screen controls help text
---@param previewId number The preview ID
function VehiclePreview.showControls(previewId)
    CreateThread(function()
        while VehiclePreview.active and VehiclePreview.id == previewId do
            Wait(0)
            
            -- Draw controls on screen
            SetTextFont(0)
            SetTextProportional(1)
            SetTextScale(0.35, 0.35)
            SetTextColour(255, 255, 255, 255)
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(1, 0, 0, 0, 255)
            SetTextDropShadow()
            SetTextOutline()
            SetTextEntry("STRING")
            AddTextComponentString("~b~Vehicle Preview~w~\n◄ ► Rotate | 1-8 Change Color | ESC Close")
            DrawText(0.5, 0.9)
        end
    end)
end

---Preview a vehicle with controls
---@param vehicleModel string|number Vehicle model name or hash
function VehiclePreview.show(vehicleModel)
    -- Cleanup any existing preview
    if VehiclePreview.active then
        VehiclePreview.finish()
    end
    
    -- Increment preview ID
    VehiclePreview.id = VehiclePreview.id + 1
    local previewId = VehiclePreview.id
    
    -- Create vehicle
    local vehicle = VehiclePreview.createPreviewVehicle(vehicleModel)
    
    if not vehicle then
        return
    end
    
    -- Set active state
    VehiclePreview.vehicle = vehicle
    VehiclePreview.active = true
    VehiclePreview.manualRotation = 0.0
    VehiclePreview.currentColorIndex = 1
    
    -- Apply default color
    local defaultColor = Config.Colors[1]
    if defaultColor then
        SetVehicleCustomPrimaryColour(vehicle, defaultColor[1], defaultColor[2], defaultColor[3])
        SetVehicleCustomSecondaryColour(vehicle, defaultColor[1], defaultColor[2], defaultColor[3])
    end
    
    -- Start control thread
    VehiclePreview.startControlThread(vehicle, previewId)
    
    -- Show controls
    VehiclePreview.showControls(previewId)
    
    -- Auto-cleanup timer
    SetTimeout(Config.PreviewDuration, function()
        if VehiclePreview.id == previewId then
            VehiclePreview.finish()
        end
    end)
    
    -- Show notification
    SetNotificationTextEntry("STRING")
    AddTextComponentString("Vehicle preview started! Use arrow keys to rotate, 1-8 for colors.")
    DrawNotification(false, false)
end
```

---

### 5. client/main.lua - Commands and Usage

```lua
-- VehiclePreview is globally accessible from preview.lua
-- No require needed in FiveM

-- Command to preview a vehicle
RegisterCommand('previewvehicle', function(source, args, rawCommand)
    if #args < 1 then
        print("^1Usage: /previewvehicle <vehicle_model>")
        print("^3Example: /previewvehicle adder")
        return
    end
    
    local vehicleModel = args[1]
    VehiclePreview.show(vehicleModel)
end, false)

-- Command to close preview
RegisterCommand('closepreview', function(source, args, rawCommand)
    VehiclePreview.finish()
    
    SetNotificationTextEntry("STRING")
    AddTextComponentString("Vehicle preview closed.")
    DrawNotification(false, false)
end, false)

-- Close preview on ESC key
CreateThread(function()
    while true do
        Wait(0)
        
        if VehiclePreview.active then
            -- Check for ESC key (322 = ESC)
            if IsControlJustPressed(0, 322) then
                VehiclePreview.finish()
            end
        end
    end
end)

-- Export functions for other resources
exports('showVehiclePreview', function(vehicleModel)
    VehiclePreview.show(vehicleModel)
end)

exports('closeVehiclePreview', function()
    VehiclePreview.finish()
end)

exports('isPreviewActive', function()
    return VehiclePreview.active
end)
```

---

## Usage Examples

### In-Game Commands

```
/previewvehicle adder          # Preview an Adder
/previewvehicle t20            # Preview a T20
/previewvehicle insurgent      # Preview an Insurgent
/closepreview                  # Close the preview
```

### From Another Resource

```lua
-- Show preview
exports['vehicle_preview']:showVehiclePreview('zentorno')

-- Close preview
exports['vehicle_preview']:closeVehiclePreview()

-- Check if preview is active
local isActive = exports['vehicle_preview']:isPreviewActive()
```

### Integration with Menu Systems

```lua
-- Example: ox_lib menu integration
lib.registerMenu({
    id = 'vehicle_preview_menu',
    title = 'Vehicle Preview',
    options = {
        {
            label = 'Adder',
            description = 'Preview Adder',
        },
        {
            label = 'Zentorno',
            description = 'Preview Zentorno',
        },
        {
            label = 'T20',
            description = 'Preview T20',
        }
    }
}, function(selected, scrollIndex, args)
    local vehicles = {'adder', 'zentorno', 't20'}
    exports['vehicle_preview']:showVehiclePreview(vehicles[selected])
end)
```

---

## Controls Reference

| Key | Action |
|-----|--------|
| **← (Left Arrow)** | Rotate vehicle left |
| **→ (Right Arrow)** | Rotate vehicle right |
| **1** | Red color |
| **2** | Green color |
| **3** | Blue color |
| **4** | Yellow color |
| **5** | Magenta color |
| **6** | Cyan color |
| **7** | White color |
| **8** | Black color |
| **ESC** | Close preview |

---

## Advanced Customization

### Custom Color Picker

Add this to `client/preview.lua`:

```lua
---Set custom RGB color
---@param r number Red (0-255)
---@param g number Green (0-255)
---@param b number Blue (0-255)
function VehiclePreview.setCustomColor(r, g, b)
    if VehiclePreview.vehicle and DoesEntityExist(VehiclePreview.vehicle) then
        SetVehicleCustomPrimaryColour(VehiclePreview.vehicle, r, g, b)
        SetVehicleCustomSecondaryColour(VehiclePreview.vehicle, r, g, b)
    end
end
```

Export it in `client/main.lua`:

```lua
exports('setPreviewColor', function(r, g, b)
    VehiclePreview.setCustomColor(r, g, b)
end)
```

### Zoom Controls

Add to the control thread in `client/preview.lua`:

```lua
-- Zoom in/out (Mouse scroll)
if IsControlPressed(0, 241) then -- Scroll up
    Config.Distance = math.max(3.0, Config.Distance - 0.1)
elseif IsControlPressed(0, 242) then -- Scroll down
    Config.Distance = math.min(15.0, Config.Distance + 0.1)
end
```

### Save/Load Configurations

```lua
---Save current configuration
function VehiclePreview.saveConfig()
    if not VehiclePreview.vehicle then return end
    
    local r, g, b = GetVehicleCustomPrimaryColour(VehiclePreview.vehicle)
    
    return {
        rotation = VehiclePreview.manualRotation,
        color = {r, g, b},
        distance = Config.Distance
    }
end

---Load configuration
function VehiclePreview.loadConfig(config)
    if not VehiclePreview.vehicle or not config then return end
    
    VehiclePreview.manualRotation = config.rotation or 0.0
    
    if config.color then
        SetVehicleCustomPrimaryColour(VehiclePreview.vehicle, config.color[1], config.color[2], config.color[3])
        SetVehicleCustomSecondaryColour(VehiclePreview.vehicle, config.color[1], config.color[2], config.color[3])
    end
    
    if config.distance then
        Config.Distance = config.distance
    end
end
```

---

## Troubleshooting

### Preview not appearing
- Check console for error messages
- Verify vehicle model name is correct
- Ensure model is loaded (`HasModelLoaded()`)
- Check if player is in interior (may affect raycasting)

### Controls not working
- Verify control IDs match your game version
- Check for conflicting keybinds
- Ensure `VehiclePreview.active` is true

### Vehicle appears in wrong location
- Adjust `Config.ScreenPosX` and `Config.ScreenPosY`
- Increase `Config.Distance` for larger vehicles
- Check camera angle (raycasting requires line of sight)

### Transparency not working
- Some vehicle models don't support alpha
- Try different `Config.Transparency` values (50-254)
- Check for model-specific rendering issues

---

## Performance Optimization

### Reduce CPU Usage

1. **Increase Wait time** in control thread (trade responsiveness for performance):
```lua
Wait(10) -- Instead of Wait(0)
```

2. **Limit buffer updates**:
```lua
local frameCount = 0
if frameCount % 2 == 0 then -- Update every 2 frames
    -- Position calculation
end
frameCount = frameCount + 1
```

3. **Disable when not in use**:
```lua
if not VehiclePreview.active then
    Wait(500) -- Sleep longer when inactive
end
```

---

## Building Prompts for AI Assistance

### Prompt 1: Basic Implementation
```
Create a FiveM vehicle preview system that:
1. Spawns a semi-transparent vehicle in front of the player's camera
2. Uses screen-to-world raycasting for positioning (screen coords 0.65, 0.65)
3. Implements a 5-position smoothing buffer for stable positioning
4. Disables collision and physics on the preview vehicle
5. Auto-cleanup after 30 seconds

Include fxmanifest.lua, config, and client-side implementation.
```

### Prompt 2: Add Controls
```
Extend the vehicle preview system with:
1. Arrow key rotation (left/right, 2 degrees per frame)
2. Number key color presets (1-8 for different RGB colors)
3. ESC key to close preview
4. On-screen help text showing controls
5. Track manual rotation separately from camera rotation

Maintain smooth positioning while adding controls.
```

### Prompt 3: Advanced Features
```
Add advanced features to vehicle preview:
1. Mouse scroll zoom (distance 3-15 units)
2. Custom RGB color picker function
3. Save/load configuration (rotation, color, distance)
4. Export functions for other resources
5. Menu system integration example

Keep the architecture modular and documented.
```

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Vehicle Preview System                   │
└─────────────────────────────────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
   ┌─────────┐      ┌──────────┐      ┌──────────┐
   │ Config  │      │ Preview  │      │   Main   │
   │         │      │  Engine  │      │ Commands │
   └─────────┘      └──────────┘      └──────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
        ▼                 ▼                 ▼
  ┌──────────┐    ┌──────────┐     ┌──────────┐
  │Position  │    │ Controls │     │ Cleanup  │
  │ Thread   │    │  Thread  │     │  Timer   │
  └──────────┘    └──────────┘     └──────────┘
        │                 │                 │
        └─────────────────┴─────────────────┘
                          │
                          ▼
                  ┌──────────────┐
                  │   Vehicle    │
                  │   Entity     │
                  └──────────────┘
```

---

## Best Practices

1. **Always validate models** before creating vehicles
2. **Use preview IDs** to prevent race conditions
3. **Clean up entities** properly to avoid memory leaks
4. **Freeze vehicle position** to prevent physics glitches
5. **Disable collision** to prevent blocking players
6. **Set transparency** to indicate preview state
7. **Limit buffer size** for performance
8. **Handle edge cases** (interiors, camera angles, etc.)

---

## Testing Checklist

- [ ] Preview spawns correctly
- [ ] Rotation controls work smoothly
- [ ] Color changes apply properly
- [ ] ESC key closes preview
- [ ] Auto-cleanup works after timeout
- [ ] Multiple previews don't conflict
- [ ] Works in different camera modes
- [ ] No memory leaks after extended use
- [ ] Controls don't conflict with other resources
- [ ] Performance is acceptable (check with `/resmon`)

---

## Credits & License

Based on the emote preview system architecture from `scully_emotemenu`.

**Core Concepts:**
- Camera raycasting positioning
- Smoothing buffer algorithm
- Entity management pattern
- Control thread architecture

Feel free to modify and extend for your needs!
