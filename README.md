[![](https://images.microbadger.com/badges/image/kevineye/heyu.svg)](https://microbadger.com/images/kevineye/heyu "Get your own image badge on microbadger.com")

This is a dockerized [heyu](http://www.heyu.org/) for controlling and monitoring X10 home automation devices via a CM11A module.

## Setup

Run this to generate some config files:

    docker run --rm -v /your/config/dir:/etc/heyu cuetus/heyu-mqtt
    
Copy `x10config.sample` to `x10.sched.sample` and to `x10.conf` and `x10.sched` and edit your configuration.

## Run

    docker run -d \
        -v /your/config/dir:/etc/heyu \
        -v /etc/localtime:/etc/localtime \
        --device /dev/ttyUSB0 \
        --env MQTT_HOST=your.mqtt.server.ip \
        cuetus/heyu-mqtt

The device can be configured in the `x10.conf` file.

MQTT setup using environment variables

    MQTT_HOST     - set to your MQTT server ip
    MQTT_PORT     - default 1883
    MQTT_USER.    - default none
    MQTT_PASSWORD - default none
    MQTT_PREFIX   - default home/x10


## MQTT Services

State information sent to topic home/x10/<housecode><unitcode> with payload containing device state and brightness level
    
    topic: "home/x10/O3"
    payload: "{"device":"O3", "state":"ON", "level":"35"}"

or
    
    topic: "home/x10/O3"
    payload: "{"device":"O3", "state":"OFF", "level":""}"

Commands to set X10 device status can be sent to topic home/x10/+/set, for example to turn a device off
    
    topic: "heyu/x10/O3/set"
    payload: off
    
Support for extended raw commands, for example set device O3 absolute brightness to 50% (0-63)
    
    topic: "home/x10/raw/set"
    payload: xpreset O3 32

    
