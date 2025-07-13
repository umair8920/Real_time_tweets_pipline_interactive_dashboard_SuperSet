import json
import numpy as np
import pandas as pd
from datetime import datetime
import time
import paho.mqtt.client as mqtt
import os
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# MQTT Configuration
MQTT_BROKER = os.getenv('MQTT_BROKER', 'localhost')
MQTT_PORT = int(os.getenv('MQTT_PORT', 1883))
MQTT_TOPIC = os.getenv('MQTT_TOPIC', 'twitter/tweets')

class TwitterDataPublisher:
    def __init__(self):
        self.client = mqtt.Client()
        self.client.on_connect = self.on_connect
        self.client.on_publish = self.on_publish
        self.client.on_disconnect = self.on_disconnect
        
        # Load data files
        self.load_data()
        
    def on_connect(self, client, userdata, flags, rc):
        if rc == 0:
            logger.info(f"Connected to MQTT broker at {MQTT_BROKER}:{MQTT_PORT}")
        else:
            logger.error(f"Failed to connect to MQTT broker. Return code: {rc}")
    
    def on_publish(self, client, userdata, mid):
        logger.debug(f"Message {mid} published successfully")
    
    def on_disconnect(self, client, userdata, rc):
        logger.warning(f"Disconnected from MQTT broker. Return code: {rc}")
    
    def load_data(self):
        """Load Twitter data files"""
        try:
            # Load tweets data
            with open('/app/data/tweets1.json', 'r', encoding='utf-8') as file:
                self.tweets_data = json.load(file)
            logger.info(f"Loaded {len(self.tweets_data)} users with tweets")
            
            # Load user info
            with open('/app/data/users1.json', 'r', encoding='utf-8') as file:
                self.users_data = json.load(file)
            logger.info(f"Loaded {len(self.users_data)} user profiles")
            
            # Load MBTI labels
            self.mbti_data = pd.read_csv('/app/data/mbti_labels.csv')
            logger.info(f"Loaded {len(self.mbti_data)} MBTI personality labels")
            
            # Create user lookup for MBTI
            self.mbti_lookup = dict(zip(self.mbti_data['id'], self.mbti_data['mbti_personality']))
            
            # Create user info lookup
            self.user_info_lookup = {user['screen_name']: user for user in self.users_data}
            
        except Exception as e:
            logger.error(f"Error loading data files: {e}")
            raise
    
    def get_user_info(self, user_id):
        """Get user information by user_id"""
        # Find user in tweets data first
        user_tweets = None
        for user in self.tweets_data:
            if user.get('id') == user_id:
                user_tweets = user
                break
        
        if not user_tweets:
            return None
            
        # Get screen name and look up additional info
        screen_name = user_tweets.get('screen_name', '')
        user_info = self.user_info_lookup.get(screen_name, {})
        
        return {
            'user_id': user_id,
            'screen_name': screen_name,
            'location': user_info.get('location', ''),
            'verified': user_info.get('verified', False),
            'statuses_count': user_info.get('statuses_count', 0),
            'total_retweet_count': user_info.get('total_retweet_count', 0),
            'total_favorite_count': user_info.get('total_favorite_count', 0),
            'mbti_personality': self.mbti_lookup.get(user_id, 'unknown')
        }
    
    def create_tweet_message(self, user_data, tweet_text):
        """Create a structured tweet message"""
        now = datetime.now()
        
        # Clean tweet text
        cleaned_text = tweet_text.encode('utf-8', 'ignore').decode('utf-8')
        cleaned_text = cleaned_text.replace('\n', ' ').replace('"', '').replace('\\', '')
        if not cleaned_text.endswith('.'):
            cleaned_text += '.'
        
        user_info = self.get_user_info(user_data['id'])
        
        message = {
            'user_id': user_data['id'],
            'screen_name': user_data.get('screen_name', ''),
            'tweet': cleaned_text,
            'timestamp': now.strftime("%Y-%m-%d %H:%M:%S"),
            'iso_timestamp': now.isoformat(),
            'location': user_info.get('location', '') if user_info else '',
            'verified': user_info.get('verified', False) if user_info else False,
            'statuses_count': user_info.get('statuses_count', 0) if user_info else 0,
            'mbti_personality': user_info.get('mbti_personality', 'unknown') if user_info else 'unknown',
            'total_retweet_count': user_info.get('total_retweet_count', 0) if user_info else 0,
            'total_favorite_count': user_info.get('total_favorite_count', 0) if user_info else 0
        }
        
        return message
    
    def connect_mqtt(self):
        """Connect to MQTT broker"""
        try:
            self.client.connect(MQTT_BROKER, MQTT_PORT, 60)
            self.client.loop_start()
            return True
        except Exception as e:
            logger.error(f"Error connecting to MQTT broker: {e}")
            return False
    
    def publish_tweets(self):
        """Main loop to publish tweets"""
        if not self.connect_mqtt():
            return
        
        logger.info("Starting tweet publishing...")
        
        while True:
            try:
                # Select random user and tweet
                user_idx = np.random.randint(len(self.tweets_data))
                user_data = self.tweets_data[user_idx]
                
                if 'tweets' in user_data and len(user_data['tweets']) > 0:
                    tweet_idx = np.random.randint(len(user_data['tweets']))
                    tweet_text = user_data['tweets'][tweet_idx]
                    
                    # Create message
                    message = self.create_tweet_message(user_data, tweet_text)
                    
                    # Publish to MQTT
                    result = self.client.publish(MQTT_TOPIC, json.dumps(message))
                    
                    if result.rc == mqtt.MQTT_ERR_SUCCESS:
                        logger.info(f"Published tweet from user {message['screen_name']} (ID: {message['user_id']})")
                    else:
                        logger.error(f"Failed to publish message. Return code: {result.rc}")
                
                # Wait 2 seconds before next tweet
                time.sleep(2)
                
            except KeyboardInterrupt:
                logger.info("Stopping tweet publisher...")
                break
            except Exception as e:
                logger.error(f"Error in publish loop: {e}")
                time.sleep(5)  # Wait before retrying
        
        self.client.loop_stop()
        self.client.disconnect()

if __name__ == "__main__":
    publisher = TwitterDataPublisher()
    publisher.publish_tweets()
