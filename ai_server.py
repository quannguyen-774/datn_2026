import os
import re
import json
import psycopg2
from fastapi import FastAPI, Request
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from transformers import pipeline
from openai import AsyncOpenAI
app = FastAPI()
# ĐƯỜNG DẪN TỚI FILE ÂM THANH FILLER
DIR_CHO = "/var/lib/freeswitch/recordings/fillers/cho"
DIR_CHOT = "/var/lib/freeswitch/recordings/fillers/chot"
# 1. CẤU HÌNH API OPENAI QUA SHUPREMIUM
ai_client = AsyncOpenAI(
    base_url="https://api.groq.com/openai/v1",
api_key="$API_LLM"
)
# CẤU HÌNH DATABASE
DB_CONFIG = {
    "host": "127.0.0.1",
    "port": "5432",
    "dbname": "fusionpbx",
    "user": "fusionpbx",
    "password": "fusionpbx"
}
# BỘ NHỚ TẠM VÀ SỰ KIỆN ETD
memory = {}
speech_accumulator = {}
MODEL_PATH = "./phobert_endturn"
print("Đang nạp Model PhoBERT ETD...")
try:
    etd_model = pipeline("text-classification", model=MODEL_PATH, device=-1)
    print("Đã nạp ETD thành công!")
except Exception as e:
    print(f"Lỗi nạp ETD: {e}")
    etd_model = None
# HÀM BỔ TRỢ: ĐỌC PROMPT & LƯU DATABASE
def read_prompt_file(file_path="prompt.txt") -> str:
    """Đọc kịch bản chữ từ file prompt.txt"""
    if not os.path.exists(file_path):
        return "Bạn là trợ lý ảo tổng đài. Hãy trả lời ngắn gọn, tự nhiên bằng tiếng Việt."
    try:
        with open(file_path, mode='r', encoding='utf-8') as file:
            return file.read().strip()
    except Exception:
        return "Bạn là trợ lý ảo tổng đài."

def save_to_db(uuid: str, speaker: str, message: str, action: str = "none"):
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO ai_logs (uuid, speaker, message, action) VALUES (%s, %s, %s, %s)",
            (uuid, speaker, message, action)
        )
        conn.commit()
        cur.close()
        conn.close()
        print(f"[DB] Đã lưu log: {speaker.upper()} - {message[:50]}...")
    except Exception as e:
        print(f"[DB ERROR] Lỗi lưu DB: {e}")
# API ENDPOINT CHÍNH (KẾT NỐI VỚI LUA)
@app.post("/chat")
async def chat_with_ai_stream(req: Request):
    try:
        data = await req.json()
    except:
        return {"error": "Invalid JSON format"}
    uuid = data.get("uuid")
    new_text = data.get("text")

    if not uuid or not new_text:
        return {"error": "Missing uuid or text"}
    # 1. CỘNG DỒN CÂU CHỮ CỦA KHÁCH
    if uuid not in speech_accumulator:
        speech_accumulator[uuid] = ""
    speech_accumulator[uuid] = (speech_accumulator[uuid] + " " + new_text).strip()
    full_text_clean = re.sub(r'[^\w\s]', '', speech_accumulator[uuid]).strip()
    print(f"\nKhách đang nói: '{full_text_clean}'")
    # 2. CHẠY ETD KIỂM TRA XEM KHÁCH ĐÃ NÓI XONG CHƯA
    is_waiting = False
    if etd_model and full_text_clean:
        bot_context = memory[uuid][-1]["content"] if (uuid in memory and len(memory[uuid]) > 0) else "Xin chào"
        etd_input = f"{bot_context} </s></s> {full_text_clean.lower()}"
        result = etd_model(etd_input)[0]
        if result['label'] == 'LABEL_0' and result['score'] > 0.85:
            is_waiting = True
    # 3. LUỒNG XỬ LÝ STREAMING
    async def generate_openai_stream():
        FILE_WAIT = os.path.join(DIR_CHO, "no_1.wav")
        FILE_CONFIRM = os.path.join(DIR_CHOT, "yes_1.wav")
        if is_waiting:
            print("ETD: Khách ngập ngừng -> Đợi nói tiếp...")
            if os.path.exists(FILE_WAIT):
                # Chuẩn hóa JSON: Luôn có đủ 4 key để Lua không bị lỗi
                yield json.dumps({"text_chunk": "null", "action": "playback", "file": FILE_WAIT, "extension": "null"}, ensure_ascii=False) + "\n"
            # Gửi lệnh wait để Lua tiếp tục giữ line
            yield json.dumps({"text_chunk": "null", "action": "wait", "file": "null", "extension": "null"}, ensure_ascii=False) + "\n"
            return
        print("ETD: Đã chốt! Đang gọi Shupremium OpenAI...")
        if os.path.exists(FILE_CONFIRM):
            yield json.dumps({"text_chunk": "null", "action": "playback", "file": FILE_CONFIRM, "extension": "null"}, ensure_ascii=False) + "\n"
            print(f"Đã bơm âm thanh chốt cố định: {FILE_CONFIRM}")
        user_final_text = speech_accumulator[uuid]
        speech_accumulator[uuid] = ""
        save_to_db(uuid, "user", user_final_text)
        system_prompt = read_prompt_file("prompt.txt")
        if uuid not in memory:
            memory[uuid] = [{"role": "system", "content": system_prompt}]
        else:
            if memory[uuid] and memory[uuid][0]["role"] == "system":
                memory[uuid][0]["content"] = system_prompt
        memory[uuid].append({"role": "user", "content": user_final_text})
        full_ai_response = ""
        current_sentence = ""
        try:
            stream_response = await ai_client.chat.completions.create(
                model="llama-3.1-8b-instant",
                messages=memory[uuid],
                stream=True,
                timeout=15.0
            )
            async for chunk in stream_response:
                if chunk.choices and chunk.choices[0].delta.content:
                    text_chunk = chunk.choices[0].delta.content
                    full_ai_response += text_chunk
                    current_sentence += text_chunk
                    if any(p in text_chunk for p in ['.', '?', '!', '\n']):
                        sentence_to_send = current_sentence.strip()
                        if sentence_to_send:
                            action_type = "none"
                            ext_num = "null"
                            lower_sentence = sentence_to_send.lower()
                            if "kết thúc cuộc gọi" in lower_sentence:
                                action_type = "hangup"
                            elif "chuyển máy" in lower_sentence:
                                action_type = "transfer"
                                ext_num = "102"
                            yield json.dumps({"text_chunk": sentence_to_send, "action": action_type, "file": "null", "extension": ext_num}, ensure_ascii=False) + "\n"
                        current_sentence = ""
            # Xử lý đoạn text còn sót lại cuối cùng (nếu có)
            if current_sentence.strip():
                action_type = "none"
                ext_num = "null"
                lower_sentence = current_sentence.strip().lower()
                if "kết thúc cuộc gọi" in lower_sentence:
                    action_type = "hangup"
                elif "chuyển máy" in lower_sentence:
                    action_type = "transfer"
                    ext_num = "100"
                yield json.dumps({"text_chunk": current_sentence.strip(), "action": action_type, "file": "null", "extension": ext_num}, ensure_ascii=False) + "\n"
            print(f"-----> AI TRẢ LỜI: {full_ai_response}")
            save_to_db(uuid, "ai", full_ai_response)
            memory[uuid].append({"role": "assistant", "content": full_ai_response})
        except Exception as e:
            print(f"Lỗi OpenAI API: {e}")
            yield json.dumps({"text_chunk": "Xin lỗi, máy chủ đang bận.", "action": "none", "file": "null", "extension": "null"}, ensure_ascii=False) + "\n"
    return StreamingResponse(generate_openai_stream(), media_type="application/x-ndjson")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
