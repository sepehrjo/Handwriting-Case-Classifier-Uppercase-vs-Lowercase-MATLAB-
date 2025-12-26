# Handwriting Case Classifier
A MATLAB-based tool that identifies whether handwritten text is uppercase, lowercase, or mixed. It uses image processing techniques like baseline alignment and height uniformity to make the call.

## Why this project exists
This project was built to explore how computer vision can distinguish between different writing styles. It's a handy tool for anyone interested in handwriting analysis or OCR preprocessing.

## Quick Start
1. **Open MATLAB**: Make sure you have MATLAB installed on your machine.
2. **Add to Path**: Open the project folder in MATLAB.
3. **Run the Script**: Type `LowercaseUppercase` in the Command Window and press Enter.
4. **Upload Image**: Use the GUI to select a handwriting image from the `lowercase` or `uppercase` folders.
5. **Analyze**: Click the process button to see the results and diagnostic figures.

## Project Structure
- `LowercaseUppercase.m`: The main MATLAB script and GUI logic.
- `lowercase/`: Sample images of lowercase handwriting.
- `uppercase/`: Sample images of uppercase handwriting.
- `.gitignore`: Keeps the repo clean by ignoring temporary MATLAB files.

## How to contribute
If you have ideas to improve the classification accuracy or want to add more features:
1. Fork the repo.
2. Create a new branch for your feature.
3. Submit a Pull Request with a clear description of your changes.

## How to roll back cleanup
If you need to undo the cleanup, you can use these commands:
- `git checkout cleanup/backup-20251226113816`
- Or apply the reverse patch: `git apply repo-cleanup-20251226113816.patch -R`

## License
No license file found.
