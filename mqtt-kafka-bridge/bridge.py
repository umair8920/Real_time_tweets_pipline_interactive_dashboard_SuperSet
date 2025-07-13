import json
import logging
import os
import time
import paho.mqtt.client as mqtt
from kafka import KafkaProducer
from kafka.errors import KafkaError

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Configuration
MQTT_BROKER = os.getenv('MQTT_BROKER', 'mosquitto')
MQTT_PORT = int(os.getenv('MQTT_PORT', 1883))
MQTT_TOPIC = os.getenv('MQTT_TOPIC', 'twitter/tweets')
KAFKA_BOOTSTRAP_SERVERS = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'kafka:29092')
KAFKA_TOPIC = os.getenv('KAFKA_TOPIC', 'twitter-tweets')

class MQTTKafkaBridge:
    def __init__(self):
        self.mqtt_client = mqtt.Client()
        self.kafka_producer = None
        self.setup_mqtt()
        self.setup_kafka()
    
    def setup_mqtt(self):
        """Set up MQTT client"""
        self.mqtt_client.on_connect = self.on_mqtt_connect
        self.mqtt_client.on_message = self.on_mqtt_message
        self.mqtt_client.on_disconnect = self.on_mqtt_disconnect
    
    def setup_kafka(self):
        """Set up Kafka producer"""
        try:
            self.kafka_producer = KafkaProducer(
                bootstrap_servers=[KAFKA_BOOTSTRAP_SERVERS],
                value_serializer=lambda x: json.dumps(x).encode('utf-8'),
                key_serializer=lambda x: str(x).encode('utf-8') if x else None,
                retries=5,
                retry_backoff_ms=100,
                request_timeout_ms=30000
            )
            logger.info(f"Kafka producer connected to {KAFKA_BOOTSTRAP_SERVERS}")
        except Exception as e:
            logger.error(f"Error setting up Kafka producer: {e}")
            raise
    
    def on_mqtt_connect(self, client, userdata, flags, rc):
        """Callback for MQTT connection"""
        if rc == 0:
            logger.info(f"Connected to MQTT broker at {MQTT_BROKER}:{MQTT_PORT}")
            client.subscribe(MQTT_TOPIC)
            logger.info(f"Subscribed to MQTT topic: {MQTT_TOPIC}")
        else:
            logger.error(f"Failed to connect to MQTT broker. Return code: {rc}")
    
    def on_mqtt_disconnect(self, client, userdata, rc):
        """Callback for MQTT disconnection"""
        logger.warning(f"Disconnected from MQTT broker. Return code: {rc}")
    
    def on_mqtt_message(self, client, userdata, msg):
        """Callback for MQTT message received"""
        try:
            # Parse the JSON message
            message_str = msg.payload.decode('utf-8')
            message_data = json.loads(message_str)
            
            # Use user_id as the key for partitioning
            key = str(message_data.get('user_id', ''))
            
            # Send to Kafka
            future = self.kafka_producer.send(KAFKA_TOPIC, key=key, value=message_data)
            
            # Wait for the message to be sent
            record_metadata = future.get(timeout=10)
            
            logger.info(f"Message sent to Kafka - Topic: {record_metadata.topic}, "
                       f"Partition: {record_metadata.partition}, "
                       f"Offset: {record_metadata.offset}, "
                       f"User ID: {message_data.get('user_id')}")
            
        except json.JSONDecodeError as e:
            logger.error(f"Error decoding JSON message: {e}")
        except KafkaError as e:
            logger.error(f"Error sending message to Kafka: {e}")
        except Exception as e:
            logger.error(f"Unexpected error processing message: {e}")
    
    def start_bridge(self):
        """Start the MQTT-Kafka bridge"""
        logger.info("Starting MQTT-Kafka bridge...")
        
        # Connect to MQTT broker
        try:
            self.mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
            self.mqtt_client.loop_start()
            
            # Keep the bridge running
            while True:
                time.sleep(1)
                
        except KeyboardInterrupt:
            logger.info("Stopping MQTT-Kafka bridge...")
        except Exception as e:
            logger.error(f"Error in bridge: {e}")
        finally:
            self.mqtt_client.loop_stop()
            self.mqtt_client.disconnect()
            if self.kafka_producer:
                self.kafka_producer.close()

if __name__ == "__main__":
    bridge = MQTTKafkaBridge()
    bridge.start_bridge()
