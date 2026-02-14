# 🧠 BrainDump: The Context-Aware Second Brain

> **"Your thoughts don't happen in a vacuum. Neither should your notes."**

![Status](https://img.shields.io/badge/Status-In%20Development-orange?style=for-the-badge)
![Stack](https://img.shields.io/badge/Stack-Flutter%20%7C%20FastAPI%20%7C%20PostgreSQL-blue?style=for-the-badge)
![AI](https://img.shields.io/badge/AI-OpenAI%20%2B%20Llama3-purple?style=for-the-badge)

<br>

## 💡 The Vision

Most note-taking apps are just **digital graveyards**. You dump ideas in, and they disappear forever.

**BrainDump** is different. It is an **Agentic Knowledge Graph** that doesn't just store your text; it captures your **State of Mind**.

* **🎧 Passively Records Context:** What were you listening to? (Spotify) Where were you? (Location) What was the vibe? (Energy Level).
* **🧠 Active Recall:** An AI Agent ("The Subconscious") that connects your past notes to your current problems.
* **🔮 Clarity Engine:** It detects when you are scattered or anxious and forces you to prioritize.

---

## 📱 The Interface
*Current Build: Neural Onboarding & Adaptive Dashboard*

| **The Hook** | **The Dump** | **The Calibration** | **The Focus HUD** |
|:---:|:---:|:---:|:---:|
| <img src="https://github.com/user-attachments/assets/504d92fb-4ca9-4fc0-9cc6-7050b737d18a" width="200" /> | <img src="https://github.com/user-attachments/assets/7260203e-a893-4768-9aa5-3bade8530867" width="200" /> | <img src="https://github.com/user-attachments/assets/5696988f-6552-4cdd-b015-f3cc82b9db90" width="200" /> | <img src="https://github.com/user-attachments/assets/6234b5ae-9104-4ccf-832d-de546f3be7ce" width="200" /> |
| *Initial System Link* | *Raw "RAM" Clear* | *Context Awareness* | *Energy-Based UI* |

---

## 🏗️ Tech Stack

### **Mobile (Frontend)**
* **Framework:** [Flutter](https://flutter.dev/) (Dart)
* **State Management:** Riverpod (Feature-first architecture)
* **UI/UX:** Custom "Neural" RenderObject animations, Glassmorphism, Haptic Feedback.
* **Local Storage:** Hive / SQLite (for offline-first capability).

### **Core (Backend)**
* **API:** [FastAPI](https://fastapi.tiangolo.com/) (Python, Async)
* **Database:** PostgreSQL + `pgvector` (Vector Embeddings for Semantic Search).
* **AI Orchestration:** LangChain / Custom Agent logic.
* **Models:** OpenAI GPT-4o-mini (Intelligence) + Groq Llama-3 (Speed).
* **Task Queue:** Celery + Redis (for background embedding generation).

---

## ✨ Roadmap

### **Phase 1: The Foundation (Current)**
- [x] **Neural Onboarding:** "Mad Libs" style user calibration (Energy, Goals, Music).
- [x] **Adaptive Dashboard:** Home screen that changes UI based on user energy.
- [ ] **The "Peeking Dock":** A distraction-free UI to capture thoughts instantly.
- [ ] **Context Injection:** Attaching metadata (Time, Mood) to every note.

### **Phase 2: The Brain (Q2 2026)**
- [ ] **Vector Search:** "Show me ideas I had when I was anxious about my startup."
- [ ] **The Clarity Agent:** A nightly cron job that analyzes your "Brain Dump" and gives you a 1-sentence focus for the next day.
- [ ] **Graph View:** Visualizing thoughts as organic, connecting roots.

### **Phase 3: The Senses (Q3 2026)**
- [ ] **Spotify Integration:** "Play the song I was listening to when I wrote this code."
- [ ] **Kindle Sync:** Pulling highlights into the graph.

---

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (3.x+)
* Docker (for the Backend + DB)
* Python 3.10+

### 1. Clone the Repo
```bash
git clone [https://github.com/YOUR_USERNAME/brain-dump.git](https://github.com/YOUR_USERNAME/brain-dump.git)
cd brain-dump
