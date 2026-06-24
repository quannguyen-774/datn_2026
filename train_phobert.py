import json
import torch
import numpy as np
from datasets import Dataset
from transformers import (
    AutoTokenizer,
    AutoModelForSequenceClassification,
    Trainer,
    TrainingArguments,
    EarlyStoppingCallback
)
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, precision_recall_fscore_support
print("BƯỚC 1: Nạp dữ liệu 3 CỘT (Ngữ cảnh + Câu khách)...")
try:
    with open('dataset.json', 'r', encoding='utf-8') as f:
        data = json.load(f)
except FileNotFoundError:
    print("LỖI: Không tìm thấy file data!")
    exit()
bot_contexts = [str(item['bot_context']) for item in data]
user_texts = [str(item['user_text']) for item in data]
labels = [int(item['label']) for item in data]
train_contexts, val_contexts, train_texts, val_texts, train_labels, val_labels = train_test_split(
    bot_contexts, user_texts, labels, test_size=0.2, random_state=42
)
print("BƯỚC 2: Tải não bộ PhoBERT gốc từ VinAI...")
model_name = "vinai/phobert-base-v2"
tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModelForSequenceClassification.from_pretrained(model_name, num_labels=2)
def tokenize_data(contexts, texts, labels):
    encodings = tokenizer(contexts, texts, truncation=True, padding="max_length", max_length=128)
    return Dataset.from_dict({
        'input_ids': encodings['input_ids'],
        'attention_mask': encodings['attention_mask'],
        'labels': labels
    })
print("Đang mã hóa dữ liệu...")
train_dataset = tokenize_data(train_contexts, train_texts, train_labels)
val_dataset = tokenize_data(val_contexts, val_texts, val_labels)
def compute_metrics(pred):
    labels = pred.label_ids
    preds = pred.predictions.argmax(-1)
    precision, recall, f1, _ = precision_recall_fscore_support(labels, preds, average='binary', zero_division=0)
    acc = accuracy_score(labels, preds)
    return {'accuracy': acc, 'f1': f1, 'precision': precision, 'recall': recall}
print("BƯỚC 3: Bắt đầu huấn luyện...")
training_args = TrainingArguments(
    output_dir='./results',
    num_train_epochs=10,
    per_device_train_batch_size=16,
    per_device_eval_batch_size=16,
    learning_rate=2e-5,
    eval_strategy="epoch",
    save_strategy="epoch",
    load_best_model_at_end=True,
    metric_for_best_model="f1",
    logging_dir='./logs',
    seed=42
)
trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=train_dataset,
    eval_dataset=val_dataset,
    compute_metrics=compute_metrics,
    callbacks=[EarlyStoppingCallback(early_stopping_patience=2)] # Nếu 2 vòng liên tiếp F1 không tăng -> Cắt cầu dao!
)

trainer.train()
print("\nĐÃ TRAIN XONG!...")
save_path = "./phobert_endturn"
model.save_pretrained(save_path)
tokenizer.save_pretrained(save_path)
print(f"Lưu trong thư mục: {save_path}")
