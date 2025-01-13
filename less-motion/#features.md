
# Currently
- now after single tap if I tap fast its sending not the 1 shifted key but 2 shifted keys


- after single tap it should send only 1 shifted key and they stop doing it, but it keeps doing it sending shifted keys only after 1 caps tap



- 1 caps tap should've send 1 shifted key and return to normal mode
- double caps should send shifted keys till I do release caps
        do we add tracking of capsUP somehow?


- sometimes Caps behaviour is getting turned on despite me not using it
- Potentially for shift we do single caps tap   
        for the next symbol to be shifted.
        And what if for caps + T/H = holding caps would be like holding shift,
        till the moment you don't release the Caps or press the H/T again


"Tap for Shift" concept seems like the most promising from a UX perspective, as it maintains a degree of immediacy. However, the timing is absolutely critical for it to feel natural and not frustrating. Experiment with different timing windows (e.g., 100ms, 150ms, 200ms) to find what feels best.


- potentially for shift instead of 2xCaps => Caps+Tab hold to be sure about pressing it and not mess up with just CapsLock
- Caps + Shift still working, it shouldn't be like that, Caps+Shift+V is not working as well







# Potential, further Ideas
        - Caps + ~ = Alt+~ terminal activation
        - Caps+S+/ = Ctrl+Enter
        - Caps+Shift+/ = Ctrl+Shift+Enter
        - is there a better idea for a shift? or just have to get used to it? Caps+ Tabto
        - Caps + Click as a Ctrl + Click 




## Hotstrings entering the arena
- ;dpp = delete previous paragraph, as a hotstring, not as a hotkey
- ;dw = delete word
- ;d{Space}= {Delete}

- ;aw = accent a word
- ;awd = accent a word delete
- ;ap = accent a paragraph
- ;aa = all accent 

- do we do anything about the "-_/+=" as a hotkey?;dot
- ;j;ke -> looking for the "ke" to jump to further  
- ;pl = previous line
- ;nl = next line
- Caps + 1/2/3 = as Alt + 1/2/3 to switch editors







# Completed already
        #1m #3w #пн #2025 / #2025_01_13 #winter
+ fixed = singleCapsTab now is working nicely
        but when I doubleCapsTab holding it, 
        it's also sending only 1 shifted key,
        - but it should send as many shifter key as I want as long as I hold shift in a doublecapsTab mode  



+ great, but now when I quit the editing mode (after holding caps)
        it's registering the release (capslock up)
        and activating shifted keys for some reason
        but I want to track only fast taps


+ kinda great now, lil bit of progress
        but instead of instantly detecting as a shifted key,
        i want it to turn it on after 1st CapsLockUpReleased
        because when I just hold Caps->wanna edit faster
        same thing with a double caps => track if there was 1 release + 2nd press

#12m #5w #2024
- alt+tab lost it functionality cuz it's sending tab when detected in combination with CapsLock
        : made the Hotif context for a tab activation
        = as a result, its not touching the regular tab
        

#12m #4w #2024
+ ctrl + u as vim-like undo
+ double caps > shift (working integrated, but not every button, especially when layout switched / KR-EN-CN)
        for multiple cross-layout RU-EN support, changed it all to VK code
        + map for the cross-binds so its not interrupting with each other
+ tab as expected - but its sending only tab in alt-tab
+ delete to d, and backspace little bit further to ' so no missclick when moving, potentially [ as a delete cuz its above the '




