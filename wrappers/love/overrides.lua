utf8 = require("utf8")

local events = {}
local keyBinds = {}

function addEventHandler(event, _, handler)
    if (events[event] == nil) then
        events[event] = {}
    end

    events[event][#events[event] + 1] = handler
end

function triggerEvent(event, ...)
    if (events[event] == nil) then
        return
    end

    for i=1, #events[event] do
        events[event][i](...)
    end
end

function triggerKeyEvent(key, keyState)
    if (keyBinds[key] == nil) then
        return
    end

    if (keyBinds[key][keyState] == nil) then
        return
    end

    for i=1, #keyBinds[key][keyState] do
        keyBinds[key][keyState][i](key, keyState)
    end
end

function guiGetScreenSize()
    return love.graphics.getWidth(), love.graphics.getHeight()
end

function dxCreateTexture(width, height)
    local canvas = love.graphics.newCanvas(width, height)
    local pixels = canvas:newImageData(nil, nil, 0, 0, width, height)

    return {width, height, canvas, pixels, love.graphics.newImage(pixels)}
end

function dxCreateRenderTarget(width, height, withAlpha)
    local canvas = love.graphics.newCanvas(width, height)
    return {width, height, canvas}
end

function dxSetRenderTarget(renderTarget, clear)
    if (renderTarget == nil) then
        return love.graphics.setCanvas()
    end

    love.graphics.setCanvas(renderTarget[3])

    if (clear) then
        love.graphics.clear()
    end
end

function dxSetBlendMode(mode)
    --[[if (mode == "modulate_add") then
        mode = "add"
    end

    if (mode == "blend") then
        mode = "alpha"
    end

    love.graphics.setBlendMode(mode)]]
end

function dxSetTexturePixels(texture, pixels)
    texture[5]:replacePixels(pixels, nil, nil, 0, 0, false)
end

function dxGetTexturePixels(texture)
    return texture[4]
end

function tocolor(r, g, b, a)
    return {r, g, b, a}
end

function dxSetPixelColor(pixels, x, y, r, g, b, a)
    pixels:setPixel(x, y, (r or 255) / 255, (g or 255) / 255, (b or 255) / 255, (a or 255) / 255)
end

function dxGetPixelColor(pixels, x, y)
    local r, g, b, a = pixels:getPixel(x, y)
    return r * 255, g * 255, b * 255, (a or 1) * 255
end

function dxDrawImage(x, y, width, height, image, rotation, rotOffsetX, rotOffsetY, color, _)
    if (color == nil) then
        color = {255, 255, 255, 255}
    end

    local draw = image[5] or image[3]

    love.graphics.setColor((color[1] or 255) / 255, (color[2] or 255) / 255, (color[3] or 255) / 255, (color[4] or 255) / 255)
    love.graphics.draw(draw, x or 0, y or 0, math.rad(rotation or 0), 1 / (image[1] / width), 1 / (image[2] / height))
    love.graphics.setColor(1, 1, 1, 1)
end

function dxDrawText(text, left, top, right, bottom, color, scale, font, alignX, alignY)
    if (color == nil) then
        color = {255, 255, 255, 255}
    end

    if (right == 0 or right == nil) then
        right = love.graphics.getWidth()
    end

    love.graphics.setColor((color[1] or 255) / 255, (color[2] or 255) / 255, (color[3] or 255) / 255, (color[4] or 255) / 255)
    love.graphics.printf(text, left, top, right, alignX or "left", 0, scale or 1, scale or 1)
    love.graphics.setColor(1, 1, 1, 1)
end

function dxDrawRectangle(x, y, width, height, color)
    if (color == nil) then
        color = {255, 255, 255, 255}
    end

    love.graphics.setColor((color[1] or 255) / 255, (color[2] or 255) / 255, (color[3] or 255) / 255, (color[4] or 255) / 255)
    love.graphics.rectangle("fill", x, y, width, height)
    love.graphics.setColor(1, 1, 1, 1)
end

function dxGetFontHeight(scale, font)
    return 2
end

function fileOpen(filePath, readOnly)
    return love.filesystem.newFile(filePath, ((readOnly) and 'r' or 'w'))
end

function fileCreate(filePath)
    return fileOpen(filePath, false)
end

function fileClose(file)
    return file:close()
end

function fileIsEOF(file)
    return file:isEOF()
end

function fileExists(filePath)
    return (love.filesystem.getInfo(filePath) ~= nil)
end

function fileWrite(file, data)
    return file:write(data)
end

function fileDelete(filePath)
    return love.filesystem.remove(filePath)
end

function pregMatch()
    return {}
end

function outputDebugString(text)
    print(text)
end

function bitAnd(value1, value2)
    return bit.band(value1, value2)
end

function bitOr(value1, value2)
    return bit.bor(value1, value2)
end

function bitXor(value1, value2)
    return bit.bxor(value1, value2)
end

function bitNot(value)
    return bit.bnot(value)
end

function bitReplace(value, replaceWith, field, width)
    if (width == nil) then
        width = 1
    end

    local mask = bit.lshift(1, width) - 1

    replaceWith = bit.band(replaceWith, mask)

    return bit.bor(bit.band(value, bit.bnot(bit.lshift(mask, field))), bit.lshift(replaceWith, field))
end

function bitExtract(value, field, width)
    if (width == nil) then
        width = 1
    end

    return bit.band(bit.rshift(value, field), bit.lshift(1, width) - 1)
end

function bitLShift(value, n)
    return bit.lshift(value, n)
end

function bitRShift(value, n)
    return bit.rshift(value, n)
end

function bitLRotate(value, n)
    return bit.lrotate(value, n)
end

function bitRRotate(value, n)
    return bit.rrotate(value, n)
end

function getTickCount()
    return love.timer.getTime() * 1000
end

function setTimer()
    --
end

function addCommandHandler()
    --
end

function bindKey(key, keyState, handler)
    if (keyBinds[key] == nil) then
        keyBinds[key] = {}
    end

    if (keyBinds[key][keyState] == nil) then
        keyBinds[key][keyState] = {}
    end

    keyBinds[key][keyState][#keyBinds[key][keyState] + 1] = handler
end

utf8.byte = function(byte)
    return string.byte(byte)
end