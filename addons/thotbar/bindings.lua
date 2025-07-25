-- bindings is a root tablee to manage all hotkey configs
-- GlobalBindings is empty T{} intended to hold hotkey configs for all jobs
-- JobBindings is a T{} with two more T{} nested. Default holds Job scope hotkeys. Palettes hold palette scope hotkeys
local bindings = {
    GlobalBindings = T{},
    JobBindings = T{
        Default = T{},
        Palettes = T{ { Name="Base", Bindings = T{} } }
    },
};


bindings.ActivePalette = bindings.JobBindings.Palettes[1]; -- ActivePalette set as the first Palette in list "Base"
bindings.ActivePaletteIndex = 1; -- Storing the index of the currently active palette
bindings.LastPaletteIndex = 1; -- Storing the last/previous active palette index 


-- Write Binding is used to write out a singlee hotkey binding. 
local function WriteBinding(writer, depth, hotkey, binding)

    -- pad variables used to make file more human readable. Each one is different depth of spaces on each line.
    local pad1 = string.rep(' ', depth);
    local pad2 = string.rep(' ', depth + 4);
    local pad3 = string.rep(' ', depth + 8);

    writer:write(string.format('%s[%q] = {\n', pad1, hotkey)); -- Writes hotkey string to file exactly as it is %s with quotes and brackets [%q]. 

    depth = depth + 4;

    writer:write(string.format('%sActionType              = \'%s\',\n', pad2, binding.ActionType)); -- Writes the action type spell/ability.. on the next line with a futher indent.
    if T{'Ability', 'Item', 'Spell', 'Trust', 'Weaponskill'}:contains(binding.ActionType) then -- Contains a method of T{} called contains to confirm valid Action Type
        writer:write(string.format('%sId                      = %u,\n', pad2, binding.Id)); -- Writes binding.Id to to file unsigned integer
    end
    writer:write(string.format('%sMacro                   = T{\n', pad2)); -- Writes line to file that declars a T{} named Macro
    for _,line in ipairs(binding.Macro) do
        writer:write(string.format('%s%q,\n', pad3, line)); -- Writes each entry of the binding.Macro list
    end
    writer:write(string.format('%s},\n', pad2)); -- This writes the closing brace on the next line

    if (binding.CostOverride ~= nil) then
        writer:write(string.format('%sCostOverride            = T{ ', pad2)); -- Writes the line of "CostOverride" to the file and the opening of T{}
        local first = true;
        for _,id in ipairs(binding.CostOverride) do
            if not first then
                writer:write(', '); -- Adds comma after each id if not the first id in the T{}
            end
            writer:write(tostring(id)); -- Writes the id as entry to T{}
            first = false;
        end
        writer:write(' },\n');
    end

    -- These write functions write a new line for each binding value. The lines with booleans are written as "A and B or C"
    writer:write(string.format('%sLabel                   = %q,\n', pad2, binding.Label));
    writer:write(string.format('%sImage                   = %q,\n', pad2, binding.Image));
    writer:write(string.format('%sShowCost                = %s,\n', pad2, binding.ShowCost and 'true' or 'false'));
    writer:write(string.format('%sShowCross               = %s,\n', pad2, binding.ShowCross and 'true' or 'false'));
    writer:write(string.format('%sShowFade                = %s,\n', pad2, binding.ShowFade and 'true' or 'false'));
    writer:write(string.format('%sShowRecast              = %s,\n', pad2, binding.ShowRecast and 'true' or 'false'));
    writer:write(string.format('%sShowName                = %s,\n', pad2, binding.ShowName and 'true' or 'false'));
    writer:write(string.format('%sShowTrigger             = %s,\n', pad2, binding.ShowTrigger and 'true' or 'false'));
    writer:write(string.format('%sShowSkillchainIcon      = %s,\n', pad2, binding.ShowSkillchainIcon and 'true' or 'false'));
    writer:write(string.format('%sShowSkillchainAnimation = %s,\n', pad2, binding.ShowSkillchainAnimation and 'true' or 'false'));
    writer:write(string.format('%sShowHotkey              = %s,\n', pad2, binding.ShowHotkey and 'true' or 'false'));
    writer:write(string.format('%s},\n', pad1));
end

local function WriteGlobals(globalBindings)
    local writer = io.open(bindings.GlobalPath, 'w');
    writer:write('return T{\n');
    for hotkey,binding in pairs(bindings.GlobalBindings) do
        WriteBinding(writer, 4, hotkey, binding);
    end
    writer:write('};');
    writer:close();
end

local function WriteJob(jobBindings)
    local writer = io.open(bindings.JobPath, 'w');
    writer:write('return T{\n');
    writer:write('    Default = T{\n');
    for hotkey,binding in pairs(bindings.JobBindings.Default) do
        WriteBinding(writer, 8, hotkey, binding);
    end
    writer:write('    },\n');
    writer:write('    Palettes = T{\n');
    for _,palette in ipairs(bindings.JobBindings.Palettes) do
        writer:write(string.format('        { Name=%q, Bindings = T{\n', palette.Name));
        for hotkey,binding in pairs(palette.Bindings) do
            WriteBinding(writer, 12, hotkey, binding);
        end
        writer:write('        } },\n');
    end
    writer:write('    },\n');
    writer:write('};');
    writer:close();
end

local function ApplyBindings()
    if (gDisplay == nil) then
        return;
    end

    local output = {};
    for hotkey,binding in pairs(bindings.ActivePalette.Bindings) do
        output[hotkey] = binding;
        binding.Scope = 3;
    end

    for hotkey,binding in pairs(bindings.JobBindings.Default) do
        if (output[hotkey] == nil) then
            output[hotkey] = binding;
            binding.Scope = 2;
        end
    end

    for hotkey,binding in pairs(bindings.GlobalBindings) do
        if  (output[hotkey] == nil) then
            output[hotkey] = binding;
            binding.Scope = 1;
        end
    end

    gDisplay:UpdateBindings(output);
end

local exposed = {};

function exposed:LoadDefaults(name, id, job)
    if (name == '') or (id == 0) then
        bindings = {
            GlobalBindings = T{},
            JobBindings = T{
                Default = T{},
                Palettes = T{ { Name="Base", Bindings = T{} } }
            }
        };
        bindings.ActivePalette = bindings.JobBindings.Palettes[1];
        bindings.ActivePaletteIndex = 1;
        bindings.LastPaletteIndex = 1;
        ApplyBindings();
        return;
    end

    --Check/Create binding folder..
    local characterPath = string.format('%sconfig/addons/%s/%s_%u/bindings', AshitaCore:GetInstallPath(), addon.name, name, id);
    if not (ashita.fs.exists(characterPath)) then
        ashita.fs.create_directory(characterPath);
    end

    --Check/Create global file..
    bindings.GlobalPath = string.format('%s/globals.lua', characterPath);
    bindings.GlobalBindings = LoadFile_s(bindings.GlobalPath);
    if (bindings.GlobalBindings == nil) then
        bindings.GlobalBindings = T{};        
        if not (ashita.fs.exists(bindings.GlobalPath)) then
            WriteGlobals();
        end
    end

    --Check/Create job file..
    bindings.JobPath = string.format('%s/%s.lua', characterPath, AshitaCore:GetResourceManager():GetString('jobs.names_abbr', job));
    bindings.JobBindings = LoadFile_s(bindings.JobPath);

    if (bindings.JobBindings == nil) then
        bindings.JobBindings = T{
            Default = T{},
            Palettes = T{
                { Name = 'Base', Bindings = T{} },
            }
        };

        if not (ashita.fs.exists(bindings.JobPath)) then
            WriteJob();
        end
    end

    if (type(bindings.JobBindings.Palettes) ~= 'table') or (#bindings.JobBindings.Palettes == 0) then
        bindings.JobBindings.Palettes = T{
            { Name = 'Base', Bindings = T{} },
        };
    end

    --Fill in hotkey setting..
    for _,palette in ipairs(bindings.JobBindings.Palettes) do
        for _,binding in pairs(palette.Bindings) do
            if (binding.Hotkey == nil) then
                binding.Hotkey = true;
            end
        end
    end
    
    for _,binding in pairs(bindings.JobBindings.Default) do
        if (binding.Hotkey == nil) then
            binding.Hotkey = true;
        end
    end
    
    for _,binding in pairs(bindings.GlobalBindings) do
        if (binding.Hotkey == nil) then
            binding.Hotkey = true;
        end
    end

    bindings.ActivePalette = bindings.JobBindings.Palettes[1];
    bindings.ActivePaletteIndex = 1;
    bindings.LastPaletteIndex = 1;
    ApplyBindings();
end

--[[
    /tb palette [add/change/remove/list/next/previous] [name]
]]--

function exposed:BindGlobal(hotkey, binding)
    bindings.GlobalBindings[hotkey] = binding;
    WriteGlobals();
    ApplyBindings();
end

function exposed:BindJob(hotkey, binding)
    bindings.JobBindings.Default[hotkey] = binding;
    WriteJob();
    ApplyBindings();
end

function exposed:BindPalette(hotkey, binding)
    bindings.ActivePalette.Bindings[hotkey] = binding;
    WriteJob();
    ApplyBindings();
end

function exposed:GetDisplayText()
    if (bindings.ActivePalette == nil) then
        return;
    end
    
    local paletteCount = #bindings.JobBindings.Palettes;
    if (paletteCount == 1) then
        return;
    else
        return string.format ('%s (%u/%u)', bindings.ActivePalette.Name, bindings.ActivePaletteIndex, paletteCount);
    end
end

function exposed:HandleCommand(args)
    if (#args < 3) then
        return;
    end
    
    local cmd = string.lower(args[3]);

    if (cmd == 'add') then
        if (args[4] == nil) then
            Error('Command Syntax: $H/tb palette add [name]$R.');
            return;
        end
        local paletteName = string.lower(args[4]);
        for _,palette in ipairs(bindings.JobBindings.Palettes) do
            if (string.lower(palette.Name) == paletteName) then
                Error('Palette already exists.');
                return;
            end
        end
        
        local newPalette = { Name = args[4], Bindings = T{} };
        bindings.JobBindings.Palettes:append(newPalette);
        bindings.LastPaletteIndex = bindings.ActivePaletteIndex;
        bindings.ActivePalette = newPalette;
        bindings.ActivePaletteIndex = #bindings.JobBindings.Palettes;
        ApplyBindings();
        Message('Created palette!');
        WriteJob();
    elseif (cmd == 'remove') then
        if (args[4] == nil) then
            Error('Command Syntax: $H/tb palette remove [name]$R.');
            return;
        end
        if (#bindings.JobBindings.Palettes == 1) then
            Error('Cannot remove last palette.');
            return;
        end
        local paletteName = string.lower(args[4]);
        for index,palette in ipairs(bindings.JobBindings.Palettes) do
            if (string.lower(palette.Name) == paletteName) then
                table.remove(bindings.JobBindings.Palettes, index);
                if (index == bindings.ActivePaletteIndex) then
                    bindings.ActivePalette = bindings.JobBindings.Palettes[1];
                    bindings.ActivePaletteIndex = 1;
                    bindings.LastPaletteIndex = 1;
                    ApplyBindings();
                end
                Message('Removed palette!');
                WriteJob();
                return;
            end
        end
        Error('Could not find palette to remove.');
    elseif (cmd == 'rename') then
        if (args[4] == nil) or (args[5] == nil) then
            Error('Command Syntax: $H/tb palette rename [old name] [new name]$R.');
            return;
        end
        local paletteName = string.lower(args[4]);
        local newNameLower = string.lower(args[5]);
        local targetPalette;
        for index,palette in ipairs(bindings.JobBindings.Palettes) do
            local lower = string.lower(palette.Name);
            if (lower == paletteName) then
                targetPalette = palette;
            elseif (lower == newNameLower) then
                Error('A palette with that name already exists.');
                return;
            end
        end

        if targetPalette then
            targetPalette.Name = args[5];
            Message('Renamed palette!');
            WriteJob();
            return;
        end        
        Error('Could not find palette to rename.');
    elseif (cmd == 'list') then
        for index,palette in ipairs(bindings.JobBindings.Palettes) do
            Message(string.format('[%u] %s%s', index, palette.Name, (bindings.ActivePaletteIndex == index) and ' - $HACTIVE$R' or ''));
        end
    elseif (cmd == 'next') then
        local paletteCount = #bindings.JobBindings.Palettes;
        if (paletteCount == 1) then
            Error('Current job only has one palette!');
            return;
        end
        bindings.ActivePaletteIndex = bindings.ActivePaletteIndex + 1;
        if (bindings.ActivePaletteIndex > paletteCount) then
            bindings.ActivePaletteIndex = 1;
        end
        bindings.ActivePalette = bindings.JobBindings.Palettes[bindings.ActivePaletteIndex];
        ApplyBindings();
        Message(string.format('Swapped to palette: $H%s$R', bindings.ActivePalette.Name));
    elseif (cmd == 'previous') then
        local paletteCount = #bindings.JobBindings.Palettes;
        if (paletteCount == 1) then
            Error('Current job only has one palette!');
            return;
        end
        bindings.ActivePaletteIndex = bindings.ActivePaletteIndex - 1;
        if (bindings.ActivePaletteIndex < 1) then
            bindings.ActivePaletteIndex = paletteCount;
        end
        bindings.ActivePalette = bindings.JobBindings.Palettes[bindings.ActivePaletteIndex];
        ApplyBindings();
        Message(string.format('Swapped to palette: $H%s$R', bindings.ActivePalette.Name));
    elseif (cmd == 'change') then
        if (args[4] == nil) then
            Error('Command Syntax: $H/tb palette change [name]$R.');
            return;
        end
        local paletteName = string.lower(args[4]);

        for index,palette in ipairs(bindings.JobBindings.Palettes) do
            if (string.lower(palette.Name) == paletteName) then
                if (bindings.ActivePaletteIndex ~= index) then
                    bindings.LastPaletteIndex = bindings.ActivePaletteIndex;
                    bindings.ActivePalette = palette;
                    bindings.ActivePaletteIndex = index;
                    ApplyBindings();
                end
                Message(string.format('Swapped to palette: $H%s$R', bindings.ActivePalette.Name));
                return;
            end
        end
        
        Error('Could not find palette to change to.');
    elseif (cmd == 'last') then        
        local last = bindings.LastPaletteIndex;
        local newPalette = bindings.JobBindings.Palettes[last];
        if (newPalette == bindings.ActivePalette) then
            Error('You have not changed palettes since previous palette edit.  You cannot return to last palette.');
            return;
        elseif (newPalette == nil) then
            Error('Your last palette doesn\'t exist.  You cannot return to it.');
            return;
        end

        bindings.LastPaletteIndex = bindings.ActivePaletteIndex;
        bindings.ActivePalette = newPalette;
        bindings.ActivePaletteIndex = last;
        ApplyBindings();
        Message(string.format('Swapped to palette: $H%s$R', bindings.ActivePalette.Name));
    end
end

function exposed:Update()
    ApplyBindings();
end

return exposed;