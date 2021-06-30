# MTA-GB - Game Boy emulator in Multi Theft Auto
This project aims to create a fully playable Game Boy emulator within Multi Theft Auto.

## Loading ROMs
At this stage it is not possible to dynamically decide which ROM to load. Instead it is currently hardcoded to run the Tetris ROM but this can be adjusted in **src/gameboy.lua**. This ROM is _not_ included in this repository.

## How To Run
1. Clone or download this repository.
2. Copy the folder containing this repository to your Multi Theft Auto server under **mods/deatmatch/resources**.
3. Add a **data** folder inside the resource.
4. Add a ROM to the **data** folder and adjust **src/gameboy.lua** and **meta.xml** if the filename is not Tetris.gb.

### LÖVE
Due to poor performance on Multi Theft Auto a WIP/experimental wrapper for LÖVE is available that allows to test the emulator on LuaJIT. The following steps are needed to run it:
1. Clone or download this repository.
2. Add a ROM (like Tetris) to your LÖVE data folder (appdata in Windows).
3. (Optional) If a different ROM than Tetris (Tetris.gb) is added modify **src/gameboy.lua**.
4. Navigate to the directory containing this repository and then navigate into **wrappers/love**.
5. Run: $ **love .**

![Tetris](/images/tetris.png)
![The Legend of Zelda Link's Awakening](/images/zelda.png)
![Pokémon Blue](/images/pokemon.png)

## Current Progress
This emulator currently has most of the CPU instructions, a somewhat decent MMU, graphics support, a debugger and more. It is able to run games such as Tetris, Dr. Mario, Pokémon Blue and The Legend of Zelda Links Awakening fairly well.

## TODO
(This is not a full list)
- Add sound support
- Improve debugging tools by using a proper dxGUI.
- Improve interrupt handling
- Improve timer support
- Improve GPU timings
- Add save states

## Known Problems
- Donkey Kong land shows a white screen.
- MBC3 isn't yet fully implemented and causes crashes.
- GPU doesn't fully have correct timings yet.
- Slow performance
- There's a minor scrolling bug causing minor graphical glitches in Pokémon Blue/Red's new game sequence.

## FAQ
1. Why Multi Theft Auto?    
   I wanted to develop this for a platform that not yet has a Game Boy emulator and at the same time poses a bigger challenge for optimization due to its poor performance. MTA not having a Game Boy emulator and at the same time have plenty of performance issues fit this criteria very well. Once finished and properly optimized this emulator could be used as a way of keeping players entertained at times when they have to wait (such as after dying on a race deatchmatch map).

2. Will this also support Game Boy Color?    
   Yes. This will be introduced once the Game Boy emulation is stable and optimized well enough in a new branch. It will be possible to toggle which of the two you want to use to run a ROM.
   
3. Will this support Game Boy Advance games?    
   Perhaps. This would be far into the future and only if optimization methods deem it feasable.
   
4. How well does this emulator perform?
   Poorly. Optimizations are being made but at the moment it only runs between 6-8 FPS on a system with a i9 9900k and RTX 2070 SUPER.

5. Can I contribute?    
   Yes. Feel free to fork this project and help improve it. It's open source for a reason.

## Guidelines
Please note that there's no class system within the code base. This is intentional and it's pointless to add one. There used to be one but as the emulator already performs poorly a faster, and unfortunately less readable/convenient, way of writing code had to be chosen.

## License
GNU General Public License v3.0

See [LICENSE](LICENSE) for details.
