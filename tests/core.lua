-----------------------------------
-- * Events
-----------------------------------

addEventHandler("onResourceStart", resourceRoot, function()
    if (get("tests_enabled") == "true") then
        Override.override()
        --TestOpcodes():run()
    end
end)
