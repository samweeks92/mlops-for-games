import json
import socket
import os
import time, datetime
from random import seed
from random import randint
from random import choices

def send_tcp(host, port):
        
    seed(time.time())
    
    current_date = datetime.datetime.today().strftime("%Y%m%d")
    
    possible_event_names = ['screen_view','user_engagement','level_start_quickplay','level_end_quickplay','post_score','level_complete_quickplay','level_fail_quickplay','level_reset_quickplay','select_content','level_start','session_start','level_end','level_retry','level_up','level_complete','level_retry_quickplay','test_event','level_fail','spend_virtual_currency','use_extra_steps','level_reset','firebase_campaign','app_exception','first_open','os_update','no_more_extra_steps']
    possible_event_name_probabilities = [0.393,0.238,0.092,0.061,0.042,0.033,0.024,0.021,0.018,0.013,0.013,0.010,0.008,0.006,0.006,0.005,0.004,0.003,0.002,0.002,0.001,0.001,0.001,0.001,0.001,0.000]
    event_name = choices(possible_event_names, weights=possible_event_name_probabilities, k=1)[0]
        
    data_payload = {
        "event_date": current_date,
        "event_timestamp": randint(1,9),
        "event_name": event_name,
        "event_params": [
            {
                "key": "value",
                "value": {
                    "int_value": randint(10,99)
                }
            },
            {
                "key": "firebase_screen_class",
                "value": {
                    "string_value": "game_board"
                }
            },
            {
                "key": "firebase_event_origin",
                "value": {
                    "string_value": "app+gtm"
                }
            },
            {
                "key": "firebase_screen_id",
                "value": {
                    "int_value": randint(-99999999999999999,-11111111111111111)
                }
            },
            {
                "key": "board",
                "value": {
                    "string_value": "S"
                }
            }
        ],
        "event_previous_timestamp": randint(1500000000000000,5555555555555555),
        "event_bundle_sequence_id": randint(111,999),
        "event_server_timestamp_offset": randint(100000,999999),
        "user_pseudo_id": "D50D60807F5347EB64EF0CD5A3D4C4CD",
        "user_properties": [
            {
                "key": "initial_extra_steps",
                "value": {
                    "string_value": "5",
                    "set_timestamp_micros": randint(1000000000000000,9999999999999999)
                }
            },
            {
                "key": "plays_quickplay",
                "value": {
                    "string_value": "true",
                    "set_timestamp_micros": randint(1400000000000000,1599999999999999)
                }
            },
            {
                "key": "num_levels_available",
                "value": {
                    "string_value": "30",
                    "set_timestamp_micros": randint(1400000000000000,1599999999999999)
                }
            },
            {
                "key": "firebase_last_notification",
                "value": {
                    "string_value": "1705466146457443844",
                    "set_timestamp_micros": randint(1400000000000000,1599999999999999)
                }
            },
            {
                "key": "firebase_exp_4",
                "value": {
                    "string_value": "2",
                    "set_timestamp_micros": randint(1400000000000000,1599999999999999)
                }
            },
            {
                "key": "plays_progressive",
                "value": {
                    "string_value": "true",
                    "set_timestamp_micros": randint(1400000000000000,1599999999999999)
                }
            },
            {
                "key": "firebase_exp_1",
                "value": {
                    "string_value": "2",
                    "set_timestamp_micros": randint(1400000000000000,1599999999999999)
                }
            },
            {
                "key": "first_open_time",
                "value": {
                    "int_value": randint(1400000000000000,1599999999999999),
                    "set_timestamp_micros": randint(1400000000000000,1599999999999999)
                }
            },
            {
                "key": "ad_frequency",
                "value": {
                    "string_value": "3",
                    "set_timestamp_micros": randint(1400000000000000,1599999999999999)
                }
            }
        ],
        "user_first_touch_timestamp": randint(1400000000000000,1599999999999999),
        "device": {
            "category": "mobile",
            "mobile_brand_name": "not available in demo dataset",
            "mobile_model_name": "not available in demo dataset",
            "mobile_marketing_name": "not available in demo dataset",
            "mobile_os_hardware_model": "not available in demo dataset",
            "operating_system": "ANDROID",
            "operating_system_version": "not available in demo dataset",
            "language": "en-us",
            "is_limited_ad_tracking": "No",
            "time_zone_offset_seconds": -14400
        },
        "geo": {
            "continent": "Americas",
            "country": "United States",
            "region": "Northern America",
            "city": "New York"
        },
        "app_info": {
            "id": "com.labpixies.flood",
            "version": "2.62",
            "firebase_app_id": "1:300830567303:android:9b9ba2ce17104d0c",
            "install_source": "com.android.vending"
        },
        "traffic_source": {
            "name": "(direct)",
            "medium": "(none)",
            "source": "(direct)"
        },
        "stream_id": "1051193346",
        "platform": "ANDROID"
    }

    json_data = json.dumps(data_payload)
    server_address = (host, port)
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect(server_address)
    sock.sendall(json_data.encode())
    data = sock.recv(1024)
    sock.close()

if __name__ == "__main__":
    
    runtime_seconds = int(os.environ.get('RUNTIME_SECONDS', 60))
    event_ingest_service_name = os.environ.get('EVENT_INGEST_SERVICE_NAME', 'event-ingest-service')
    event_ingest_service_namespace = os.environ.get('EVENT_INGEST_SERVICE_NAMESPACE', 'game-event-ns')
    event_ingest_service_ip = os.environ.get('EVENT_INGEST_SERVICE_IP')
    event_ingest_service_port = int(os.environ.get('EVENT_INGEST_SERVICE_PORT', 80))

    host = ""
    if event_ingest_service_ip is not None and event_ingest_service_ip != "":
        host = event_ingest_service_ip
    else:
        host = f"{event_ingest_service_name}.{event_ingest_service_namespace}.svc.cluster.local"


    t_end = time.time() + runtime_seconds
    print(f'Sending events to {host}:{event_ingest_service_port} for {runtime_seconds} seconds')
    messageCount = 1
    while time.time() < t_end:
        event_start_time = datetime.datetime.now()
        send_tcp(host=host, port=event_ingest_service_port)
        event_runtime = (datetime.datetime.now() - event_start_time).total_seconds() * 1000 # milliseconds
        print(f'Message {messageCount}: Received TCP server response. Runtime: {event_runtime} milliseconds')
        messageCount += 1