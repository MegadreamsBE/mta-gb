# MTA-GB - Game Boy (Color) emulator in Multi Theft Auto
This project aims to create a fully playable Game Boy emulator within Multi Theft Auto.

**Experimental CGB support is available as well but has limited support for games at this time!**

## Loading ROMs
At this stage it is not possible to dynamically decide which ROM to load. Instead it is currently hardcoded but this can be adjusted in **src/gameboy.lua**. There is _no_ ROM included with this repository.

## How To Run
1. Clone or download this repository.
2. Copy the folder containing this repository to your Multi Theft Auto server under **mods/deatmatch/resources**.
3. Add a **data** folder inside the resource.
4. Add a ROM to the **data** folder and adjust **src/gameboy.lua** and **meta.xml** if the filename is not Tetris.gb.

### LÖVE
A experimental wrapper for the LÖVE framework is available to allow for playing/testing outside of MTA. The following steps are needed to run it:
1. Clone or download this repository.
2. Add a ROM (like Tetris) to your LÖVE data folder (appdata in Windows).
3. Navigate to the directory containing this repository and then navigate into **wrappers/love**.
4. Run: $ **love . <pathToRom>**

![Tetris](/images/tetris.png)
![The Legend of Zelda Link's Awakening](/images/zelda.png)
![Pokémon Blue](/images/pokemon.png)
![Pokémon Crystal](/images/pokemoncrystal.png)

## Current Progress
This emulator currently has a fully working CPU, GPU, MMU (except some MBC types), a debugger and more. It is able to run games such as Tetris, Dr. Mario, Pokémon Blue and The Legend of Zelda Links Awakening fairly well. Bugs do currently exist and some weirder DMG/CBG behaviors aren't fully implemented yet.

## TODO
(This is not a full list)
- Add sound support.
- Improve debugging tools by using a proper dxGUI.
- Improve GPU timings.
- Add save states.
- Add missing memory banks and improve existing ones.

## Known Problems
(This is not a full list)
- Donkey Kong land shows a white screen.
- Pokémon Crystal glitches when opening the PokéDex.
- Pokémon Blue/Red has a sprite glitch when the emulator runs in CGB mode (bottom part is white).
- MBC3 isn't yet fully implemented and causes crashes.
- GPU timings isn't quite right yet.
- Slow performance
- There's a minor scrolling bug causing minor graphical glitches in Pokémon Blue/Red's new game sequence.

## FAQ
1. Why Multi Theft Auto?    
   I wanted to develop this for a platform that didn't yet have a Game Boy emulator and at the same time poses a bigger challenge for optimization due to its poor performance. MTA not having a Game Boy emulator and at the same time have plenty of performance issues fit this criteria very well. Once finished and properly optimized this emulator could be used as a way of keeping players entertained at times when they have to wait (such as after dying on a race deatchmatch map).
   
2. Will this support Game Boy Advance games?    
   Perhaps. This would be far into the future and only if optimization methods deem it feasable.
   
3. How well does this emulator perform?
   Poorly in MTA, fairly well on LÖVE. Performance improves are being made.

4. Can I contribute?    
   Yes. Feel free to fork this project and help improve it. It's open source for a reason.

## Guidelines
Please note that there's no class system within the code base. This is intentional and it's pointless to add one. There used to be one but as the emulator already performs poorly a faster, and unfortunately less readable/convenient, way of writing code had to be chosen.

## License
GNU General Public License v3.0

See [LICENSE](LICENSE) for details.
