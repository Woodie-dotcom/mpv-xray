-- annotations_api.lua
-- Versione modificata per usare l'API backend tramite lua-socket
-- annotations_api.lua (Versione con lua-socket installato da apt)

local mp_msg = require 'mp.msg'
local ass = require 'mp.assdraw'

-- === LIBRERIE (Caricamento Semplificato) ===
-- Prova a caricare socket.* dal sistema, json/ltn12 da libs
-- Assumiamo che json.lua e ltn12.lua siano in libs/

-- Aggiungiamo il percorso per 'libs' al path per json e ltn12
local script_dir = debug.getinfo(1, "S").source:match("@?(.*[/\\])") or ""
local libs_search_path = script_dir .. 'libs/?.lua;'
package.path = package.path .. ';' .. libs_search_path
mp_msg.warn("PACKAGE.PATH con libs: " .. package.path) -- Verifica

-- Carica le librerie
local ok_json, json = pcall(require, 'json')           -- Cerca libs/json.lua
local ok_ltn12, ltn12 = pcall(require, 'ltn12')         -- Cerca libs/ltn12.lua
local ok_http, http = pcall(require, 'socket.http')    -- Cerca nei percorsi di sistema
local ok_url, url = pcall(require, 'socket.url')       -- Cerca nei percorsi di sistema

-- Verifica caricamento librerie essenziali (con messaggi dettagliati)
if not ok_json then
    local err_msg = json
    mp_msg.error("Errore caricando 'json': " .. tostring(err_msg))
    mp_msg.error("Controlla 'PACKAGE.PATH con libs' e la presenza/permessi di 'libs/json.lua'.")
    return
end
if not ok_ltn12 then
    local err_msg = ltn12
    mp_msg.error("Errore caricando 'ltn12': " .. tostring(err_msg))
    mp_msg.error("Controlla 'PACKAGE.PATH con libs' e la presenza/permessi di 'libs/ltn12.lua'.")
    return
end
if not ok_url then
    local err_msg = url
    mp_msg.error("Errore caricando 'socket.url': " .. tostring(err_msg))
    mp_msg.error("Potrebbe mancare lua-socket di sistema (sudo apt install lua-socket)?")
    return
end
if not ok_http then
    local err_msg = http
    mp_msg.error("Errore caricando 'socket.http': " .. tostring(err_msg))
    mp_msg.error("Potrebbe mancare lua-socket di sistema (sudo apt install lua-socket)?")
    return
end

mp_msg.info("Librerie JSON e Socket caricate con successo.")

-- === CONFIGURAZIONE ===
local config = {
    api_base_url = "http://localhost:8123",
    osd_style = "{\\an7\\fs20\\b1\\c&HFFFFFF&\\fnNoto Sans}",
}

mp_msg.info("Script annotations_api.lua caricato correttamente (usando lua-socket di sistema).")

mp_msg.info("API Base URL: " .. config.api_base_url)

-- === VARIABILI GLOBALI ===
local actors = {}
local sorted_actors = {}
local last_active_text = nil
local last_second = -1

-- === FUNZIONI HELPER ===

local function get_video_filename()
    local path = mp.get_property("path")
    if not path then
        mp_msg.warn("Nessun percorso video disponibile")
        return nil
    end
    local filename = path:match("^.+/(.+)$") or path:match("^.+\\(.+)$") or path
    mp_msg.debug("Nome file video ottenuto: " .. filename)
    return filename
end

local function parse_timestamp(ts)
    local h, m, s = ts:match("^(%d+):(%d+):(%d+%.?%d*)$")
    if not (h and m and s) then
        mp_msg.error("Formato timestamp non valido ricevuto dall'API: " .. ts)
        return nil
    end
    h, m, s = tonumber(h), tonumber(m), tonumber(s)
    if h < 0 or m < 0 or m > 59 or s < 0 or s >= 60 then
        mp_msg.error("Valori timestamp fuori range: " .. ts)
        return nil
    end
    return h * 3600 + m * 60 + s
end

-- === FUNZIONE PRINCIPALE DI CARICAMENTO DATI (RIFATTA con lua-socket) ===

-- Carica le annotazioni dall'API backend usando lua-socket http.request
local function load_annotations_from_api()
    local video_filename = get_video_filename()
    if not video_filename then
        mp_msg.warn("Impossibile ottenere il nome del file video per interrogare l'API.")
        return {}
    end

    -- Costruiamo l'URL. http.request gestisce l'encoding dei parametri di base.
    -- Per sicurezza potremmo usare url.build, ma proviamo semplice prima.
    local api_url = config.api_base_url .. "/api/v1/annotations?filename=" .. url.escape(video_filename) -- url.escape per sicurezza

    mp_msg.info("Richiesta API (lua-socket) a: " .. api_url)

    -- Prepariamo una tabella per raccogliere il corpo della risposta con LTN12
    local response_body_parts = {}
    -- Eseguiamo la richiesta HTTP GET
    -- Usiamo la forma tabellare di http.request per impostare headers e sink
    local ok, code, headers, status = http.request{
        url = api_url,
        method = "GET",
        headers = { ["Accept"] = "application/json" },
        -- sink: funzione che riceve i pezzi del corpo della risposta
        -- ltn12.sink.table appende i pezzi alla tabella fornita
        sink = ltn12.sink.table(response_body_parts)
    }

    -- Controllo errori di connessione/rete (ok è nil, code contiene l'errore)
    if not ok then
        mp_msg.error("Errore di rete o connessione API: " .. tostring(code))
        return {}
    end

    -- Controllo codice di stato HTTP (ok è true, code contiene lo status code numerico)
    if code ~= 200 then
        mp_msg.error("Errore HTTP dall'API: " .. code .. " " .. status)
        -- Proviamo a unire e decodificare il corpo anche in caso di errore,
        -- potrebbe contenere un JSON con dettagli (es. {"detail": "..."})
        local error_body_str = table.concat(response_body_parts)
        local _, decoded_error = pcall(json.decode, error_body_str or "")
        if decoded_error and decoded_error.detail then
             mp_msg.error("Dettaglio errore API: " .. decoded_error.detail)
        -- Se l'errore è 404, lo trattiamo come "non trovato" senza loggare come errore grave
        elseif code == 404 then
             mp_msg.warn("API ha risposto 404 Not Found per il file: " .. video_filename)
        end
        return {} -- Restituisce tabella vuota per errori HTTP != 200
    end

    -- Successo! Codice HTTP 200 OK.
    -- Uniamo i pezzi del corpo della risposta in un'unica stringa
    local json_body_str = table.concat(response_body_parts)

    if not json_body_str or json_body_str == "" then
        mp_msg.warn("L'API ha risposto con successo (200 OK) ma corpo vuoto.")
        return {}
    end

    -- Decodifica il JSON ricevuto
    local success, decoded_data = pcall(json.decode, json_body_str)
    if not success then
        mp_msg.error("Errore nel parsing del JSON ricevuto dall'API: " .. tostring(decoded_data))
        mp_msg.error("JSON Ricevuto: " .. json_body_str)
        return {}
    end

    -- Decodifica riuscita
    mp_msg.info("Annotazioni caricate con successo dall'API (lua-socket).")
    return decoded_data
end


-- === FUNZIONE DI PRE-PROCESSING  ===
local function preprocess_intervals(raw_data_from_api)
    -- ... (codice identico a prima) ...
    local processed = {}
    for actor, intervals in pairs(raw_data_from_api) do
        processed[actor] = {}
        for _, interval_str in ipairs(intervals) do
            local start_ts = parse_timestamp(interval_str[1])
            local end_ts = parse_timestamp(interval_str[2])
            if start_ts and end_ts then
                if start_ts <= end_ts then
                    table.insert(processed[actor], {start_ts, end_ts})
                else
                    mp_msg.warn("Intervallo non valido per " .. actor .. ": " .. interval_str[1] .. " > " .. interval_str[2])
                end
            else
                 mp_msg.warn("Timestamp non valido ignorato per " .. actor .. ": [" .. interval_str[1] .. ", " .. interval_str[2] .. "]")
            end
        end
        if #processed[actor] == 0 then
            processed[actor] = nil
            mp_msg.warn("Attore rimosso per mancanza di intervalli validi: " .. actor)
        end
    end
    sorted_actors = {}
    for actor in pairs(processed) do
        table.insert(sorted_actors, actor)
    end
    table.sort(sorted_actors)
    mp_msg.debug("Dati pre-processati e attori ordinati.")
    return processed
    -- ... (fine codice identico) ...
end


-- === FUNZIONE AGGIORNAMENTO OSD ===
local function update_osd()
    -- ... (codice identico a prima) ...
    local osd_level = mp.get_property_number("osd-level", 3)
    if osd_level < 1 then
        if last_active_text ~= "" then
            mp.set_osd_ass(0, 0, "")
            last_active_text = ""
        end
        return
    end
    local time = mp.get_property_number("time-pos")
    if not time then return end
    local current_second = math.floor(time)
    if current_second == last_second then
        return
    end
    last_second = current_second
    local active = {}
    if next(actors) ~= nil then
        for _, actor in ipairs(sorted_actors) do
            local intervals = actors[actor]
            if intervals then
                for _, interval in ipairs(intervals) do
                    if time >= interval[1] and time <= interval[2] then
                        table.insert(active, actor)
                        break
                    end
                end
            end
        end
    end
    local new_active_text = #active > 0 and config.osd_style .. table.concat(active, "\\N") or ""
    if new_active_text ~= last_active_text then
        mp.set_osd_ass(0, 0, new_active_text)
        last_active_text = new_active_text
    end
    -- ... (fine codice identico) ...
end


-- === GESTIONE EVENTI MPV (Logica Principale Invariata, usa nuova funzione di load) ===

mp.observe_property("osd-level", "number", function(_, level)
    mp_msg.debug("OSD level cambiato a: " .. tostring(level))
    last_second = -1
    last_active_text = nil
    update_osd()
end)

mp.register_event("file-loaded", function()
    mp_msg.info("Evento file-loaded ricevuto.")
    actors = {}
    sorted_actors = {}
    last_active_text = nil
    last_second = -1
    mp.set_osd_ass(0, 0, "")

    local raw_data = load_annotations_from_api() -- Chiama la nuova funzione
    actors = preprocess_intervals(raw_data)

    mp.observe_property("time-pos", "number", update_osd)
    update_osd()
end)

mp.register_event("end-file", function()
    mp_msg.info("Evento end-file ricevuto.")
    mp.set_osd_ass(0, 0, "")
    last_active_text = nil
    actors = {}
    sorted_actors = {}
    last_second = -1
    mp.unobserve_property(update_osd)
end)

mp.register_event("shutdown", function()
     mp_msg.info("Script annotations_api.lua unloading.")
     mp.set_osd_ass(0, 0, "")
     mp.unobserve_property(update_osd)
end)
