# Currently
- also, when i want to go back to my powered mode (naVigation) and doing caps+JKL, it would for some reason take me extra click to get the movement, instead of instantelly creating a movement based on my commabnd



- do we do right shift as a enter? cuz it's like enter, but closer
        RShift as enter, Caps+Rshift as Shift+Enter 
        switching language layout with something else as well 
        like J and F has physically something on them to physially feel and navigate
        is it possible to do something about ' to feel the backspace




- instead of caps 1 tap as a shift, wanna make Shift one tap for a next 1 shifted key instead of caps onetap
- everywhere so caps mode doesnt work when shift is physically pressed .
        or make that shift doesnt work but priority to a caps mode
- deLete caps+H cuz whats the difference
- antimouse gui



- what about caps+H, is it viable?
        nope, it's needed to hold, but i want toggle
        but the way to turn it off - being releasing caps and not pressing H again


- also when I press caps + ', for some reason its turning on shifted mode sometimes, do I need to make it unregister it every time I do caps + other power buttons?


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
        - caps + \ as backspace as well, so don't need to do exactly ', can do \ as well (2 buttons on a right of a finger)

        - Caps+S+/ = Ctrl+Enter
        - Caps+Shift+/ = Ctrl+Shift+Enter
        - is there a better idea for a shift? or just have to get used to it? Caps+ Tabto
        - Caps + Click as a Ctrl + Click 
        - Caps + tab = shift tab
        - is there a excalidraw for vscode studio    



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
        #1m #3w #чт #2025 / #2025_01_16 #winter
+ after tooltip dissapears (1sec) -> nextShiftedKey mode now also dissapear

+ ; is now turning into : in shifted mode (forgot to include previously)

+ layout translation now works

+ enter stopped working in caps mode
        >> refactored with map and GetKeyState mode

+ second tap to turn of the nextshiftedkey mode,
        also a tooltip is not dissapearing despite mode being not active already
        >> calling tooltip () to make it dissapear everytime

+ second tap to turn of the nextshiftedkey mode

+ shift is keep being shift even after I already sent a key with shift (Shift(pressed)+Some key), 
        then i would type something and it would Do shifted key Again(Cuz activated after shift up and not tracking it) 
        // I Guess have to track all keys again?
        // or getkeystate any inside of the shift?
                >> shift not checking all of the buttons clicked with shift

+ caps when deleted fast sometimes keep Next shifted key UP mode
        >> tracking combo of caps+button as well with a counter


        #1m #3w #ср #2025 / #2025_01_15 #winter
+ when caps pressed first, now shift is not sending shifted keys/when shift pressed first, caps is not sending keys
        > with tracking statements all good

+ Shift/Caps one tap doing double shifted keys sometimes
it works nicely with a single tap,
but if I want to do triple tap BNM it would do all shifted keys
        IF I rapidly insta clicking 3 buttons like CapsUp > NMB         
        (it would send the 3 shifted keys, but it should send only 1st shifted key)??
        > did it with a number counting


        #1m #3w #вт #2025 / #2025_01_14 #winter
+ When typing, suddenly was kinda thinking about returning a 1 tap caps mode, instead of only shift 1 tap mode.
+ Caps + ~ = Alt+~ terminal activation


        #1m #3w #пн #2025 / #2025_01_13 #winter
+ single/double tap CapsLock works nicely (- great, now what if I pressed 1 tap of caps, but then decided to enter a regular editing mode, is there a way to switch back to default editing capslock powerbuton mode?)


+ improved = after single tap if was sending not the 1 shifted key but 2 shifted keys sometimes


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




