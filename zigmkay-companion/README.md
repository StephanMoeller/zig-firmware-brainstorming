# zigmkay-companion

A high-performance desktop overlay providing real-time visualization of keyboard inputs and layer state for keyboards running `zigmkay` firmware.

## Features
- **Real-time Synchronization**: Automatically tracks the active layer and key states via a dedicated RAWHID channel.
- **Dynamic Keymap Viewer**: Implemented using [DVUI](https://github.com/david-vanderson/dvui) with the **SDL3 backend** for low-latency, transparent overlays.
- **Background Mode & Smart Toggle**: The app runs in the background and is activated/deactivated by a custom keypress defined in your firmware.
- **Visual Feedback**: Highlights active physical key presses and provides a layer indicator grid.

## HID Interface & Control
The companion app communicates with the keyboard over a vendor-defined HID interface (RAWHID):
- **Layer Sync**: The firmware pushes layer changes (Signal `0x01`) to the app.
- **Companion Toggle**: A special key defined in the `zigmkay` keymap (Custom ID `4` in the sample) sends signals (`0x02`) to show or hide the overlay.
  - **Tap**: Toggles persistent visibility.
  - **Hold**: Momentarily shows the overlay until the key is released.
- **Closing**: Press the **ESC** key to exit the application.

## Prerequisites
- A keyboard running [zigmkay](https://github.com/StephanMoeller/zigmkay) firmware with RAWHID enabled.
- A compatible keymap. Currently, this app uses a [local dependency to a keymap](https://github.com/conlorz/zigmkay-keyboard-sample-unibody).

## Usage
1. Checkout `zigmkay-keyboard-sample-unibody` and `zigmkay-companion`.
2. Ensure your firmware includes the `COMPANION_TOGGLE` key.
3. Run the app with `zig build run`.

## Future Plans
- Easier build process removing the need to build comnpanion and firmware sperately

