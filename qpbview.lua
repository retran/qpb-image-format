--[[
    qpbview - QPB Viewer
    (c) 2024 Andrew Vasilyev. All rights reserved.

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program. If not, see <https://www.gnu.org/licenses/>.
]]

local qpb = nil
local x = 0
local y = 0

local function apply_palettes(palettes)
    -- Iterate over all the palettes
    for i = 1, #palettes do
        -- Retrieve the palette at the current index
        local palette = palettes[i].palette
        for j = 0, palette:width() - 1 do
            -- Calculate the memory address for each entry
            local address = 0x5000 + (i - 1) * palette:width() * 4 + j * 4
            -- Write the 32-bit ARGB value to the calculated address
            poke4(address, palette:get(j))
        end
    end
end

local function apply_palette_map(y, map)
    -- The base address of the palette map in memory
    local palette_base_address = 0x5400

    -- The number of scanlines in the palette map
    local num_scanlines = map:width()

    for i = 0, num_scanlines - 1 do
        -- Retrieve the palette index for the current scanline
        local palette_index = map:get(i)
        assert(palette_index >= 0 and palette_index <= 3, "Invalid palette index")

        -- Calculate the memory address for the palette entry
        local scanline = y + i
        local byte_offset = palette_base_address + math.floor(scanline / 4)
        local bit_shift = (scanline % 4) * 2

        -- Retrieve the current value at the byte_offset
        local current_value = peek(byte_offset)

        -- Clear the specific 2 bits at the bit_shift position
        local mask = ~(0x03 << bit_shift)
        current_value = current_value & mask

        -- Set the new palette index at the specific bit position
        current_value = current_value | (palette_index << bit_shift)

        -- Write the modified value back to memory
        poke(byte_offset, current_value)
    end
end

function _init()
    local argv = env().argv
    local filename = argv[1]

    if filename == nil then
        print("qpbview - QPB Viewer")
        print("(c) 2024 Andrew Vasilyev. All rights reserved.")
        print("Usage: qpbview <filename>")
        print("  filename - The path to the QPB file to view")
        print("Example: qpbview city.qpb")
        exit(0)
        return
    end

    qpb = fetch(filename)

    -- Center the image on the screen
    x = 480 / 2 - qpb.bitmap:width() / 2
    y = 270 / 2 - qpb.bitmap:height() / 2

    -- Apply the palettes and palette map
    apply_palettes(qpb.palettes)
    apply_palette_map(y, qpb.map)
end

function _draw()
    -- Draw the bitmap at the specified position
    spr(qpb.bitmap, x, y)
end

function _update()
    -- do nothing
end
