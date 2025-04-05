local utils = require 'mp.utils'
local ass = require 'mp.assdraw'

-- Ottieni il percorso dello script corrente usando debug.getinfo
local script_path = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
local json_path = script_path .. "json.lua"

-- Carica json.lua
local json_file = io.open(json_path, "r")
if json_file then
    json = dofile(json_path)
    json_file:close()
else
    mp.msg.error("Impossibile caricare json.lua da " .. json_path)
    return
end

local config = { 
    json_extension = ".json",
    osd_style = "{\\an7\\fs20\\b1\\c&HFFFFFF&\\fnNoto Sans}"
}

mp.msg.info("Script annotations.lua caricato correttamente")

-- Variabili globali
local actors = {}          -- Dati grezzi degli attori e intervalli
local sorted_actors = {}   -- Lista ordinata staticamente degli attori
local last_active_text = nil -- Ultimo testo mostrato nell'OSD
local last_second = -1     -- Ultimo secondo elaborato

-- Ottiene il percorso base del video
local function get_video_base_path()
    local path = mp.get_property("path")
    if not path then
        mp.msg.warn("Nessun percorso video disponibile")
        return "", ""
    end
    local dir, filename = utils.split_path(path)
    local base = filename:gsub("%..+$", "")
    return dir, base
end

-- Carica le annotazioni dal file JSON
local function load_annotations()
    local dir, base = get_video_base_path()
    local json_path = utils.join_path(dir, base .. config.json_extension)
    
    local file = io.open(json_path, "r")
    if not file then
        mp.msg.warn("File JSON non trovato: " .. json_path)
        return {}
    end
    local data = file:read("*a")
    file:close()
    
    local success, decoded = pcall(json.decode, data)
    if not success then
        mp.msg.error("Errore nel parsing del JSON: " .. decoded)
        return {}
    end
    return decoded
end

-- Converte un timestamp in secondi con validazione
local function parse_timestamp(ts)
    local h, m, s = ts:match("^(%d+):(%d+):(%d+)$")
    if not (h and m and s) then
        mp.msg.error("Formato timestamp non valido: " .. ts)
        return nil
    end
    h, m, s = tonumber(h), tonumber(m), tonumber(s)
    if h < 0 or m < 0 or m > 59 or s < 0 or s > 59 then
        mp.msg.error("Valori timestamp fuori range: " .. ts)
        return nil
    end
    return h * 3600 + m * 60 + s
end

-- Pre-elabora gli intervalli e ordina gli attori una sola volta
local function preprocess_intervals(raw_data)
    local processed = {}
    for actor, intervals in pairs(raw_data) do
        processed[actor] = {}
        for _, interval in ipairs(intervals) do
            local start_ts = parse_timestamp(interval[1])
            local end_ts = parse_timestamp(interval[2])
            if start_ts and end_ts then
                if start_ts <= end_ts then
                    table.insert(processed[actor], {start_ts, end_ts})
                else
                    mp.msg.warn("Intervallo non valido per " .. actor .. ": " .. interval[1] .. " > " .. interval[2])
                end
            end
        end
    end
    
    -- Ordina gli attori staticamente
    sorted_actors = {}
    for actor in pairs(processed) do
        table.insert(sorted_actors, actor)
    end
    table.sort(sorted_actors) -- Ordinamento alfabetico una tantum
    
    return processed
end

-- Aggiorna l'OSD con gli attori attivi
local function update_osd()
    local osd_level = mp.get_property_number("osd-level", 3)
    if osd_level < 1 then
        last_active_text = ""
        mp.set_osd_ass(0, 0, "")
        return
    end

    local time = mp.get_property_number("time-pos", 0)
    if not time then return end -- Evita errori se time-pos non è disponibile
    local current_second = math.floor(time)

    -- Evita aggiornamenti inutili se il secondo non è cambiato
    if current_second == last_second then
        return
    end
    last_second = current_second

    -- Raccogli gli attori attivi mantenendo l'ordine di sorted_actors
    local active = {}
    for _, actor in ipairs(sorted_actors) do
        local intervals = actors[actor]
        for _, interval in ipairs(intervals) do
            if time >= interval[1] and time <= interval[2] then
                table.insert(active, actor)
                break -- Passa all'attore successivo una volta trovato
            end
        end
    end

    -- Genera il testo per l'OSD
    local new_active_text = #active > 0 and config.osd_style .. table.concat(active, "\\N") or ""
    if new_active_text ~= last_active_text then
        mp.set_osd_ass(0, 0, new_active_text)
        last_active_text = new_active_text
    end
end

-- Gestione del cambio di livello OSD
mp.observe_property("osd-level", "number", function()
    last_second = -1
    last_active_text = ""
    update_osd()
end)

-- Inizializzazione al caricamento del file
mp.register_event("file-loaded", function()
    actors = preprocess_intervals(load_annotations())
    mp.observe_property("time-pos", "number", update_osd)
    update_osd()
end)

-- Pulizia alla fine del file
mp.register_event("end-file", function()
    mp.set_osd_ass(0, 0, "")
    last_active_text = ""
    actors = {}
    sorted_actors = {}
end)
