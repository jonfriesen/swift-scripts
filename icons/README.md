# Icons for Swift Scripts

This folder contains icons used in various Swift scripts within the Swift Scripts project. These icons enhance the visual appeal and functionality of the utilities.

## Icon Source

All icons in this folder are sourced from [Phosphor Icons](https://phosphoricons.com/). Phosphor Icons is an open-source and flexible icon family designed for interfaces, diagrams, presentations, and more.

## Usage

To use these icons in your Swift scripts, you may need to convert them to base64 encoded strings. This can be done using the following command:

```bash
base64 -i 'icon.png' | tr -d '\n'
```

Replace `'icon.png'` with the name of the specific icon file you want to encode.

## Example

An example of a base64 encoded icon can be found at `snippets/menu_icon.swift`. You can use this as a reference for implementing icons in your scripts.

## License

The icons are subject to the licensing terms of Phosphor Icons. Please refer to their [website](https://phosphoricons.com/) for the most up-to-date licensing information.

---

For more information on the Swift Scripts project, please refer to the main [README.md](../README.md) file in the root directory.
