# DataSort Factory

DataSort Factory is an educational 2D sorting game made with Godot Engine 4.6 and GDScript.

Players organize numbered crates inside a factory-themed interface while learning how different sorting algorithms work. Instead of watching the algorithms sort automatically, players interact with the crates, compare values, perform swaps, follow algorithm rules and complete each sorting challenge manually.

## Features

DataSort Factory includes three difficulty modes:

- Easy Mode
  - Bubble Sort
  - Insertion Sort
  - Selection Sort

- Intermediate Mode
  - Merge Sort
  - Quick Sort
  - Radix Sort

- Advanced Mode
  - Shell Sort
  - Heap Sort
  - Tim Sort

The game also includes:

- Interactive crate sorting
- Algorithm-based gameplay rules
- Hints
- Undo controls
- Reset and retry options
- Move counting
- Efficiency scoring
- Star ratings
- Win and failure screens
- Factory-themed graphics
- Animated crane and processing-machine elements
- Algorithm explanations through the in-game manual
- Background music and sound-related interface elements

## Built With

- Godot Engine 4.6
- GDScript
- Godot 2D scene system
- Godot UI nodes
- AnimationPlayer
- CanvasLayer
- TextureButton
- Sprite2D
- Line2D
- AudioStreamPlayer
- PNG textures
- SVG icon
- MP3 background music
- Custom font

## How to Run the Project

### Requirements

You need:

- Godot Engine 4.6 or a compatible Godot 4.x version
- A computer that supports Godot’s 2D renderer

### Steps

1. Download or clone this repository.

2. Open Godot Engine.

3. Select Import or Import Existing Project.

4. Choose the folder containing project.godot.

5. Open the project.

6. Press the Play Project button.

The game starts from:

scenes/menu.tscn

## Project Structure

DataSort Factory Finals/
├── assets/
│   ├── crates/
│   ├── fonts/
│   ├── music/
│   └── ui/
├── scenes/
│   ├── advancedmode.tscn
│   ├── bubblesort.tscn
│   ├── difficulty.tscn
│   ├── easymode.tscn
│   ├── heapsort.tscn
│   ├── insertionsort.tscn
│   ├── intermediatemode.tscn
│   ├── manual.tscn
│   ├── menu.tscn
│   ├── mergesort.tscn
│   ├── option.tscn
│   ├── processing_machine.tscn
│   ├── quicksort.tscn
│   ├── radixsort.tscn
│   ├── selectionsort.tscn
│   ├── shellsort.tscn
│   └── timsort.tscn
├── scripts/
│   ├── bubblesort.gd
│   ├── difficulty.gd
│   ├── easymode.gd
│   ├── insertionsort.gd
│   ├── intermediatemode.gd
│   ├── manual.gd
│   ├── processing_machine.gd
│   ├── selectionsort.gd
│   └── other button and interface scripts
├── project.godot
└── export_presets.cfg

## How the Game Works

The game uses Godot scenes for each screen and GDScript files for the gameplay behavior.

The main menu loads first when the project runs. From there, the player can open the difficulty selection screen, manual, options or exit the game.

The difficulty screen sends the player to Easy, Intermediate or Advanced Mode. Each mode contains buttons that open the gameplay scene for a specific sorting algorithm.

Each algorithm scene contains the crates, buttons, labels, animations, score displays, win panels and failure panels needed for that level.

The sorting scripts store the crate values in arrays. The visible crates represent the values inside those arrays. When the player selects or swaps crates, the script updates the array and changes the visual positions of the crates.

A typical gameplay flow looks like this:

Start the game
    ↓
Open the main menu
    ↓
Choose a difficulty
    ↓
Choose a sorting algorithm
    ↓
Interact with the numbered crates
    ↓
Follow the rules of the selected algorithm
    ↓
Sort the complete array
    ↓
Receive a score and star rating

## Sorting Algorithms

### Bubble Sort

Bubble Sort repeatedly compares neighboring values. If two neighboring values are in the wrong order, they are swapped.

The larger values gradually move toward the end of the array after each pass.

### Insertion Sort

Insertion Sort takes one value at a time and places it into the correct position among the values that have already been sorted.

It works similarly to sorting a hand of playing cards.

### Selection Sort

Selection Sort searches for the smallest remaining value and places it at the beginning of the unsorted section.

The sorted section grows from left to right.

### Merge Sort

Merge Sort divides the array into smaller sections, sorts those sections and merges them back together.

The game represents the temporary and output areas used while merging sorted runs.

### Quick Sort

Quick Sort chooses a pivot and separates the values into smaller and larger groups around that pivot.

The groups are then sorted separately.

### Radix Sort

Radix Sort organizes values by processing their digits or positions instead of comparing the values directly in the same way as comparison-based algorithms.

The processing-machine elements help represent this idea inside the game.

### Shell Sort

Shell Sort compares values separated by a gap. The gap becomes smaller during each pass until the final pass uses a gap of one.

The game displays this gap-based process through crate comparisons and movement.

### Heap Sort

Heap Sort organizes values into a heap structure. The largest value is repeatedly moved to the end of the array while the remaining values are reorganized.

### Tim Sort

Tim Sort divides the array into smaller sorted runs and merges those runs together.

The Tim Sort level is divided into several phases:

1. Set run boundaries
2. Sort each run
3. Select runs
4. Compare the front values
5. Move values into temporary and output rows

## Controls

Controls depend on the selected algorithm, but most levels use:

- Click a crate to select it
- Click another crate to compare or select it
- Press the action button to perform a swap or movement
- Press the hint button to receive guidance
- Press undo to reverse a previous action
- Press reset to restart the level
- Use the retry button after completing or failing a level
- Use the main menu button to return to the main menu

## Scoring

The game tracks the number of moves used by the player.

After completing a level, the game displays:

- Total moves
- Efficiency
- Star rating
- Completion result

Using fewer moves generally produces a better efficiency score.

The goal is not only to produce a sorted array. The player also has to follow the logic of the selected algorithm.

## Assets and Credits

The game’s visual assets, interface elements and music are owned by the project creator.

The background music was AI-generated for DataSort Factory and is included in this repository by the project creator.

The game uses original project materials such as:

- Factory backgrounds
- Numbered crate graphics
- Interface buttons
- Sorting icons
- Gauge graphics
- Star-rating graphics
- Crane and machine visuals
- Custom font
- Background music

## Development Notes

The project was created as an educational game that combines algorithm lessons with interactive gameplay.

Each level uses a Godot scene for its layout and a GDScript controller for its behavior. Button signals are connected to functions that handle navigation, crate selection, swapping, hints, undo actions, resets and win conditions.

Some gameplay scripts are stored in the scripts folder while some advanced algorithm scripts are stored in the scenes folder. This does not stop the game from running, but future updates could organize all gameplay scripts in one folder.

The project also contains Godot-generated files such as .import, .uid and .godot files. These files are created by Godot to manage imported assets and project metadata.

## Recommended Godot Version

This project was created for:

Godot Engine 4.6

Using the same Godot version is recommended to reduce the chance of scene, script or compatibility issues.

## Repository Notes

The project configuration may still contain the default internal name:

New Game Project

The visible project title can be changed in project.godot if needed:

config/name="DataSort Factory"

Generated cache files should normally not be included in version control. A .gitignore file can contain:

.godot/

## License

All rights reserved by the project creator unless stated otherwise.

The game, source code, graphics, music and other project materials may not be copied, modified, redistributed or used in another project without permission from the creator.

If this project is being submitted for an academic requirement, the source code may be reviewed for educational and evaluation purposes.

## Project Status

DataSort Factory is a completed educational game project with multiple playable sorting-algorithm levels.

Future updates may include:

- More sorting algorithms
- More levels
- Improved sound effects
- Additional animations
- A level-selection progress system
- Improved mobile controls
- More detailed score statistics
