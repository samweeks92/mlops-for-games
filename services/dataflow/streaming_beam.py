from __future__ import absolute_import
import datetime
import logging
import argparse
import json
from typing import List
import apache_beam as beam
from apache_beam import window
from apache_beam.options.pipeline_options import PipelineOptions


bq_schema = {
    "fields": [
        {
            "name": "event_date",
            "type": "DATE"
        },
        {
            "name": "event_timestamp",
            "type": "INTEGER"
        },
        {
            "name": "event_name",
            "type": "STRING"
        },
        {
            "fields": [
            {
                "name": "key",
                "type": "STRING"
            },
            {
                "fields": [
                {
                    "name": "string_value",
                    "type": "STRING"
                },
                {
                    "name": "int_value",
                    "type": "INTEGER"
                },
                {
                    "name": "float_value",
                    "type": "FLOAT"
                },
                {
                    "name": "double_value",
                    "type": "FLOAT"
                }
                ],
                "name": "value",
                "type": "RECORD"
            }
            ],
            "mode": "REPEATED",
            "name": "event_params",
            "type": "RECORD"
        },
        {
            "name": "event_previous_timestamp",
            "type": "INTEGER"
        },
        {
            "name": "event_value_in_usd",
            "type": "FLOAT"
        },
        {
            "name": "event_bundle_sequence_id",
            "type": "INTEGER"
        },
        {
            "name": "event_server_timestamp_offset",
            "type": "INTEGER"
        },
        {
            "name": "user_id",
            "type": "STRING"
        },
        {
            "name": "user_pseudo_id",
            "type": "STRING"
        },
        {
            "fields": [
            {
                "name": "key",
                "type": "STRING"
            },
            {
                "fields": [
                {
                    "name": "string_value",
                    "type": "STRING"
                },
                {
                    "name": "int_value",
                    "type": "INTEGER"
                },
                {
                    "name": "float_value",
                    "type": "FLOAT"
                },
                {
                    "name": "double_value",
                    "type": "FLOAT"
                },
                {
                    "name": "set_timestamp_micros",
                    "type": "INTEGER"
                }
                ],
                "name": "value",
                "type": "RECORD"
            }
            ],
            "mode": "REPEATED",
            "name": "user_properties",
            "type": "RECORD"
        },
        {
            "name": "user_first_touch_timestamp",
            "type": "INTEGER"
        },
        {
            "fields": [
            {
                "name": "revenue",
                "type": "FLOAT"
            },
            {
                "name": "currency",
                "type": "STRING"
            }
            ],
            "name": "user_ltv",
            "type": "RECORD"
        },
        {
            "fields": [
            {
                "name": "category",
                "type": "STRING"
            },
            {
                "name": "mobile_brand_name",
                "type": "STRING"
            },
            {
                "name": "mobile_model_name",
                "type": "STRING"
            },
            {
                "name": "mobile_marketing_name",
                "type": "STRING"
            },
            {
                "name": "mobile_os_hardware_model",
                "type": "STRING"
            },
            {
                "name": "operating_system",
                "type": "STRING"
            },
            {
                "name": "operating_system_version",
                "type": "STRING"
            },
            {
                "name": "vendor_id",
                "type": "STRING"
            },
            {
                "name": "advertising_id",
                "type": "STRING"
            },
            {
                "name": "language",
                "type": "STRING"
            },
            {
                "name": "is_limited_ad_tracking",
                "type": "STRING"
            },
            {
                "name": "time_zone_offset_seconds",
                "type": "INTEGER"
            },
            {
                "name": "browser",
                "type": "STRING"
            },
            {
                "name": "browser_version",
                "type": "STRING"
            },
            {
                "fields": [
                {
                    "name": "browser",
                    "type": "STRING"
                },
                {
                    "name": "browser_version",
                    "type": "STRING"
                },
                {
                    "name": "hostname",
                    "type": "STRING"
                }
                ],
                "name": "web_info",
                "type": "RECORD"
            }
            ],
            "name": "device",
            "type": "RECORD"
        },
        {
            "fields": [
            {
                "name": "continent",
                "type": "STRING"
            },
            {
                "name": "country",
                "type": "STRING"
            },
            {
                "name": "region",
                "type": "STRING"
            },
            {
                "name": "city",
                "type": "STRING"
            },
            {
                "name": "sub_continent",
                "type": "STRING"
            },
            {
                "name": "metro",
                "type": "STRING"
            }
            ],
            "name": "geo",
            "type": "RECORD"
        },
        {
            "fields": [
            {
                "name": "id",
                "type": "STRING"
            },
            {
                "name": "version",
                "type": "STRING"
            },
            {
                "name": "install_store",
                "type": "STRING"
            },
            {
                "name": "firebase_app_id",
                "type": "STRING"
            },
            {
                "name": "install_source",
                "type": "STRING"
            }
            ],
            "name": "app_info",
            "type": "RECORD"
        },
        {
            "fields": [
            {
                "name": "name",
                "type": "STRING"
            },
            {
                "name": "medium",
                "type": "STRING"
            },
            {
                "name": "source",
                "type": "STRING"
            }
            ],
            "name": "traffic_source",
            "type": "RECORD"
        },
        {
            "name": "stream_id",
            "type": "STRING"
        },
        {
            "name": "platform",
            "type": "STRING"
        },
        {
            "fields": [
            {
                "name": "hostname",
                "type": "STRING"
            }
            ],
            "name": "event_dimensions",
            "type": "RECORD"
        }
    ]
}

def parse_pubsub(event):
    return json.loads(event)

def preprocess_event(event):
    # Convert event_date to DATE type
    event_date_str = event['event_date']
    event_date = datetime.datetime.strptime(event_date_str, "%Y%m%d").date()
    
    # Update the event_date in the event dictionary
    event['event_date'] = event_date.isoformat()

    return event


def print_event(event):
    print('{}'.format(event))

def run(
    input_topic: str,
    output_table: str,
    window_interval_sec: int = 60,
    beam_args: List[str] = None,
) -> None:
    """Build and run the pipeline."""
    options = PipelineOptions(beam_args, save_main_session=True, streaming=True)
    
    print('[ INFO ] PUBSUB INPUT TOPIC: {}'.format(input_topic))
    print('[ INFO ] BQ TABLE NAME: {}'.format(output_table))

    with beam.Pipeline(options=options) as p:
        
        # Get PubSub Topic
        events = ( 
                 p  | 'raw events' >> beam.io.ReadFromPubSub(topic=input_topic) 
        )
        
        # Parse events
        parsed_events = (
            events  | 'parsed events' >> beam.Map(parse_pubsub)
        )

        # Print results to console (for testing/debugging)
        events | 'Raw events received'   >> beam.Map(print_event)
        
        # Parse events
        preprocessed_events = (
            parsed_events  | 'Preprocessed events' >> beam.Map(preprocess_event)
        )

        # Event Window Transform
        event_window = (
            preprocessed_events | 'Window processing' >> beam.WindowInto(window.SlidingWindows(window_interval_sec, (window_interval_sec/2))) # Window is 60 seconds in length, and a new window begins every 15 seconds
                                # | beam.GroupByKey()
                                # | beam.Map(avg_by_group)
        )
        
        # Print results to console (for testing/debugging)
        event_window | 'Print window processed events'   >> beam.Map(print_event)

        # Sink/Persist to BigQuery
        event_window | 'Write to bq' >> beam.io.gcp.bigquery.WriteToBigQuery(
                            output_table,
                            schema=bq_schema
                        )



if __name__ == '__main__':
    logging.getLogger().setLevel(logging.INFO)
    parser = argparse.ArgumentParser()
    
    parser.add_argument(
        "--output_table",
        help="Output BigQuery table for results specified as: "
        "PROJECT:DATASET.TABLE or DATASET.TABLE.",
    )
    parser.add_argument(
        "--input_topic",
        help="Input PubSub topic of the form "
        '"projects/<PROJECT>/topic/<TOPIC>."',
    )
    parser.add_argument(
        "--window_interval_sec",
        default=60,
        type=int,
        help="Window interval in seconds for grouping incoming messages.",
    )
    args, beam_args = parser.parse_known_args()

    run(
        input_topic=args.input_topic,
        output_table=args.output_table,
        window_interval_sec=args.window_interval_sec,
        beam_args=beam_args,
    )


