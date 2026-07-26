-- CineTrack Relational Schema (PostgreSQL DDL)
-- Documenting table constraints, indexes, and relationships.

-- Ensure timezone is set to UTC
SET timezone = 'UTC';

-- =========================================================================
-- 1. USERS TABLE
-- =========================================================================
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,
    username VARCHAR(100) UNIQUE NOT NULL,
    avatar_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_superuser BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Index username and email for rapid lookup during authentication
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);


-- =========================================================================
-- 2. WATCHLIST TABLE
-- =========================================================================
CREATE TABLE watchlist (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    media_id VARCHAR(100) NOT NULL,            -- TMDB id (stored as string to support extension)
    media_type VARCHAR(50) NOT NULL,          -- 'movie' or 'tv'
    title VARCHAR(255) NOT NULL,
    poster_path TEXT,
    added_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT unique_user_watchlist UNIQUE (user_id, media_id, media_type)
);

CREATE INDEX idx_watchlist_user ON watchlist(user_id);


-- =========================================================================
-- 3. FAVORITES TABLE
-- =========================================================================
CREATE TABLE favorites (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    media_id VARCHAR(100) NOT NULL,
    media_type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    poster_path TEXT,
    added_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT unique_user_favorites UNIQUE (user_id, media_id, media_type)
);

CREATE INDEX idx_favorites_user ON favorites(user_id);


-- =========================================================================
-- 4. RATINGS TABLE
-- =========================================================================
CREATE TABLE ratings (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    media_id VARCHAR(100) NOT NULL,
    media_type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    rating NUMERIC(3, 1) CHECK (rating >= 0.0 AND rating <= 10.0) NOT NULL, -- e.g., 8.5
    review TEXT,
    rated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT unique_user_rating UNIQUE (user_id, media_id, media_type)
);

CREATE INDEX idx_ratings_user ON ratings(user_id);
CREATE INDEX idx_ratings_media ON ratings(media_id, media_type);


-- =========================================================================
-- 5. WATCH HISTORY TABLE
-- =========================================================================
CREATE TABLE watch_history (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    media_id VARCHAR(100) NOT NULL,
    media_type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    poster_path TEXT,
    watched_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    season_number INT,                        -- Nullable (specific to 'tv')
    episode_number INT,                       -- Nullable (specific to 'tv')
    duration_watched_seconds INT              -- Playback time tracked
);

CREATE INDEX idx_watch_history_user ON watch_history(user_id);


-- =========================================================================
-- 6. CUSTOM LISTS TABLE
-- =========================================================================
CREATE TABLE custom_lists (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    is_private BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE INDEX idx_custom_lists_user ON custom_lists(user_id);


-- =========================================================================
-- 7. LIST ITEMS TABLE
-- =========================================================================
CREATE TABLE list_items (
    id BIGSERIAL PRIMARY KEY,
    list_id BIGINT REFERENCES custom_lists(id) ON DELETE CASCADE NOT NULL,
    media_id VARCHAR(100) NOT NULL,
    media_type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    poster_path TEXT,
    notes TEXT,                                -- User comments specifically for this list entry
    added_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT unique_list_item UNIQUE (list_id, media_id, media_type)
);

CREATE INDEX idx_list_items_list ON list_items(list_id);


-- =========================================================================
-- 8. CONTINUE WATCHING TABLE
-- =========================================================================
CREATE TABLE continue_watching (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    media_id VARCHAR(100) NOT NULL,
    media_type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    poster_path TEXT,
    season_number INT,                        -- Nullable
    episode_number INT,                       -- Nullable
    progress_seconds INT DEFAULT 0 NOT NULL,   -- Seconds played so far
    total_duration_seconds INT NOT NULL,       -- Total length in seconds
    last_watched_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT unique_user_continue_watching UNIQUE (user_id, media_id, media_type)
);

CREATE INDEX idx_continue_watching_user ON continue_watching(user_id);


-- =========================================================================
-- 9. COMMENTS TABLE
-- =========================================================================
CREATE TABLE comments (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    media_id VARCHAR(100) NOT NULL,
    media_type VARCHAR(50) NOT NULL,
    parent_id BIGINT REFERENCES comments(id) ON DELETE CASCADE, -- Recursive link for nested replies
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE INDEX idx_comments_media ON comments(media_id, media_type);
CREATE INDEX idx_comments_parent ON comments(parent_id);
CREATE INDEX idx_comments_user ON comments(user_id);


-- =========================================================================
-- 10. SEARCH HISTORY TABLE
-- =========================================================================
CREATE TABLE search_history (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    query VARCHAR(255) NOT NULL,
    searched_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE INDEX idx_search_history_user ON search_history(user_id);
CREATE INDEX idx_search_history_date ON search_history(searched_at);
