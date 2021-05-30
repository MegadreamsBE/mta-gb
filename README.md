# MTA-GB - Game Boy emulator in Multi Theft Auto
This project aims to create a fully playable Game Boy emulator within Multi Theft Auto.

## Loading ROMs
At this stage it is not possible to dynamically decide which ROM to load. Instead it is currently hardcoded to run the Tetris ROM but this can be adjusted in **src/core.lua**. This ROM is _not_ included in this repository.

## How To Run
1. Clone or download this repository.
2. Copy the folder containing this repository to your Multi Theft Auto server under **mods/deatmatch/resources**.
3. Add a **data** folder inside the resource.
4. Add a ROM to the **data** folder and adjust **src/core.lua** and **meta.xml** if the filename is not Tetris.gb.

![Tetris](/images/tetris.png)

## Current Progress
This emulator currently has most of the CPU instructions, a somewhat decent MMU, graphics support, a debugger and more. It is able to run games such as Tetris and Dr. Mario up to the selection screen at this time.

## TODO
(This is not a full list)
- Finish adding all CPU instructions.
- Add sound support
- Improve debugging tools by using a proper dxGUI.

## Known Problems
- GPU timings are slightly off.
- GPU doesn't trigger all necessary interrupts yet.
- Not all CPU instructions have correct timings nor logic. Although most have been fixed by now.
- Slow performance

## FAQ
1. Why Multi Theft Auto?    
   I wanted to develop this for a platform that not yet has a Game Boy emulator and at the same time poses a bigger challenge for optimization due to its poor performance. MTA not having a Game Boy emulator and at the same time have plenty of performance issues fit this criteria very well. Once finished and properly optimized this emulator could be used as a way of keeping players entertained at times when they have to wait (such as after dying on a race deatchmatch map).
   
2. Will this also support Game Boy Color?    
   Yes. This will be introduced once the Game Boy emulation is stable and optimized well enough in a new branch. It will be possible to toggle which of the two you want to use to run a ROM.
   
3. Will this support Game Boy Advance games?    
   Perhaps. This would be far into the future and only if optimization methods deem it feasable.
   
4. Can I contribute?    
   Yes. Feel free to fork this project and help improve it. It's open source for a reason.

## License
GNU General Public License v3.0

See [LICENSE](LICENSE) for details.
