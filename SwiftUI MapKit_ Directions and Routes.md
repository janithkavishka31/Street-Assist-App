# **MapKit in SwiftUI: Calculating and Displaying Routes**

This guide explains how to calculate travel time and directions using MKRoute and display them on a Map view in SwiftUI.

## **1\. Initial State and View Setup**

To manage a route calculation, you need to track the selected destination and the resulting route object.  
import SwiftUI  
import MapKit

struct ContentView: View {  
    @State private var selectedResult: MKMapItem?  
    @State private var route: MKRoute?

    var body: some View {  
        Map(selection: $selectedResult) {  
            // Map content goes here  
        }  
    }

    func getDirections() {   
        // Logic to follow  
    }  
}

## **2\. Configuring the Directions Request**

Within the getDirections() function, you configure an MKDirections.Request. This requires a source and a destination. While the source is often the user's location, you can use fixed coordinates for testing.  
func getDirections() {  
    self.route \= nil  
      
    // Check if there is a selected result  
    guard let selectedResult else { return }  
      
    // Starting point coordinates (Example: Naples, Italy)  
    let startingPoint \= CLLocationCoordinate2D(  
        latitude: 40.83657722488077,  
        longitude: 14.306896671048852  
    )  
      
    // Create and configure the request  
    let request \= MKDirections.Request()  
    request.source \= MKMapItem(placemark: MKPlacemark(coordinate: startingPoint))  
    request.destination \= self.selectedResult  
      
    // Run the request asynchronously  
    Task {  
        let directions \= MKDirections(request: request)  
        let response \= try? await directions.calculate()  
        // Store the first valid route  
        route \= response?.routes.first  
    }  
}

## **3\. Triggering Calculations**

Use the .onChange modifier to monitor selectedResult. Whenever a new location is selected, the map will automatically trigger the direction calculation.  
Map(selection: $selectedResult) {  
    // ...  
}  
.onChange(of: selectedResult) {  
    getDirections()  
}

## **4\. Visualizing the Route with MapPolyline**

Once a route is available in the state, you can overlay it on the map using a MapPolyline.  
Map(selection: $selectedResult) {  
    // Marker for the starting point  
    Marker("Start", coordinate: self.startingPoint)

    // Overlay the route if it exists  
    if let route {  
        MapPolyline(route)  
            .stroke(.blue, lineWidth: 5\)  
    }  
}

## **5\. Formatting Travel Time**

You can extract metadata from the MKRoute object, such as expectedTravelTime. Using DateComponentsFormatter ensures the time is readable (e.g., "15 min" or "1 hr 10 min").  
private var travelTime: String? {  
    guard let route else { return nil }

    let formatter \= DateComponentsFormatter()  
    formatter.unitsStyle \= .abbreviated  
    formatter.allowedUnits \= \[.hour, .minute\]

    return formatter.string(from: route.expectedTravelTime)  
}

## **Full Functional Example**

The following code demonstrates a complete implementation showing a route between two fixed points.  
import SwiftUI  
import MapKit

struct ContentView: View {  
    @State private var selectedResult: MKMapItem?  
    @State private var route: MKRoute?  
      
    private let startingPoint \= CLLocationCoordinate2D(  
        latitude: 40.83657722488077,  
        longitude: 14.306896671048852  
    )  
      
    private let destinationCoordinates \= CLLocationCoordinate2D(  
        latitude: 40.849761,  
        longitude: 14.263364  
    )  
      
    var body: some View {  
        Map(selection: $selectedResult) {  
            Marker("Start", coordinate: self.startingPoint)  
              
            if let route {  
                MapPolyline(route)  
                    .stroke(.blue, lineWidth: 5\)  
            }  
        }  
        .onChange(of: selectedResult) {  
            getDirections()  
        }  
        .onAppear {  
            // Set initial destination to trigger calculation  
            self.selectedResult \= MKMapItem(placemark: MKPlacemark(coordinate: self.destinationCoordinates))  
        }  
    }  
      
    func getDirections() {  
        self.route \= nil  
        guard let selectedResult else { return }  
          
        let request \= MKDirections.Request()  
        request.source \= MKMapItem(placemark: MKPlacemark(coordinate: self.startingPoint))  
        request.destination \= self.selectedResult  
          
        Task {  
            let directions \= MKDirections(request: request)  
            let response \= try? await directions.calculate()  
            route \= response?.routes.first  
        }  
    }  
}  
