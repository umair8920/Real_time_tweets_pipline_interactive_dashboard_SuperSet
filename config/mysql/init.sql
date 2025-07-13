CREATE DATABASE IF NOT EXISTS twitter_analytics;
USE twitter_analytics;

CREATE TABLE IF NOT EXISTS tweets (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    screen_name VARCHAR(255),
    tweet TEXT,
    timestamp DATETIME,
    iso_timestamp DATETIME,
    location VARCHAR(255),
    verified BOOLEAN DEFAULT FALSE,
    statuses_count BIGINT DEFAULT 0,
    mbti_personality VARCHAR(10),
    total_retweet_count BIGINT DEFAULT 0,
    total_favorite_count BIGINT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_screen_name (screen_name),
    INDEX idx_mbti (mbti_personality),
    INDEX idx_timestamp (timestamp)
);

-- Create aggregated views for analytics
CREATE VIEW user_tweet_stats AS
SELECT 
    user_id,
    screen_name,
    mbti_personality,
    location,
    verified,
    COUNT(*) as tweet_count,
    AVG(statuses_count) as avg_statuses_count,
    AVG(total_retweet_count) as avg_retweet_count,
    AVG(total_favorite_count) as avg_favorite_count,
    MIN(timestamp) as first_tweet,
    MAX(timestamp) as last_tweet
FROM tweets 
GROUP BY user_id, screen_name, mbti_personality, location, verified;

CREATE VIEW mbti_analytics AS
SELECT 
    mbti_personality,
    COUNT(*) as total_tweets,
    COUNT(DISTINCT user_id) as unique_users,
    AVG(statuses_count) as avg_statuses_count,
    AVG(total_retweet_count) as avg_retweet_count,
    AVG(total_favorite_count) as avg_favorite_count
FROM tweets 
WHERE mbti_personality != 'unknown'
GROUP BY mbti_personality;

CREATE VIEW hourly_tweet_volume AS
SELECT 
    DATE_FORMAT(timestamp, '%Y-%m-%d %H:00:00') as hour,
    COUNT(*) as tweet_count,
    COUNT(DISTINCT user_id) as unique_users
FROM tweets 
GROUP BY DATE_FORMAT(timestamp, '%Y-%m-%d %H:00:00')
ORDER BY hour;
