# Demo Stop The Crazy Train - Lego Train AI app

![lego](https://www.lego.com/cdn/cs/set/assets/blt95604d8cc65e26c4/CITYtrain_Hero-XL-Desktop.png?fit=crop&format=webply&quality=80&width=1600&height=1000&dpr=1)

# Intelligent-Train

Intelligent-Train is a Python module in a larger system that employs machine learning algorithms to interpret video data from the Capture-App. The primary function of this module is to recognize specific signs that indicate the need to slow down or stop the train.

## How it works

Intelligent-Train receives video data from the Capture-App module via MQTT. This data is processed using a machine learning model specifically trained to recognize signs that signal the need to slow down or halt the train. The module then generates raw predictions based on this analysis, which are subsequently sent to the Train-CEQ-App for further processing and decision-making.

## Prerequisites

- **MQTT Broker**: Intelligent-Train uses MQTT for messaging. An MQTT broker, accessible to Intelligent-Train, must be operational. Set `MQTT_BROKER` (default `localhost`) and `MQTT_PORT` (default `1883`) to point at it.

  Every component of this demo talks to the same broker, so the mosquitto setup is documented once, in
  [train-controller](https://github.com/redhatnsp/train-controller#local-installation). Follow its
  *Local installation* and *Test* sections to get a broker running.

Intelligent-Train only subscribes to `train-image` and publishes to `train-model-result`. The broker
is the sole thing it shares with the rest of the demo.

## Dependencies

Dependencies are managed by pip and are specified in the `src/requirements.txt` file.

## Related Modules

Intelligent-Train is part of a larger system that includes the following modules:

- **Capture-App**: This module captures video and sends it to Intelligent-Train.
- **Train-CEQ-App**: This module processes the raw predictions made by the Intelligent-Train module, transforming them into actionable insights.
- **Train-Monitoring-App**: This module receives the CloudEvent from Train-CEQ-App via Kafka and uses this information for monitoring and visualization purposes.
- **Train-Controller**: This module receives decisions from Train-CEQ-App and controls the operation of the train accordingly.

## How to run

1. Clone the repository: `git clone https://github.com/redhatnsp/intelligent-train.git`
2. Navigate to the project directory: `cd intelligent-train`
3. Install the dependencies: `pip install -r src/requirements.txt`
4. Start an MQTT broker (see [Prerequisites](#prerequisites)), and set `MQTT_BROKER` / `MQTT_PORT` if it
   is not on `localhost:1883`.
5. Run the application from the **repository root**: `python src/app.py`

### Running locally on macOS

The container image targets NVIDIA Jetson and defaults to CUDA so a few changes are needed to test locally.

Create a virtualenv and install the dependencies:

```sh
python3.11 -m venv .venv
.venv/bin/pip install -r src/requirements.txt
```

`ONNXRUNTIME_PROVIDERS` defaults to `["CUDAExecutionProvider"]`, which fails without an NVIDIA GPU.
Override it and run from the repository root:

```sh
export ONNXRUNTIME_PROVIDERS='["CPUExecutionProvider"]'
.venv/bin/python src/app.py
```

The first start takes around 20 seconds with no output at all while onnxruntime initialises. It looks
hung; it is not. Once ready you should see:

```text
2026-10-06 19:07:20 INFO     Connected with result code Success
2026-10-06 19:07:20 INFO     Subscribed to topic: train-image
```

### Test

No camera, Capture-App or Train-Controller is needed — the repository ships a sample image
(`test/test.jpg`) and a publish script (`test/publish.sh`), and the model `models/model.onnx`
is already committed.

Subscribe to the results topic in one terminal:

```sh
mosquitto_sub -h localhost -p 1883 -t train-model-result
```

Publish the sample image from another:

```sh
cd test && ./publish.sh
```

The application logs the inference, and the subscriber receives the detections:

```text
2026-10-06 19:07:30 INFO     Processed image 2026-10-06T19:07:30-04:00 in 0.04699s
```

```json
{
  "id": "2026-10-06T19:07:30-04:00",
  "detections": [
    { "class_id": 0, "class_name": "SpeedLimit", "confidence": "0.94", "box": ["357.48", "120.03", "70.64", "63.84"] }
  ],
  "pre-process": "0.00s", "inference": "0.04s", "post-process": "0.01s", "total": "0.05s", "scale": 1.09375
}
```

Prometheus metrics are exposed on port `8000` throughout.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.