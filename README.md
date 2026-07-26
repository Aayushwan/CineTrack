# CineTrack 🎬

CineTrack is a premium, responsive full-stack web application designed for movie and television show tracking. Users can manage their watchlists, catalog favorites, rate content, organize custom collections, track what they are currently watching, interact with the community via comments, and search content seamlessly.

---

## 🚀 Tech Stack

- **Frontend:** Flutter Web (responsive layout, interactive, beautiful design)
- **Backend:** FastAPI (Python 3.10+, asynchronous endpoints, Pydantic settings)
- **Database:** PostgreSQL (structured relational schema with foreign key integrity)
- **Database Access:** SQLAlchemy 2.0 (Async Engine & Async Sessions) with `asyncpg`

---

## 📂 Project Directory Structure

```text
CineTrack/
├── backend/                  # FastAPI Application
│   ├── app/
│   │   ├── core/
│   │   │   └── config.py     # Pydantic Settings & Environment Configurations
│   │   ├── db/
│   │   │   └── session.py    # SQLAlchemy Async Engine & Session Dependency
│   │   └── main.py           # Application Entrypoint & CORS Middleware
│   ├── .env.example          # Template for backend settings
│   └── requirements.txt      # Python dependencies
│
├── database/                 # Database Schema & DDL
│   └── schema.sql            # PostgreSQL relational table definitions
│
├── frontend/                 # Flutter Web Application (Workspace)
│   └── .gitkeep
│
├── docs/                     # Visual Assets & Design Documentation
│   └── .gitkeep
│
├── .gitignore                # Global ignore configuration
└── README.md                 # Project Overview & Quick Start
```

---

## 🛠️ Getting Started

### 1. Database Setup
Ensure PostgreSQL is running locally or remotely, then initialize the database tables:
```bash
psql -U your_user -d cinetrack -f database/schema.sql
```

### 2. Backend Setup
Navigate to the `backend/` directory and install the requirements:
```bash
cd backend
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
pip install -r requirements.txt
```
Copy `.env.example` to `.env` and adjust settings:
```bash
cp .env.example .env
```
Start the development server:
```bash
uvicorn app.main:app --reload
```

### 3. Frontend Setup
Navigate to the `frontend/` directory and run:
```bash
cd frontend
flutter pub get
flutter run -d chrome
```

---

## 📊 Database Schema Features
The system maintains the following relational tables:
1. **users**: Authentication details and security roles.
2. **watchlist**: Media items users plan to watch.
3. **favorites**: Liked items pinned to profiles.
4. **ratings**: Numeric scores and textual reviews.
5. **watch_history**: Logs of watched movies/TV episodes.
6. **custom_lists**: Groupings of media curated by users.
7. **list_items**: The individual media titles inside custom lists.
8. **continue_watching**: Resume playback states.
9. **comments**: Discussion board items (self-referential for threaded comments).
10. **search_history**: Log of terms searched for analytics/recent history.
