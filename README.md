The ShepherD Ground Station
================

This is the repository for the ShepherD Gound Station, a perl script that takes control over Parrot Drones, it was created by [Samy Kamkar](https://github.com/samyk) and modified by us for the ShepherD project. This Ground Station has been modified to log any activity to the [ShepherD App](https://github.com/anadaniel/shepherd_app) and also to run a node server that communicates with the [ShepherD Client](https://github.com/tooga/ict-drone-client) to send the live camera feed of the drones that it has taken control over and to receive commands from the Client to drive the controlled drone.

## How does the ShepherD work?

The final **ShepherD** product is an integration of the App, the Ground Station and the Client. Through the App, Ground Stations are registered along with the coordinates where they will be placed in the area they will help monitor. Once in place, the Ground Stations will be constantly looking for drones that enter the range of their antennas and when they detect a drone they will log this information with the App. The Client is a real-time App that is constantly listening for notifications that the Ground Stations log into the App. When the Client is notified that a new drone has been detected, the user gets an alert and then it can choose to take control of the drone that has been detected, this drone has been already hacked by the Ground Station. If the user decides to take control of the dron, a socket connection is opened between the Client and the Ground Station, the Client will receive the feed of the camera feed on the drone and it will also send commands to drive the drone to an area where is no longer a threat.

## How to install and run the ShepherD Ground Station
```sh
  git@github.com:tooga/ict-drone-groundstation.git # download the repository
  cd ict-drone-groundstation
  npm install # install dependencies
  perl skyjack.pl
```

This code is meant to be run on the ground station which is a Raspberry Pi with the correct configuration. We followed the configuration described by Samy Kamkar in his original project [Skyjack](https://github.com/samyk/skyjack/).
