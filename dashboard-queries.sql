-- Twitter Personality Analysis Dashboard Queries
-- Copy and paste these into Superset SQL Lab

-- =====================================================
-- Query 1: MBTI Distribution with Percentages
-- Use for: Bar Chart
-- =====================================================
SELECT 
    mbti_personality,
    COUNT(*) as tweet_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM tweets), 1) as percentage
FROM tweets 
WHERE mbti_personality != 'unknown'
GROUP BY mbti_personality 
ORDER BY tweet_count DESC;

-- =====================================================
-- Query 2: Tweet Volume Over Time (5-minute intervals)
-- Use for: Line Chart
-- =====================================================
SELECT 
    DATE_FORMAT(timestamp, '%Y-%m-%d %H:%i:00') as time_bucket,
    COUNT(*) as tweet_count,
    COUNT(DISTINCT user_id) as unique_users
FROM tweets 
GROUP BY DATE_FORMAT(timestamp, '%Y-%m-%d %H:%i:00')
ORDER BY time_bucket;

-- =====================================================
-- Query 3: Verification Analysis by MBTI
-- Use for: Stacked Bar Chart
-- =====================================================
SELECT 
    mbti_personality,
    SUM(CASE WHEN verified = 1 THEN 1 ELSE 0 END) as verified_count,
    SUM(CASE WHEN verified = 0 THEN 1 ELSE 0 END) as unverified_count,
    COUNT(*) as total_count,
    ROUND(SUM(CASE WHEN verified = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as verification_rate
FROM tweets 
WHERE mbti_personality != 'unknown'
GROUP BY mbti_personality 
ORDER BY verification_rate DESC;

-- =====================================================
-- Query 4: Real-time Tweet Feed
-- Use for: Table
-- =====================================================
SELECT 
    user_id,
    mbti_personality,
    CASE 
        WHEN verified = 1 THEN '✓ Verified'
        ELSE 'Not Verified'
    END as verification_status,
    LEFT(tweet, 80) as tweet_preview,
    timestamp,
    statuses_count
FROM tweets 
ORDER BY timestamp DESC 
LIMIT 25;

-- =====================================================
-- Query 5: Personality Dimensions Analysis
-- Use for: Pie Chart or Bar Chart
-- =====================================================
SELECT 
    CASE 
        WHEN mbti_personality LIKE '%E%' THEN 'Extrovert'
        ELSE 'Introvert'
    END as personality_dimension,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM tweets WHERE mbti_personality != 'unknown'), 1) as percentage
FROM tweets 
WHERE mbti_personality != 'unknown'
GROUP BY personality_dimension
UNION ALL
SELECT 
    CASE 
        WHEN mbti_personality LIKE '%S%' THEN 'Sensing'
        ELSE 'Intuition'
    END as personality_dimension,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM tweets WHERE mbti_personality != 'unknown'), 1) as percentage
FROM tweets 
WHERE mbti_personality != 'unknown'
GROUP BY personality_dimension
UNION ALL
SELECT 
    CASE 
        WHEN mbti_personality LIKE '%T%' THEN 'Thinking'
        ELSE 'Feeling'
    END as personality_dimension,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM tweets WHERE mbti_personality != 'unknown'), 1) as percentage
FROM tweets 
WHERE mbti_personality != 'unknown'
GROUP BY personality_dimension
UNION ALL
SELECT 
    CASE 
        WHEN mbti_personality LIKE '%J%' THEN 'Judging'
        ELSE 'Perceiving'
    END as personality_dimension,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM tweets WHERE mbti_personality != 'unknown'), 1) as percentage
FROM tweets 
WHERE mbti_personality != 'unknown'
GROUP BY personality_dimension;

-- =====================================================
-- Bonus Query 6: Hourly Tweet Activity Heatmap
-- Use for: Heatmap or Line Chart
-- =====================================================
SELECT 
    HOUR(timestamp) as hour_of_day,
    COUNT(*) as tweet_count,
    AVG(statuses_count) as avg_user_activity
FROM tweets 
GROUP BY HOUR(timestamp)
ORDER BY hour_of_day;

-- =====================================================
-- Bonus Query 7: Top Active Users by MBTI
-- Use for: Table
-- =====================================================
SELECT 
    mbti_personality,
    COUNT(*) as tweet_count,
    COUNT(DISTINCT user_id) as unique_users,
    ROUND(COUNT(*) / COUNT(DISTINCT user_id), 1) as tweets_per_user
FROM tweets 
WHERE mbti_personality != 'unknown'
GROUP BY mbti_personality 
ORDER BY tweets_per_user DESC;

-- =====================================================
-- Data Verification Queries
-- =====================================================

-- Check total data volume
SELECT 
    COUNT(*) as total_tweets,
    COUNT(DISTINCT user_id) as unique_users,
    MIN(timestamp) as first_tweet,
    MAX(timestamp) as latest_tweet,
    COUNT(DISTINCT mbti_personality) as mbti_types
FROM tweets;

-- Check data quality
SELECT 
    'Total Records' as metric,
    COUNT(*) as value
FROM tweets
UNION ALL
SELECT 
    'Records with MBTI' as metric,
    COUNT(*) as value
FROM tweets 
WHERE mbti_personality != 'unknown'
UNION ALL
SELECT 
    'Verified Users' as metric,
    SUM(CASE WHEN verified = 1 THEN 1 ELSE 0 END) as value
FROM tweets
UNION ALL
SELECT 
    'Records with Location' as metric,
    COUNT(*) as value
FROM tweets 
WHERE location != '';
