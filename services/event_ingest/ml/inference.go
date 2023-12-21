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

package inference

import (
    "context"
    "encoding/json"
    "fmt"
    "time"
    "io/ioutil"

    "event_ingest/types"
    external "event_ingest/external"
)

// Defines a function that validates and filters a game event payload,
// then sends the data to an ML endpoint.
func PredictEvent(ctx context.Context, payload types.GameEvent) (types.Prediction, error) {
    
    // Get ml endpoint URI
    mlEndpointURI := ctx.Value("mlEndpointURI").(string)
    
    // Format event_date as "yyyy-mm-dd"
    formattedDate, err := time.Parse("20060102", payload.EventDate)
    if err != nil {
        fmt.Println("Error formatting event_date:", err)
        return types.Prediction{}, err
    }
    payload.EventDate = formattedDate.Format("2006-01-02")
    
    // Create a map to hold the data for each instance
    instanceData := map[string]interface{}{
        "event_name":                   payload.EventName,
        "event_date":                   payload.EventDate,
        "event_timestamp":              fmt.Sprint(payload.EventTimestamp),
        "event_previous_timestamp":     fmt.Sprint(payload.EventPreviousTimestamp),
        "event_bundle_sequence_id":     fmt.Sprint(payload.EventBundleSequenceID),
        "event_server_timestamp_offset": fmt.Sprint(payload.EventServerTimestampOffset),
        "user_pseudo_id":               payload.UserPseudoID,
        "user_first_touch_timestamp":   fmt.Sprint(payload.UserFirstTouchTimestamp),
        "operating_system":             payload.Device.OperatingSystem,
        "language":                     payload.Device.Language,
        "country":                      payload.Geo.Country,
    }

    // Create the instances array with a single instance (your payload)
    instances := []map[string]interface{}{instanceData}

    // Create the input data struct
    inputData := map[string]interface{}{
        "instances": instances,
    }

    // Convert the struct to JSON
    jsonData, err := json.Marshal(inputData)
    if err != nil {
        fmt.Println("Error with json marshal in PredictEvent")
        return types.Prediction{}, err
    }

    fmt.Printf("prediction request data: %s\n", jsonData)

    // Send data to our ML service for scoring
    resp, err := external.PostJSON(mlEndpointURI, jsonData)
    if err != nil {
        fmt.Println("Error posting to REST URI in PredictEvent")
        return types.Prediction{}, err
    }

    var prediction types.Prediction

    err = json.NewDecoder(resp.Body).Decode(&prediction)
    if err != nil {
        fmt.Println("Error decoding json in PredictEvent", err)
        body, _ := ioutil.ReadAll(resp.Body)
        fmt.Println("Response Body:", string(body))
        return types.Prediction{}, err
    }

    return prediction, err
}

// Defines a function that validates and filters a game event payload,
// then sends the data to an ML endpoint.
func LookupChurn(ctx context.Context, payload types.GameEvent) (types.ChurnLookup, error) {
    
    churnLookupServiceURI := ctx.Value("churnLookupServiceURI").(string)
    
    requestBody := map[string]string{
        "user_pseudo_id": payload.UserPseudoID,
    }
    // Convert the struct to JSON
    jsonData, err := json.Marshal(requestBody)
    if err != nil {
        fmt.Println("Error with json marshal in LookupChurn")
        return types.ChurnLookup{}, err
    }

    fmt.Printf("churn lookup request data: %s\n", jsonData)

    resp, err := external.PostJSON(churnLookupServiceURI, jsonData)
    if err != nil {
        fmt.Println("Error posting to REST URI in LookupChurn", err)
        return types.ChurnLookup{}, err
    }

    var churnLookup types.ChurnLookup

    err = json.NewDecoder(resp.Body).Decode(&churnLookup)
    if err != nil {
        fmt.Println("Error decoding json in LookupChurn", err)
        body, _ := ioutil.ReadAll(resp.Body)
        fmt.Println("Response Body:", string(body))
        return types.ChurnLookup{}, err
    }

    return churnLookup, err
}