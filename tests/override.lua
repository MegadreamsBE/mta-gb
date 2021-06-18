-- Allows to run the GPU on the server without an actual output for testing.

-----------------------------------
-- * Functions
-----------------------------------

Override = function()
    dxCreateTexture = function(width, height)
        local pixels = {}

        for i=1, height do
            pixels[i] = {}

            for a=1, width do
                pixels[i][a] = {0, 0, 0, 0}
            end
        end

        return {
            pixels = pixels
        }
    end

    dxGetTexturePixels = function(texture)
        local pixelsCopy = {}

        for i=1, #texture.pixels do
            pixelsCopy[i] = {}

            for a=1, #texture.pixels[i] do
                pixelsCopy[i][a] = texture.pixels[i][a]
            end
        end

        return pixelsCopy
    end

    dxSetPixelColor = function(pixels, x, y, r, g, b, a)
        pixels[y + 1][x + 1] = {r, g, b, (a == nil) and 255 or a}
        return true
    end

    dxSetTexturePixels = function(texture, pixels)
        texture.pixels = pixels
    end

    dxDrawImage = function() end
end
