import json
import logging
import os
import time
from datetime import datetime
from kafka import KafkaConsumer
import mysql.connector
from mysql.connector import Error

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Configuration
KAFKA_BOOTSTRAP_SERVERS = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')
KAFKA_TOPIC = os.getenv('KAFKA_TOPIC', 'twitter-tweets')
MYSQL_HOST = os.getenv('MYSQL_HOST', 'localhost')
MYSQL_PORT = int(os.getenv('MYSQL_PORT', 3306))
MYSQL_DATABASE = os.getenv('MYSQL_DATABASE', 'twitter_analytics')
MYSQL_USER = os.getenv('MYSQL_USER', 'twitter_user')
MYSQL_PASSWORD = os.getenv('MYSQL_PASSWORD', 'twitter_password')

class KafkaToMySQLConsumer:
    def __init__(self):
        self.consumer = None
        self.mysql_connection = None
        self.setup_kafka_consumer()
        self.setup_mysql_connection()
    
    def setup_kafka_consumer(self):
        """Set up Kafka consumer"""
        try:
            self.consumer = KafkaConsumer(
                KAFKA_TOPIC,
                bootstrap_servers=[KAFKA_BOOTSTRAP_SERVERS],
                auto_offset_reset='earliest',
                enable_auto_commit=True,
                group_id='mysql-consumer-group',
                value_deserializer=lambda x: json.loads(x.decode('utf-8'))
            )
            logger.info(f"Kafka consumer connected to {KAFKA_BOOTSTRAP_SERVERS}")
        except Exception as e:
            logger.error(f"Error setting up Kafka consumer: {e}")
            raise
    
    def setup_mysql_connection(self):
        """Set up MySQL connection"""
        max_retries = 10
        retry_count = 0
        
        while retry_count < max_retries:
            try:
                self.mysql_connection = mysql.connector.connect(
                    host=MYSQL_HOST,
                    port=MYSQL_PORT,
                    database=MYSQL_DATABASE,
                    user=MYSQL_USER,
                    password=MYSQL_PASSWORD,
                    autocommit=True
                )
                logger.info(f"MySQL connection established to {MYSQL_HOST}:{MYSQL_PORT}")
                break
            except Error as e:
                retry_count += 1
                logger.warning(f"MySQL connection attempt {retry_count} failed: {e}")
                if retry_count < max_retries:
                    time.sleep(5)
                else:
                    logger.error("Max retries reached. Could not connect to MySQL")
                    raise
    
    def insert_tweet(self, tweet_data):
        """Insert tweet data into MySQL"""
        try:
            cursor = self.mysql_connection.cursor()
            
            # Parse timestamp
            timestamp = None
            if 'iso_timestamp' in tweet_data:
                try:
                    timestamp = datetime.fromisoformat(tweet_data['iso_timestamp'].replace('Z', '+00:00'))
                except:
                    pass
            
            if not timestamp and 'timestamp' in tweet_data:
                try:
                    timestamp = datetime.strptime(tweet_data['timestamp'], '%Y-%m-%d %H:%M:%S')
                except:
                    pass
            
            if not timestamp:
                timestamp = datetime.now()
            
            insert_query = """
            INSERT INTO tweets (
                user_id, screen_name, tweet, timestamp, iso_timestamp,
                location, verified, statuses_count, mbti_personality,
                total_retweet_count, total_favorite_count
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """
            
            values = (
                tweet_data.get('user_id'),
                tweet_data.get('screen_name', ''),
                tweet_data.get('tweet', ''),
                timestamp,
                timestamp,
                tweet_data.get('location', ''),
                tweet_data.get('verified', False),
                tweet_data.get('statuses_count', 0),
                tweet_data.get('mbti_personality', 'unknown'),
                tweet_data.get('total_retweet_count', 0),
                tweet_data.get('total_favorite_count', 0)
            )
            
            cursor.execute(insert_query, values)
            cursor.close()
            
            logger.info(f"Inserted tweet from user {tweet_data.get('screen_name')} (ID: {tweet_data.get('user_id')})")
            
        except Error as e:
            logger.error(f"Error inserting tweet into MySQL: {e}")
            # Try to reconnect
            self.setup_mysql_connection()
    
    def consume_messages(self):
        """Main loop to consume messages from Kafka and insert into MySQL"""
        logger.info("Starting Kafka to MySQL consumer...")
        
        try:
            for message in self.consumer:
                try:
                    tweet_data = message.value
                    self.insert_tweet(tweet_data)
                except Exception as e:
                    logger.error(f"Error processing message: {e}")
                    continue
                    
        except KeyboardInterrupt:
            logger.info("Stopping consumer...")
        except Exception as e:
            logger.error(f"Error in consumer loop: {e}")
        finally:
            if self.consumer:
                self.consumer.close()
            if self.mysql_connection:
                self.mysql_connection.close()

if __name__ == "__main__":
    consumer = KafkaToMySQLConsumer()
    consumer.consume_messages()
