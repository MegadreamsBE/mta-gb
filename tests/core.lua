-----------------------------------
-- * Events
-----------------------------------

addEventHandler("onResourceStart", resourceRoot, function()
    if (get("tests_enabled") == "true") then
        Override()
        --TestOpcodes():run()
    end
end)
