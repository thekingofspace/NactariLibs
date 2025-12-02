table.insert(CreationBoot, function(self)
    self.UsedLibraries = {}

    self:AddLibrary("Nactari", "1.0.0")
    self:AddLibrary("NactariDependants", "1.0.0")
end)

function ExposedMethods.AddLibrary(self, Name:string, Version:string)
    self.UsedLibraries[Name] = Version
end

local function CompareVersion(A:string, B:string)
    local a1, a2, a3 = A:match("(%d+)%.(%d+)%.?(%d*)")
    local b1, b2, b3 = B:match("(%d+)%.(%d+)%.?(%d*)")

    a1, a2, a3 = tonumber(a1), tonumber(a2), tonumber(a3 or 0)
    b1, b2, b3 = tonumber(b1), tonumber(b2), tonumber(b3 or 0)

    if a1 ~= b1 then return a1 >= b1 end
    if a2 ~= b2 then return a2 >= b2 end
    return a3 >= b3
end

function ExposedMethods.HasLibrary(self, ...)
    for _, entry in ipairs({...}) do
        local name, requiredVersion

        if typeof(entry) == "table" then
            name = entry[1]
            requiredVersion = entry[2]
        else
            name = entry
        end

        local actual = self.UsedLibraries[name]
        if not actual then
            error("[NACTARI DEPENDANTS] - Missing dependency " .. tostring(name))
        end

        if requiredVersion and not CompareVersion(actual, requiredVersion) then
            error(("[NACTARI DEPENDANTS] - Library '%s' version too low (have %s, need %s)")
                :format(name, actual, requiredVersion))
        end
    end
end

return true
