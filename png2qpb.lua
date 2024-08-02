--[[
    png2qpb.lua - Convert a PNG image to a QPB image
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

-- Define epsilon value for floating-point comparisons
local EPSILON = 0.0001

-- Define log levels for logging messages
LogLevel = {
    TRACE = 0,
    DEBUG = 1,
    INFO = 2,
    WARNING = 3,
    ERROR = 4,
    NONE = 5
}

local log_level = LogLevel.INFO -- Set default log level

-- Logging functions
local function log_message(level, color_code, message)
    if log_level <= level then
        print("\f" .. color_code .. "[" .. date("%Y-%m-%d %H:%M:%S") .. "] " .. message)
    end
end

local function trace(message)
    log_message(LogLevel.TRACE, "6", message)
end

local function debug(message)
    log_message(LogLevel.DEBUG, "6", message)
end

local function info(message)
    log_message(LogLevel.INFO, "7", message)
end

local function success(message)
    log_message(LogLevel.INFO, "3", message)
end

local function warning(message)
    log_message(LogLevel.WARNING, "9", message)
end

local function error(message)
    log_message(LogLevel.ERROR, "8", message)
    exit(1)
end

-- Convert CIELAB color to RGB color space
local function cielab_to_rgb(l, a, b)
    -- Helper function to combine RGB components into a single color integer
    local function combine_rgb_components(r, g, b)
        assert(r >= 0 and r <= 255, "Red component out of range")
        assert(g >= 0 and g <= 255, "Green component out of range")
        assert(b >= 0 and b <= 255, "Blue component out of range")
        return (r << 16) | (g << 8) | b
    end

    -- Apply inverse gamma correction
    local function inverse_gamma_correct(value)
        return (value > 0.0031308) and (1.055 * (value ^ (1 / 2.4)) - 0.055) or (12.92 * value)
    end

    -- Transform function for Lab to XYZ conversion
    local function lab_to_xyz_transform(value)
        return (value > 0.206893034) and (value ^ 3) or ((value - 16 / 116) / 7.787)
    end

    -- Convert CIELAB components to normalized XYZ components
    local function cielab_to_xyz(l, a, b)
        local y = (l + 16) / 116
        local x = a / 500 + y
        local z = y - b / 200
        x, y, z = lab_to_xyz_transform(x), lab_to_xyz_transform(y), lab_to_xyz_transform(z)
        return x * 95.047, y * 100.000, z * 108.883
    end

    -- Convert XYZ to normalized RGB components
    local function xyz_to_normalized_rgb(x, y, z)
        local r = x * 3.2404542 + y * -1.5371385 + z * -0.4985314
        local g = x * -0.9692660 + y * 1.8760108 + z * 0.0415560
        local b = x * 0.0556434 + y * -0.2040259 + z * 1.0572252
        return inverse_gamma_correct(r), inverse_gamma_correct(g), inverse_gamma_correct(b)
    end

    -- Ensure input types are correct
    assert(type(l) == "number" and type(a) == "number" and type(b) == "number", "CIELAB components must be numbers")
    -- Convert CIELAB to XYZ, then to RGB
    local x, y, z = cielab_to_xyz(l, a, b)
    local r, g, b = xyz_to_normalized_rgb(x, y, z)
    -- Clamp and combine RGB components
    r = math.floor(math.max(0, math.min(1, r)) * 255)
    g = math.floor(math.max(0, math.min(1, g)) * 255)
    b = math.floor(math.max(0, math.min(1, b)) * 255)
    return combine_rgb_components(r, g, b)
end

-- Convert an RGB color to CIELAB color space
local function rgb_to_cielab(color)
    -- Extract RGB components from a color integer
    local function extract_rgb_components(color)
        return (color >> 16) & 0xFF, (color >> 8) & 0xFF, color & 0xFF
    end

    -- Normalize a color component (0-255 to 0-1 range)
    local function normalize_color_component(component)
        return component / 255
    end

    -- Apply gamma correction to a normalized value
    local function gamma_correct(value)
        return (value > 0.04045) and (((value + 0.055) / 1.055) ^ 2.4) or (value / 12.92)
    end

    -- Extract and normalize RGB components from an integer color value
    local function extract_normalized_rgb(color)
        local r, g, b = extract_rgb_components(color)
        return normalize_color_component(r), normalize_color_component(g), normalize_color_component(b)
    end

    -- Transform function for XYZ to Lab conversion
    local function xyz_to_lab_transform(value)
        return (value > 0.008856) and (value ^ (1 / 3)) or ((903.3 * value + 16) / 116)
    end

    -- Convert normalized RGB to XYZ color space
    local function normalized_rgb_to_xyz(r, g, b)
        return
            r * 0.4124564 + g * 0.3575761 + b * 0.1804375,
            r * 0.2126729 + g * 0.7151522 + b * 0.0721750,
            r * 0.0193339 + g * 0.1191920 + b * 0.9503041
    end

    -- Normalize XYZ components based on the D65 illuminant
    local function normalize_xyz_components(x, y, z)
        return x / 95.047, y / 100.000, z / 108.883
    end

    -- Convert XYZ to CIELAB components
    local function xyz_to_cielab(x, y, z)
        x, y, z = xyz_to_lab_transform(x), xyz_to_lab_transform(y), xyz_to_lab_transform(z)
        return (116 * y) - 16, 500 * (x - y), 200 * (y - z)
    end

    -- Convert normalized RGB to CIELAB color space
    local function normalized_rgb_to_cielab(r, g, b)
        r, g, b = gamma_correct(r), gamma_correct(g), gamma_correct(b)
        local x, y, z = normalize_xyz_components(normalized_rgb_to_xyz(r, g, b))
        return xyz_to_cielab(x, y, z)
    end

    -- Ensure input type is correct
    assert(type(color) == "number", "Expected number for 'color'")
    -- Convert RGB to CIELAB
    local r, g, b = extract_normalized_rgb(color)
    return normalized_rgb_to_cielab(r, g, b)
end

-- Get a pixel from a CIELAB bitmap
local function cielab_bitmap_get_pixel(cielab_bitmap, i, j)
    local idx = i * 3
    return cielab_bitmap:get(idx, j), cielab_bitmap:get(idx + 1, j), cielab_bitmap:get(idx + 2, j)
end

-- Set a pixel in a CIELAB bitmap
local function cielab_bitmap_set_pixel(cielab_bitmap, i, j, l, a, b)
    local idx = i * 3
    cielab_bitmap:set(idx, j, l, a, b)
end

-- Convert an RGB bitmap to CIELAB color space
local function rgb_bitmap_to_cielab_bitmap(rgb_bitmap)
    assert(type(rgb_bitmap) == "userdata", "Expected userdata for 'rgb_bitmap'")

    info("Converting RGB to CIELAB color space...")

    -- Create a new bitmap for CIELAB values
    local cielab_bitmap = userdata("f64", rgb_bitmap:width() * 3, rgb_bitmap:height())

    -- Convert each pixel from RGB to CIELAB
    for j = 0, rgb_bitmap:height() - 1 do
        for i = 0, rgb_bitmap:width() - 1 do
            trace("Converting pixel at (" .. i .. ", " .. j .. ")")
            local rgb = rgb_bitmap:get(i, j)
            trace("RGB: " .. rgb)
            local l, a, b = rgb_to_cielab(rgb)
            trace("CIELAB: " .. l .. ", " .. a .. ", " .. b)
            cielab_bitmap_set_pixel(cielab_bitmap, i, j, l, a, b)
        end
    end

    success("Conversion to CIELAB color space completed.")

    return cielab_bitmap
end

-- Compute the distance matrix between rows of histograms
local function compute_distance_matrix(histograms)
    -- Compute the Hellinger distance between two rows of histograms
    local function hellinger_distance(histograms, row1, row2)
        local bins = 256
        local sum = 0

        for i = 0, bins * 3 - 1 do
            local h1 = histograms:get(row1, i)
            local h2 = histograms:get(row2, i)
            local h1_sqrt = math.sqrt(h1)
            local h2_sqrt = math.sqrt(h2)
            local diff = h1_sqrt - h2_sqrt
            sum = sum + diff * diff
        end

        return math.sqrt(sum) / math.sqrt(2)
    end

    assert(type(histograms) == "userdata", "Expected userdata for 'histograms'")

    info("Computing distance matrix...")

    local num_rows = histograms:height()
    local distance_matrix = userdata("f64", num_rows, num_rows)

    -- Compute the distance between each pair of rows
    for row1 = 0, num_rows - 1 do
        for row2 = row1, num_rows - 1 do
            trace("Computing distance between rows " .. row1 .. " and " .. row2)
            local distance = hellinger_distance(histograms, row1, row2)
            trace("Distance: " .. distance)
            distance_matrix:set(row1, row2, distance)
            distance_matrix:set(row2, row1, distance)
        end
    end

    success("Distance matrix computed.")

    return distance_matrix
end

-- Compute histograms for each row of a CIELAB bitmap
local function compute_cielab_histograms(cielab_bitmap)
    assert(type(cielab_bitmap) == "userdata", "Expected userdata for 'cielab_bitmap'")

    info("Computing histograms...")

    local bins = 256
    local last_bin_index = bins - 1

    local width = cielab_bitmap:width() / 3
    local height = cielab_bitmap:height()
    local histograms = userdata("f64", bins * 3, height)

    -- Compute histograms for each row of the image
    for j = 0, height - 1 do
        trace("Computing histogram for row " .. j)
        for i = 0, width - 1 do
            trace("Processing pixel at (" .. i .. ", " .. j .. ")")

            local l, a, b = cielab_bitmap_get_pixel(cielab_bitmap, i, j)

            trace("CIELAB: " .. l .. ", " .. a .. ", " .. b)

            -- Normalize L* to range [0, last_bin_index] and a*, b* from [-128, 127] to [0, last_bin_index]
            l = math.floor(l / 100 * last_bin_index)
            a = math.floor((a + 128) / 255 * last_bin_index)
            b = math.floor((b + 128) / 255 * last_bin_index)

            -- Ensure indices are within bounds
            l = math.max(0, math.min(last_bin_index, l))
            a = math.max(0, math.min(last_bin_index, a))
            b = math.max(0, math.min(last_bin_index, b))

            trace("L*: " .. l .. ", a*: " .. a .. ", b*: " .. b)

            -- Update the corresponding bins in the histogram
            histograms:set(j, l, histograms:get(j, l) + 1)
            histograms:set(j, bins + a, histograms:get(j, bins + a) + 1)
            histograms:set(j, bins * 2 + b, histograms:get(j, bins * 2 + b) + 1)
        end
    end

    success("Histograms computed.")

    return histograms
end

-- k-medoids clustering algorithm
local function kmedoids(distance_matrix, k, max_iterations)
    -- Generate initial medoids
    local function generate_initial_medoids(distance_matrix, k)
        debug("Generating initial medoids...")

        local num_rows = distance_matrix:height()
        local medoids = {}
        local dist_sums = {}
        local selected = {}

        -- Compute sum of distances for each row
        for i = 0, num_rows - 1 do
            dist_sums[i] = 0
            for j = 0, num_rows - 1 do
                if i ~= j then
                    dist_sums[i] = dist_sums[i] + distance_matrix:get(i, j)
                end
            end
        end

        -- Select initial medoids based on maximum sum of distances
        while #medoids < k do
            local max_dist = -1
            local best_index = 0

            for i = 0, num_rows - 1 do
                if not selected[i] and dist_sums[i] > max_dist then
                    max_dist = dist_sums[i]
                    best_index = i
                end
            end

            trace("Selected medoid: " .. best_index)
            table.insert(medoids, best_index)
            selected[best_index] = true
        end

        debug("Initial medoids generated.")

        return medoids
    end

    -- Compute total distance of all points in a cluster to a given medoid
    local function total_distance_to_medoid(distance_matrix, medoid, cluster)
        local total_distance = 0
        for _, row in ipairs(cluster) do
            total_distance = total_distance + distance_matrix:get(row, medoid)
        end
        return total_distance
    end

    -- Find the new medoid for a cluster
    local function find_new_medoid(distance_matrix, cluster)
        local best_medoid = cluster[1]
        local best_distance = math.huge

        for _, candidate in ipairs(cluster) do
            local distance = total_distance_to_medoid(distance_matrix, candidate, cluster)
            if distance < best_distance then
                best_distance = distance
                best_medoid = candidate
            end
        end

        return best_medoid
    end

    debug("Running k-medoids algorithm...")

    local assignments = {}
    local medoids = generate_initial_medoids(distance_matrix, k)

    -- Main loop for the k-medoids algorithm
    for iteration = 1, max_iterations do
        debug("Iteration " .. iteration)
        local clusters = {}
        for i = 1, k do
            clusters[i] = {}
        end

        debug("Assigning rows to clusters...")
        for row = 0, distance_matrix:height() - 1 do
            trace("Assigning row " .. row)
            local min_distance = math.huge
            local closest_medoid = 1
            for i, medoid in ipairs(medoids) do
                local distance = distance_matrix:get(row, medoid)
                if distance < min_distance then
                    min_distance = distance
                    closest_medoid = i
                end
            end
            table.insert(clusters[closest_medoid], row)
            assignments[row + 1] = closest_medoid
            trace("Row " .. row .. " assigned to cluster " .. closest_medoid)
        end

        debug("Finding new medoids...")
        local new_medoids = {}
        for i = 1, k do
            new_medoids[i] = find_new_medoid(distance_matrix, clusters[i])
            trace("New medoid for cluster " .. i .. ": " .. new_medoids[i])
        end

        debug("Checking for stability...")
        local changes = 0
        for i = 1, k do
            if new_medoids[i] ~= medoids[i] then
                changes = changes + 1
            end
        end

        debug("Changes: " .. changes)
        medoids = new_medoids
        if changes == 0 then
            debug("No changes, stopping iterations")
            break
        end
    end

    debug("k-medoids algorithm completed.")

    return assignments
end

-- Compute the squared Euclidean distance between two vectors
local function squared_euclidean_distance(vector1, vector2)
    local sum = 0
    for i = 0, vector1:width() do
        sum = sum + (vector1:get(i) - vector2:get(i)) ^ 2
    end
    return sum
end

-- Build a color palette for a given cluster of rows in the CIELAB bitmap
local function build_palette_for_rows(cielab_bitmap, rows, number_of_colors, max_iterations)
    -- Generate initial centroids for k-means algorithm
    local function generate_initial_centroids(original_colors, pinned_centroids)
        local default_colors = {
             -- Define default RGB colors for palette initialization
            0x000000, 0x1d2b53, 0x7e2553, 0x008751, 0xab5236, 0x5f574f, 0xc2c3c7, 0xfff1e8,
            0xff004d, 0xffa300, 0xffec27, 0x00e436, 0x29adff, 0x83769c, 0xff77a8, 0xffccaa,
            0x1c5eac, 0x00a5a1, 0x754e97, 0x125359, 0x742f29, 0x492d38, 0xa28879, 0xffacc5,
            0xc3004c, 0xeb6b00, 0x90ec42, 0x00b251, 0x64dff6, 0xbd9adf, 0xe40dab, 0xff856d
        }

        debug("Generating initial centroids...")

        local centroids = {}

        assert(pinned_centroids >= 0 and pinned_centroids <= 64, "Invalid number of pinned centroids")

        if pinned_centroids > 0 then
            debug("Pinning " .. pinned_centroids .. " centroids.")
            for i = 1, pinned_centroids do
                local l, a, b = rgb_to_cielab(default_colors[i])
                local cielab_color = vec(l, a, b)
                table.insert(centroids, cielab_color)
            end
        end

        for i = 1, 64 - pinned_centroids do
            table.insert(centroids, original_colors[math.random(1, #original_colors)])
        end

        debug("Initial centroids generated.")

        return centroids
    end

    debug("Building palette for cluster...")

    local pinned_centroids = 64 - number_of_colors

    local original_colors = {}

    -- Collect unique colors from the specified rows
    for _, row in ipairs(rows) do
        for i = 0, cielab_bitmap:width() - 1 do
            local l, a, b = cielab_bitmap_get_pixel(cielab_bitmap, i, row)

            local pixel_color = vec(l, a, b)

            local exists = false
            for _, existing_color in ipairs(original_colors) do
                if squared_euclidean_distance(existing_color, pixel_color) < EPSILON then
                    exists = true
                    break
                end
            end

            if not exists then
                table.insert(original_colors, pixel_color)
            end
        end
    end

    local centroids = generate_initial_centroids(original_colors, pinned_centroids)

    debug("Running k-means algorithm...")

    for iteration = 1, max_iterations do
        debug("Iteration " .. iteration)
        local clusters = {}
        for i = 1, 64 do
            clusters[i] = {}
        end

        debug("Assigning colors to clusters...")

        for _, color in ipairs(original_colors) do
            local min_distance = math.huge
            local closest_centroid = 1

            for i, centroid in ipairs(centroids) do
                local distance = squared_euclidean_distance(color, centroid)
                if distance < min_distance then
                    min_distance = distance
                    closest_centroid = i
                end
            end

            table.insert(clusters[closest_centroid], color)
        end

        debug("Updating centroids...")

        local new_centroids = {}

        for i = 1, pinned_centroids do
            new_centroids[i] = centroids[i]
        end

        for i = pinned_centroids + 1, #centroids do
            local sum = vec(0, 0, 0)

            for _, color in ipairs(clusters[i]) do
                sum:set(0, sum:get(0) + color:get(0))
                sum:set(1, sum:get(1) + color:get(1))
                sum:set(2, sum:get(2) + color:get(2))
            end

            sum:set(0, sum:get(0) / #clusters[i])
            sum:set(1, sum:get(1) / #clusters[i])
            sum:set(2, sum:get(2) / #clusters[i])

            new_centroids[i] = sum
            trace("New centroid: " .. new_centroids[i]:get(0) .. ", " .. new_centroids[i]:get(1) .. ", " .. new_centroids[i]:get(2))
        end

        debug("Checking for stability...")

        local changes = 0

        for i = 1, #centroids do
            if squared_euclidean_distance(centroids[i], new_centroids[i]) > EPSILON then
                changes = changes + 1
            end
        end

        debug("Changes: " .. changes)

        centroids = new_centroids

        if changes == 0 then
            debug("No changes, stopping iterations")
            break
        end
    end

    debug("Palette built.")

    return centroids
end

-- Unify similar colors in the palettes
local function unify_similar_colors(palettes, pinned_colors)
    assert(type(palettes) == "table", "Expected table for 'palettes'")
    assert(type(pinned_colors) == "number", "Expected number for 'pinned_colors'")

    info("Unifying similar colors in palettes...")

    -- Iterate over all palettes and unify similar colors
    for i = 1, #palettes do
        for j = pinned_colors + 1, #palettes[i] do
            local color1 = palettes[i][j]

            for k = i, #palettes do
                local start_index = (i == k) and (j + 1) or 1

                for l = start_index, #palettes[k] do
                    local color2 = palettes[k][l]

                    if squared_euclidean_distance(color1, color2) < EPSILON * 4 then
                        -- Replace color2 with color1
                        palettes[k][l] = color1
                    end
                end
            end
        end
    end

    success("Color palettes unified.")

    return palettes
end

-- Build an indexed bitmap from a CIELAB bitmap and a set of color palettes
local function build_indexed_bitmap(cielab_bitmap, palettes, assignments)
    -- Find the closest color index in the palette for a given color
    local function find_closest_color_index(color, palette)
        local min_distance = math.huge
        local closest_color_index = 1

        for i, candidate in ipairs(palette) do
            local distance = squared_euclidean_distance(color, candidate)
            if distance < min_distance then
                min_distance = distance
                closest_color_index = i
            end
        end

        return closest_color_index
    end

    info("Building indexed bitmap...")

    local indexed_bitmap = userdata("u8", cielab_bitmap:width() / 3, cielab_bitmap:height())

    for i = 0, indexed_bitmap:width() - 1 do
        for j = 0, indexed_bitmap:height() - 1 do
            trace("Processing pixel at (" .. i .. ", " .. j .. ")")
            local l, a, b = cielab_bitmap_get_pixel(cielab_bitmap, i, j)
            local color = vec(l, a, b)
            local palette_index = assignments[j + 1]
            local palette = palettes[palette_index]
            local closest_color_index = find_closest_color_index(color, palette) - 1
            trace("Closest color index: " .. closest_color_index)
            indexed_bitmap:set(i, j, closest_color_index)
        end
    end

    success("Indexed bitmap built.")

    return indexed_bitmap
end

-- Convert a CIELAB palette to an RGB palette
local function convert_cielab_palette_to_rgb(palette)
    local rgb_palette = userdata("u32", #palette)

    for i, color in ipairs(palette) do
        local l, a, b = color:get(0), color:get(1), color:get(2)
        trace("CIELAB: " .. l .. ", " .. a .. ", " .. b)
        local rgb = cielab_to_rgb(l, a, b)
        trace("RGB: " .. rgb)
        rgb_palette:set(i - 1, rgb)
    end

    return rgb_palette
end

-- Main function to convert PNG to QPB
local function convert_png_to_qpb(filename, number_of_colors)
    -- Extract filename without extension
    local filename_without_extension = string.match(filename, "([^/]+)%.png$")
    if not filename_without_extension then
        error("Invalid filename format. Please provide a .png file.")
    end

    -- Load the PNG file
    local png = fetch(filename)
    if not png then
        error("Failed to load PNG file: " .. filename)
    end

    -- Convert RGB bitmap to CIELAB color space
    local cielab_bitmap = rgb_bitmap_to_cielab_bitmap(png)
    -- Compute histograms for CIELAB bitmap
    local histograms = compute_cielab_histograms(cielab_bitmap)
    -- Compute distance matrix from histograms
    local distance_matrix = compute_distance_matrix(histograms)

    info("Clustering rows...")

    local nclusters = 4
    local cluster_assignments = kmedoids(distance_matrix, nclusters, 100)

    success("Clustering completed.")

    -- Build color palettes for each cluster
    info("Building color palettes...")

    -- Group rows by cluster
    local clusters = {}
    for i = 1, nclusters do clusters[i] = {} end
    for i, cluster in ipairs(cluster_assignments) do
        table.insert(clusters[cluster], i)
    end

    local palettes = {}
    for _, cluster in ipairs(clusters) do
        local palette = build_palette_for_rows(cielab_bitmap, cluster, number_of_colors, 100)
        table.insert(palettes, palette)
    end

    success("Color palettes built.")

    -- Unify similar colors in the palettes
    palettes = unify_similar_colors(palettes, 64 - number_of_colors)

    local indexed_bitmap = build_indexed_bitmap(cielab_bitmap, palettes, cluster_assignments)

    info("Converting CIELAB palettes to RGB...")
    local rgb_palettes = {}
    for i, palette in ipairs(palettes) do
        table.insert(rgb_palettes, {
            id = i - 1,
            palette = convert_cielab_palette_to_rgb(palette)
        })
    end
    success("Conversion to RGB completed.")

    -- Create scanlines map
    local scanlinesMap = userdata("u8", indexed_bitmap:height())
    for i = 1, #cluster_assignments do
        scanlinesMap:set(i - 1, cluster_assignments[i] - 1)
    end

    info("Saving QPB file...")
    local qpb = {
        version = 1,
        palettes = rgb_palettes,
        bitmap = indexed_bitmap,
        map = scanlinesMap,
    }
    store(filename_without_extension .. ".qpb", qpb)
    success("QPB file saved.")
end

-- Main script entry point
print("png2qpb - Convert a PNG image to a QPB image")
print("(c) 2024 Andrew Vasilyev. All rights reserved.")

local argv = env().argv
if (#argv < 1) then
    print("Usage: png2qpb <filename> <default_colors> <epsilon>")
    print("  filename - Path to the PNG file.")
    print("  default_colors - Number of colors to retain from the default palette (default: 16).")
    print("  epsilon - Tolerance for color comparisons (default: 0.0001).")
    print("Example: png2qpb city.png")
    return
else
    local filename = argv[1]
    local default_colors = 16
    if (argv[2] ~= nil) then
        default_colors = tonumber(argv[2])
    end
    assert(default_colors >= 0 and default_colors <= 64, "Invalid number of default colors")
    EPSILON = 0.0001
    if (argv[3] ~= nil) then
        EPSILON = tonumber(argv[3])
    end
    local status, err = pcall(convert_png_to_qpb, filename, 64 - default_colors)
    if not status then
        error("Failed to convert PNG to QPB: " .. err)
    end
end
