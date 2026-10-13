# Audio

Shows the default output volume and mute state. Its popups provide stream,
device, microphone, and Easy Effects controls.

The mixer uses PulseAudio-compatible `pactl`; `pavucontrol` opens the full
mixer. When Easy Effects is installed, the right-click popup controls bypass,
input/output presets, and the full application. The normal mixer remains
available without Easy Effects.

## Actions

- **Left click:** Open the audio mixer.

  ![Audio Left Click](screenshots/audio_left_click.png)

- **Middle click:** Mute or unmute the default output.

- **Right click:** Open Easy Effects controls.

  ![Audio Right Click](screenshots/audio_right_click.png)

- **Scroll:** Raise or lower volume in two-percent steps and unmute the output.
