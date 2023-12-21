// Copyright 2023 Google LLC All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package types

type GameEvent struct {
    EventDate      string   `json:"event_date"`
    EventTimestamp  int64    `json:"event_timestamp"`
    EventName      string   `json:"event_name"`
    EventParams    []Param  `json:"event_params"`
    EventPreviousTimestamp int64 `json:"event_previous_timestamp"`
    EventBundleSequenceID int64 `json:"event_bundle_sequence_id"`
    EventServerTimestampOffset int64 `json:"event_server_timestamp_offset"`
    UserPseudoID   string   `json:"user_pseudo_id"`
    UserProperties []Property `json:"user_properties"`
    UserFirstTouchTimestamp int64 `json:"user_first_touch_timestamp"`
    Device         Device   `json:"device"`
    Geo            Geo       `json:"geo"`
    AppInfo        AppInfo          `json:"app_info"`
    TrafficSource  TrafficSource   `json:"traffic_source"`
    StreamID       string   `json:"stream_id"`
    Platform       string   `json:"platform"`
}

type Param struct {
    Key   string      `json:"key"`
    Value ValueUnion `json:"value"`
}

type Property struct {
    Key   string      `json:"key"`
    Value ValueUnion `json:"value"`
}

type ValueUnion struct {
    StringValue         string `json:"string_value,omitempty"`
    IntValue            int64  `json:"int_value,omitempty"`
    SetTimestampMicros  int64 `json:"set_timestamp_micros,omitempty"`
}

type Device struct {
    Category          string `json:"category,omitempty"`
    MobileBrandName  string `json:"mobile_brand_name,omitempty"`
    MobileModelName  string `json:"mobile_model_name,omitempty"`
    MobileMarketinglName  string `json:"mobile_marketing_name,omitempty"`
    MobileOSHardwareModel  string `json:"mobile_os_hardware_model,omitempty"`
    OperatingSystem  string `json:"operating_system,omitempty"`
    OperatingSystemVersion  string `json:"operating_system_version,omitempty"`
    Language  string `json:"language,omitempty"`
    IsLimitedAdTracking  string `json:"is_limited_ad_tracking,omitempty"`
    TimeZoneOffsetSeconds int64 `json:"time_zone_offset_seconds,omitempty"`
}

type Geo struct {
    Continent          string `json:"continent,omitempty"`
    Country  string `json:"country,omitempty"`
    Region  string `json:"region,omitempty"`
    City  string `json:"city,omitempty"`
}

type AppInfo struct {
    ID          string `json:"id,omitempty"`
    Version  string `json:"version,omitempty"`
    FirebaseAppID  string `json:"firebase_app_id,omitempty"`
    InstallSource  string `json:"install_source,omitempty"`
}

type TrafficSource struct {
    Name          string `json:"name,omitempty"`
    Medium  string `json:"medium,omitempty"`
    Source  string `json:"source,omitempty"`
}

type Prediction struct {
	Predictions []PredictionItem `json:"predictions"`
}

type PredictionItem struct {
	Value      float64 `json:"value"`
	LowerBound float64 `json:"lower_bound"`
	UpperBound float64 `json:"upper_bound"`
}

type ChurnLookup struct {
    UserPseudoID string `json:"user_pseudo_id"`
    Churned      string `json:"churned"`
    PredictedChurned string `json:"predicted_churned"`
    ProbabilityChurned string `json:"probability_churned"`
  }  