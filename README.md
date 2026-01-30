# TextCleaner

TextCleaner is a macOS application that utilizes the `imgclean` CLI tool to enhance scanned images by turning noisy, colored scans into clean, black-and-white images. It is particularly useful for preparing documents for Optical Character Recognition (OCR) or for improving the readability of scanned text.

I have started this project as a learning exercise to familiarize myself with macOS application development using XCode and Swift. The idea is simple: provide a GUI wrapper around the `imgclean` CLI tool to make it accessible to users who may not be comfortable using command-line tools. Unfortunately, I do not have an Apple Developer license, so I cannot distribute a signed version of this application. This means that for now, you will have to build the application yourself if you wish to use it.

Furthermore, Apples notarization requirements have made this app even more challenging to distribute. `imgclean` relies on several third-party libraries, which means that they need to be included with the application bundle as well. However, these libraries must be properly signed by the same developer ID as the main application to satisfy Apple's security checks. Since the libraries are neither built nor signed by me, I cannot include them as-is. Therefore, a re-signing step is necessary, but the script `collect_dylibs.sh` provided in this repository automates this process for you.

## Building

1. Pray that everything will work as intended and that Apple's shenanigans won't get in your way.
2. Clone the project to your machine.
   - `imgclean` is a git submodule and should be automatically cloned when you clone the repository. 
   - If not, run `git submodule update --init --recursive`
3. Using the terminal, navigate to `TextCleaner/imgclean/project` and build imgclean by following the instructions in the `imgclean` README. I recommend using the config flags `-DCMAKE_BUILD_TYPE=Release -DMEASURE_PERFORMANCE=OFF` for this project.
4. Collect all dylibs that imgclean needs by invoking the `collect_dylibs.sh` script in the root folder of this project:
   ```
   ./collect_dylibs.sh
   ```
   The resulting dylibs will be placed in the `imgclean-frameworks` folder.
5. Open the project in XCode.
6. In this step, you need to ensure that all the dylibs collected in step 3 are included in the application bundle:
   - Go to the `Build Phases` tab of the TextCleaner target.
   - Look for a `Copy Files` phase with the destination set to `Frameworks`.
      - If it does not exist, create one by clicking the `+` button and selecting `New Copy Files Phase`, then set the destination to `Frameworks`.
      - If it exists, make sure to remove any old dylibs that may be there from previous builds.
   - Add all the dylibs in the `imgclean-frameworks` folder to this phase. Make sure to select `Create folder references` when adding them and ensure that `Code Sign on Copy` is checked for each dylib.
7. Now, the `imgclean` binary needs to be included in the application bundle as well:
   - Still in the `Build Phases` tab, look for another `Copy Files` phase with the destination set to `Executables`.
      - If it does not exist, create one by clicking the `+` button and selecting `New Copy Files Phase`, then set the destination to `Executables`.
      - If it exists, make sure to remove any old `imgclean` binaries that may be there from previous builds.
   - Add the `imgclean` binary (located in `TextCleaner/imgclean/project/build/`) to this phase. Ensure that `Code Sign on Copy` is checked.
8. You should now be able to build and run the application from XCode. Have fun!