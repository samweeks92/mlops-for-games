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

package main

import (
    "encoding/json"
    "fmt"
    "net"
    "log"
    "os"
    "context"
    
    "event_ingest/types"
    "event_ingest/gcp"
    ml "event_ingest/ml"
)

const (
    tcpPort = ":7777"
)

func handleConnection(conn net.Conn, ctx context.Context) {
    defer conn.Close()

    decoder := json.NewDecoder(conn)
    
    // Decode the entire JSON object
    var data map[string]interface{}
    if err := decoder.Decode(&data); err != nil {
        log.Println("Error decoding JSON:", err)
        return
    }

    // Check if "ml" key is present
    mlValue, mlPresent := "", false
    if mlVal, ok := data["ml"].(string); ok {
        mlValue = mlVal
        mlPresent = true
        // Remove the "ml" key from the map
        delete(data, "ml")
    }
        
    // Convert the remaining data to JSON and then decode it into GameEvent
    jsonData, err := json.Marshal(data)
    if err != nil {
        log.Println("Error converting remaining data to JSON:", err)
        return
    }

    var ge types.GameEvent
    if err := json.Unmarshal(jsonData, &ge); err != nil {
        log.Println("Error decoding connection to GameEvent:", err)
        return
    }
    // If payload is tagged for scoring (via "ML" key), then
    // send to the ML endpoint for scoring.
    if mlPresent {
        if mlValue == "spend" {
            fmt.Println("key value pair ml:spend was found in data, so sending data to spend prediction ML Endpoint", ctx.Value("mlEndpointURI").(string))
            result, err := ml.PredictEvent(ctx, ge)
            if err != nil {
                fmt.Println("Error sending data to ML Endpoint via REST")
            } else {
                // Extract the relevant values from the prediction result
                predictionResult := result.Predictions[0]
                output := map[string]float64{
                    "value":      predictionResult.Value,
                    "lower_bound": predictionResult.LowerBound,
                    "upper_bound": predictionResult.UpperBound,
                }

                // convert the prediction struct to a JSON payload
                outputJSON, err := json.Marshal(output)
                if err != nil {
                    fmt.Println("Error converting output to JSON:", err)
                } else {
                    fmt.Printf("Spend prediction result: %s\n", outputJSON)
                    _, err = conn.Write(outputJSON)
                    if err != nil {
                        fmt.Println("Error writing spend prediction result to connection:", err)
                    }
                }
            }
        } else if mlValue == "churn" {
            fmt.Println("key value pair ml:churn was found in data, so sending data to spend prediction ML Endpoint", ctx.Value("mlEndpointURI").(string))
            result, err := ml.LookupChurn(ctx, ge)
            if err != nil {
                fmt.Println("Error sending data to churn lookup service via REST")
            } else {
                churnLookupResult := result
                outputJSON, err := json.Marshal(churnLookupResult)
                if err != nil {
                    fmt.Println("Error converting output to JSON:", err)
                } else {
                    fmt.Printf("Churn lookup result: %s\n", outputJSON)
                    _, err = conn.Write(outputJSON)
                    if err != nil {
                        fmt.Println("Error writing churn lookup result to connection:", err)
                    }
                }
            }
        }
    } else {
        fmt.Println("Valid ml flag not found in data, not making any prediction request")
    }

    // Send to PubSub
    if err := gcp.PublishToPubsub(ctx, ge); err != nil {
        log.Fatal("Error publishing message to Pubsub:", err)
    }
    fmt.Println("Successfully sent payload to Pubsub.")

}

func main() {
    
    ln, err := net.Listen("tcp", tcpPort)
    if err != nil {
        log.Fatal("Error creating TCP listener:", err)
    }
    defer ln.Close()

    fmt.Println("TCP server started on port:", tcpPort)

    ctx := context.Background()
    
    // Set ML Endpoint URI
    mlEndpointURI := fmt.Sprintf("http://%v:8080/predict", os.Getenv("ML_AGENT_URL"))
    ctx = context.WithValue(ctx, "mlEndpointURI", mlEndpointURI)
    
    // Set ML Endpoint URI
    churnLookupServiceURI := fmt.Sprintf("http://%v:8080/user", os.Getenv("CHURN_LOOKUP_SERVICE_URL"))
    ctx = context.WithValue(ctx, "churnLookupServiceURI", churnLookupServiceURI)
    
    for {
        conn, err := ln.Accept()
        if err != nil {
            log.Println("Error accepting connection:", err)
            continue
        }

        go handleConnection(conn, ctx)
    }
}
