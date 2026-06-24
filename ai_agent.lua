-- 1. CẤU HÌNH CƠ BẢN
local fpt_key = "pWWJFCJoLVlKcC6prqVOV8TZr60BbzWO"
local backend_url = "http://127.0.0.1:8000/chat" -- Chú ý chỉnh port khớp với Python
local tmp_dir = "/tmp/"
local domain = session:getVariable("domain_name")
-- 2. HÀM ĐỌC GIỌNG NÓI (TTS) 
local function play_tts(text)
    if text == nil or text == "" or text == "null" then return "none" end
    freeswitch.consoleLog("INFO", "--- AI DANG NOI: " .. text .. " ---\n")
    local safe_text = text:gsub('"', ''):gsub("'", ""):gsub("\n", " "):gsub("\r", "")
    local uuid = session:get_uuid()
    local output_audio = tmp_dir .. "ai_output_" .. uuid .. ".mp3"
    local tts_api_cmd = string.format([[curl -s -X POST -H "api-key: %s" -H "voice: banmai" -d "%s" https://api.fpt.ai/hmi/tts/v5]], fpt_key, safe_text)
    local f_tts = io.popen(tts_api_cmd)
    local raw_json = f_tts:read("*a")
    f_tts:close()
    local tts_url = string.match(raw_json, '"async"%s*:%s*"([^"]+)"')
    if tts_url ~= nil and tts_url ~= "" then
        local ready = false
        for i = 1, 10 do
            os.execute(string.format([[curl -L -k -s -o %s "%s"]], output_audio, tts_url))
            local f = io.open(output_audio, "r")
            if f then
                local size = f:seek("end")
                f:close()
                if size > 1000 then
                    ready = true
                    break
                end
            end
            os.execute("sleep 0.5")
        end
        if ready then
            session:streamFile(output_audio)
            os.remove(output_audio)
            return "played"
        else
            freeswitch.consoleLog("ERROR", ">>> LOI: TAI FILE FPT QUA LAU HOAC FILE RONG! <<<\n")
            os.remove(output_audio)
            return "error"
        end
    else
        return "error"
    end
end

-- 3. KHỞI TẠO CUỘC GỌI
session:answer()
session:sleep(1000)
freeswitch.consoleLog("INFO", "AI Agent da nhac may!\n")
-- 4. MAIN LOOP
while session:ready() do
    local uuid = session:get_uuid()
    local input_audio = tmp_dir .. "caller_" .. uuid .. ".wav"
    local payload_file = tmp_dir .. "payload_" .. uuid .. ".json"
    -- BƯỚC A: GHI ÂM KHÁCH NÓI
    freeswitch.consoleLog("INFO", "--- DANG NGHE KHACH NOI ---\n")
    session:recordFile(input_audio, 10, 200, 1)
    -- BƯỚC B: CHUYỂN GIỌNG NÓI THÀNH VĂN BẢN (STT)
    local stt_cmd = string.format([[curl -s -X POST -H "api-key: %s" -T %s https://api.fpt.ai/hmi/asr/general | jq -r '.hypotheses[0].utterance']], fpt_key, input_audio)
    local f_stt = io.popen(stt_cmd)
    local user_text = f_stt:read("*a"):gsub("^%s*(.-)%s*$", "%1")
    f_stt:close()
    os.remove(input_audio)
    -- BƯỚC C: XỬ LÝ NẾU KHÁCH CÓ NÓI
    if user_text ~= "" and user_text ~= "null" then
        freeswitch.consoleLog("INFO", "Khach noi: " .. user_text .. "\n")
        -- BƯỚC D: GỌI PYTHON BACKEND (STREAMING)
        local safe_user_text = user_text:gsub('"', '\\"')
        local json_payload = string.format('{"uuid": "%s", "text": "%s"}', uuid, safe_user_text)
        local file = io.open(payload_file, "w")
        file:write(json_payload)
        file:close()
        local backend_cmd = string.format([[curl -m 15 -N -s -X POST %s -H "Content-Type: application/json" -d @%s]], backend_url, payload_file)
        local f_backend = io.popen(backend_cmd)
        local final_action = "none"
        local final_extension = "null"
        -- BƯỚC E: ĐỌC TỪNG CÂU TỪ PYTHON VÀ PHÁT TTS
        for line in f_backend:lines() do
            if line ~= "" and line:match("{") then
                local text_chunk = line:match('"text_chunk"%s*:%s*"([^"]+)"')
                local action = line:match('"action"%s*:%s*"([^"]+)"')
                local extension = line:match('"extension"%s*:%s*"([^"]+)"')
                local audio_file = line:match('"file"%s*:%s*"([^"]+)"')
                if text_chunk then text_chunk = text_chunk:gsub('\\"', '"') end
                -- XỬ LÝ PHÁT ÂM THANH FILLER TRƯỚC
                if action == "playback" and audio_file and audio_file ~= "null" and audio_file ~= "" then
                    freeswitch.consoleLog("INFO", "--- DANG PHAT FILLER: " .. audio_file .. " ---\n")
                    session:streamFile(audio_file)
                end

                -- XỬ LÝ TÍN HIỆU ETD BẢO ĐỢI
                if action == "wait" then
                    freeswitch.consoleLog("INFO", "ETD: Khach ngap ngung, quay lai ghi am tiep...\n")
                    break -- Thoát vòng lặp Backend để quay lại Ghi âm
                end
                -- LƯU LẠI LỆNH TRANSFER/HANGUP (NẾU CÓ)
                if action and action ~= "none" and action ~= "null" and action ~= "wait" and action ~= "playback" then
                    final_action = string.upper(action)
                    final_extension = extension or "null"
                end
                -- MANG ĐI ĐỌC TTS
                if text_chunk and text_chunk ~= "null" and text_chunk ~= "" then
                    play_tts(text_chunk)
                end
            end
        end
        f_backend:close()
        os.remove(payload_file)
        -- BƯỚC F: ĐIỀU PHỐI CUỘC GỌI
        if final_action == "TRANSFER" and final_extension ~= "null" then
            freeswitch.consoleLog("INFO", "DA NHAN LENH CHUYEN MAY SANG: " .. final_extension .. "\n")
            session:transfer(final_extension, "XML", domain)
            return
        elseif final_action == "HANGUP" then
            freeswitch.consoleLog("INFO", "DA NHAN LENH CUP MAY!\n")
            session:hangup()
            return
        end
        if not session:ready() then
            break
        end
        freeswitch.msleep(100)
    end
end
