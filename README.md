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

## Configuration

Everything is configured through environment variables; there is no config file.

| Variable | Default | Purpose |
|---|---|---|
| `MQTT_BROKER` | `localhost` | Broker hostname |
| `MQTT_PORT` | `1883` | Broker port |
| `MQTT_TOPIC` | `train-image` | Topic subscribed to for incoming frames |
| `MQTT_PUB_TOPIC` | `train-model-result` | Topic the detections are published to |
| `MODEL_PATH` | `models/model.onnx` | Path to the ONNX model. Relative, so the app must be run from the repository root |
| `ONNXRUNTIME_PROVIDERS` | `["CUDAExecutionProvider"]` | onnxruntime execution providers, as a Python list literal. Use `["CPUExecutionProvider"]` off the Jetson |
| `MIN_CONF_THRESHOLD` | `0.8` | Minimum confidence for a detection to be published. Applied after NMS, which itself uses a fixed 0.25/0.45 |
| `IMG_IN_RESPONSE` | `True` | Whether to echo the source image back in the result. **Currently cannot be disabled — see Known issues** |

The published detection payload looks like this, and `train-ceq-app` is the consumer:

```json
{ "id": "...", "image": "<base64>", "detections": [ ... ],
  "pre-process": "0.00s", "inference": "0.04s", "post-process": "0.01s",
  "total": "0.05s", "scale": 1.09375 }
```

Note that `confidence` and each `box` element are emitted as **strings**, not numbers.
The Java consumer declares them as numeric types and relies on Jackson coercing them.

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

### Benchmark

`test/load.sh` publishes the sample image in a loop and reports the mean round-trip time.
It needs the application and a broker already running, and is run from the `test/`
directory like `publish.sh`. Set `ITERATIONS` to change the default 100 passes.

## Deployment

**`manifests/` is reference only and is not what runs on the train.** The deployed
configuration is rendered from the Helm chart in the
[gitops](https://github.com/redhatnsp/gitops) repository (`train/` chart), which is
templated onto the Jetson at boot. The manifests here set no environment variables at
all, so `MQTT_BROKER` would fall back to `localhost` and never reach the broker — treat
them as an illustration of the shape of the deployment, not as something to apply.

## Known issues

- **`IMG_IN_RESPONSE` cannot be turned off.** It is read as
  `bool(os.environ.get("IMG_IN_RESPONSE", True))`, and every non-empty string is truthy
  in Python, so `IMG_IN_RESPONSE=false` still evaluates to `True`.
- **`on_disconnect` is never called successfully.** Its signature takes three arguments,
  but paho-mqtt 2.x under `CallbackAPIVersion.VERSION2` calls it with five, so it raises
  `TypeError` and the "Unexpected disconnection" warning never appears.
- **A malformed frame terminates the process.** `on_message` has no error handling, so a
  payload that fails to decode propagates out of `cv2.imdecode` and stops inference until
  the container restarts.
- **The container image may be running CPU inference.** `docker/Dockerfile` installs the
  Jetson `onnxruntime_gpu-1.16.0` wheel and then runs `pip3 install -r requirements.txt`,
  which contains a bare `onnxruntime`. Both packages provide the same `onnxruntime`
  module, so the CPU build installs over the GPU one.
- **Dependencies are unpinned.** `src/requirements.txt` lists bare package names, so the
  image contents depend on the day it was built. Pinning needs to be worked out against
  an actual aarch64/cp310 build, since the local development versions resolve differently.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.