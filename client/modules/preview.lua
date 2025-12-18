local preview = {}

---Finish an emote preview
---Cleans up all preview entities (ped and props) to prevent memory leaks
function preview.finish()
    -- Delete all prop entities attached to the preview ped
    for i = 1, #preview.props do
        local entity = preview.props[i].entity

        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end

    -- Delete the preview ped itself
    DeleteEntity(preview.ped)
end

---Create the preview ped
---Creates either a cloned ped or a specific model (for animal emotes)
---@param previewModel? number Optional specific ped model (used for animal emotes)
---@return number ped The created preview ped entity
function preview.createPreviewPed(previewModel)
    local ped

    -- Create a specific ped model (for animal emotes) or clone the player's current ped
    if previewModel then
        local coords = GetEntityCoords(cache.ped)

        lib.requestModel(previewModel)

        ped = CreatePed(0, previewModel, coords.x, coords.y, coords.z, 0.0, false, false)

        SetModelAsNoLongerNeeded(previewModel)
    else
        -- Clone the player's ped to show how the emote looks on their character
        ped = ClonePed(cache.ped, false, false, true)
    end

    -- Configure the preview ped properties
    SetEntityCollision(ped, false, true) -- Disable collision so it doesn't block the player
    SetEntityInvincible(ped, true) -- Make it invincible so it can't be damaged
    SetBlockingOfNonTemporaryEvents(ped, true) -- Prevent the ped from reacting to events
    SetEntityAlpha(ped, 254, false) -- Make it slightly transparent (254/255) to indicate it's a preview

    -- Smoothing buffer to prevent jittery positioning
    local buffers = {}

    -- Continuous thread to update preview ped position and rotation
    CreateThread(function()
        while DoesEntityExist(ped) do
            Wait(0)

            -- Calculate world position from screen coordinates (0.65, 0.65 is slightly right and down from center)
            local worldVector, normalVector = GetWorldCoordFromScreenCoord(0.65, 0.65)
            -- Extend the ray 4 units into the world from the camera
            local buffer = worldVector + normalVector * 4.0
            local camRot = GetGameplayCamRot(2)

            -- Add new position to the buffer
            buffers[#buffers + 1] = buffer

            -- Keep only the last 5 positions for smoothing
            if #buffers > 5 then
                buffers = Utils.filterTable(buffers, function(_, index)
                    return index ~= 1
                end)
            end

            -- Calculate average position from all buffered positions for smooth movement
            local previewCoords = vec3(0.0, 0.0, 0.0)

            for i = 1, #buffers do
                previewCoords += buffers[i]
            end

            previewCoords = previewCoords / #buffers

            -- Update preview ped position and rotation to face the camera
            SetEntityCoords(ped, previewCoords.x, previewCoords.y, previewCoords.z)
            SetEntityRotation(ped, camRot.x * -1, 0.0, camRot.z + 180.0, 2, false) -- Rotate to face the player
        end
    end)

    return ped
end

---Preview an emote
---Main function that displays an emote preview with ped, props, and animations
---@param data table Emote data containing animation, props, and options
function preview.showEmote(data)
    -- Cleanup any existing preview first
    if preview.ped and DoesEntityExist(preview.ped) then
        preview.finish()
    end

    local previewModel

    -- For animal emotes, randomly select an appropriate animal model
    if data.PedTypes then
        local pedType = data.PedTypes[math.random(1, #data.PedTypes)]
        previewModel = PedTypes[pedType][math.random(1, #PedTypes[pedType])]
    end

    -- Increment preview ID to track multiple preview requests
    if not preview.id then preview.id = 0 end

    preview.id += 1

    local previewId = preview.id -- Store current ID to check if this is still the latest preview

    -- Create the preview ped and initialize props array
    preview.ped = preview.createPreviewPed(previewModel)
    preview.props = {}

    -- Initialize animation parameters
    local duration, movementFlag = nil, 0
    local dictionaryName, animationName = data.Dictionary, data.Animation

    -- Handle random animation selection if multiple animations are defined
    if type(dictionaryName) == 'table' and type(animationName) == 'table' then
        local randomIndex = math.random(1, #animationName)

        dictionaryName = dictionaryName[randomIndex]
        animationName = animationName[randomIndex]
    end

    -- Request and validate the animation dictionary
    local isValid = lib.requestAnimDict(dictionaryName)

    if not isValid then
        Utils.notify('error', locale('not_valid_emote'))
        DeleteEntity(preview.ped)
        return
    end

    -- Check NSFW permissions if emote is marked as NSFW
    if data.NSFW and Config.enableNSFWEmotes == 'limited' and not PlayerState.allowNSFWEmotes then
        Utils.notify('error', locale('nsfw_limited'))
        DeleteEntity(preview.ped)
        return
    end

    -- Process emote options (duration, flags, props, etc.)
    local options = data.Options

    if options then
        duration = options.duration

        -- Apply delay if specified
        if options.Delay then Wait(options.Delay) end

        -- Set movement flags based on emote requirements
        if options.Flags then
            -- Stuck (50): Frozen in place, Move (51): Can move, Loop (1): Animation loops
            movementFlag = options.Flags.Stuck and 50 or options.Flags.Move and 51 or options.Flags.Loop and 1 or movementFlag

            if options.Flags.Loop then
                lastEmote, lastVariant = data, variation
            end
        end

        -- Create and attach props if the emote has any
        if options.Props then
            -- Loop through all props and create them on the preview ped
            for i = 1, #options.Props do
                local prop = options.Props[i]
                
                -- Handle prop variations if specified
                if variation then
                    if prop.Variations and prop.Variations[variation] then
                        prop.Variant = prop.Variations[variation]
                    end
                end

                -- Prepare prop data for creation
                local previewProp = {
                    hash = joaat(prop.Name), -- Convert prop name to hash
                    bone = prop.Bone, -- Bone to attach to (e.g., hand, back)
                    placement = prop.Placement, -- Position and rotation offsets
                    variant = prop.Variant,
                    hasPtfx = options?.Ptfx?.AttachToProp -- Whether prop has particle effects
                }

                lib.requestModel(previewProp.hash)

                -- Create the prop object at preview ped location
                local previewCoords = GetEntityCoords(preview.ped)
                local object = CreateObject(previewProp.hash, previewCoords.x, previewCoords.y, previewCoords.z, false, false, false)

                -- Configure and attach the prop
                SetEntityCollision(object, false, false) -- Disable collision
                AttachEntityToEntity(object, preview.ped, GetPedBoneIndex(preview.ped, previewProp.bone), previewProp.placement[1].x, previewProp.placement[1].y, previewProp.placement[1].z, previewProp.placement[2].x, previewProp.placement[2].y, previewProp.placement[2].z, true, true, false, true, 1, true)
                SetEntityAlpha(object, 254, false) -- Match preview ped transparency
                SetModelAsNoLongerNeeded(previewProp.hash)

                -- Store prop reference for cleanup
                preview.props[i] = {
                    entity = object,
                    hasPtfx = previewProp.hasPtfx
                }
            end
        end
    end

    -- Play the main animation on the preview ped
    TaskPlayAnim(preview.ped, dictionaryName, animationName, 2.0, 2.0, duration or -1, movementFlag, 0, false, false, false)
    RemoveAnimDict(dictionaryName) -- Clean up animation dictionary from memory

    -- Handle secondary animations if the emote has one
    local secondaryEmote = options?.SecondaryEmote

    if secondaryEmote then
        local isSecondaryValid = lib.requestAnimDict(secondaryEmote.Dictionary, 1000)

        if not isSecondaryValid then
            Utils.notify('error', locale('not_valid_emote'))
            DeleteEntity(preview.ped)
            return
        end

        TaskPlayAnim(preview.ped, secondaryEmote.Dictionary, secondaryEmote.Animation, 2.0, 2.0, secondaryEmote.Duration or -1, 51, 0, false, false, false)
        RemoveAnimDict(secondaryEmote.Dictionary)
    end

    -- Auto-cleanup: Wait 5 seconds then remove the preview
    Wait(5000)

    -- Only cleanup if this is still the latest preview (prevents race condition)
    if previewId == preview.id then
        preview.finish()
    end
end

return preview