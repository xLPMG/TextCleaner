# TextCleaner

Warning: This project is WIP and not yet functional (due to imgclean not being fully implemented).

## Building

1. Open the project in XCode
2. Build imgclean
3. Collect all dylibs that imgclean needs by invoking the `collect_dylibs.sh` script in the root folder of this project:
   ```
   ./collect_dylibs.sh
   ```
4. In XCode, go to the "Build Phases" tab of the TextCleaner target, and add a "Copy Files" phase.
   - Set the "Destination" to "Frameworks"
   - Add all the dylibs in the ìmgclean-frameworks` folder to this phase.
5. Build and run the TextCleaner target.

### Building imgclean

1. imgclean is a git submodule and should be automatically cloned when you clone the repository. If not, run:
   ```
   git submodule update --init --recursive
   ```
2. Open a terminal and navigate to the `imgclean/project` directory:
3. Use cmake to build imgclean (build.sh shows you how)