# Currently
- antimouse gui:
>> some progress

/antimouse with claude
        - for now its ending everything in 1 cell (antimouse with claude)
                and not moving to a next cell
        - showing everything on 1 monitor instead of 2,
                but movement works nicely between both monitors
        >> sugg: to make different letters for different layout
                qwert yuiop // q is debatable, cuz left finger on a capsedr
                asdf ghjk

/antimouse 0.01
        - sometimes it's going to 2nd letter (AB) it would go B as a collumn
        - sometimes it would confuse my taps
                i would do GM it would go G collumn first, then back to M collumn
                instead of GM cell
                ex: for now whats happeniing: 
                        - pressing I>I>D>F == and it should do 
                                II press > II cell >> DF press > DF cell
                        - but its doing 
                                II press > II cell >> DF press > Dcollumn > Fcollumn
                sugg: -- higlighting a collumn after a first tap 
                        > then when second tap goes to the cell + highlighting a cell itself


        - /remindme
        - automatic date calculation (last time visited? --> auto calculate + mentioning with a n`n`)
        

        
        - when key is shifted = like in mac under the cursor
        - double-tap of caps not turning it off unlike double-shift > wanna make double caps have the same behaviour 

        - its also turning off functionality when pressed button outside of the current layout (k)
        - 2nd monitor support
        - CAPSLOCK STILL getting turned (kekw)
        - as well as space randomly



- ? track if sometimes Caps behaviour is getting turned on despite me not using it
- Potentially for shift we do single caps tap for the next symbol to be shifted.
        - And what if for caps + H = holding caps would be like holding shift,
        till the moment you don't release the Caps or press the H/T again
        '
        "Tap for Shift" concept seems like the most promising from a UX perspective, as it maintains a degree of immediacy. However, the timing is absolutely hcritical for it to feel natural and not frustrating. Experiment with different timing windows (e.g., 100ms, 150ms, 200ms) to find what feels best.h







# Potential, further Ideas
        - caps + \ as backspace as well, so don't need to do exactly ', can do \ as well (2 buttons on a right of a finger)

        - Caps+S+/ = Ctrl+Enter
        - Caps+Shift+/ = Ctrl+Shift+Enter
        - is there a better idea for a shift? or just have to get used to it? Caps+ Tabto
        - Caps + Click as a Ctrl + Click 
        - Caps + tab = shift tab
        - is there a excalidraw for vscode studio    


        - switching language layout with something else as well 
                like J and F has physically something on them to physially feel and navigate
                is it possible to do something about ' to feel the backspace
        - Caps + E as Ctrl+W = exit?
        - Caps + N = navigate (Alt behaviour) for Alt+LeftRightArrow behaviours
                is it even cool to do the N? Cuz its on a right hand where JKLI
                could be cool to do q/e/r/t as a navigation?
                and single tap caps+t = gonna be like a fuzzy finder or smth
                but holding with JKLI 
                        with R is kinda easier.
                        hmmm, need more thinking here 
        - actual Windows navigation via some shortcut / w+smth/ 
                nah, its for words = word delete etc


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

        #1m #3w #пт #2025 / #2025_01_17 #winter
<!-- --- cb16c0709ebbb3f4aad112837a64fbf13c2c6ec6 --- -->
+ rows switch with collumns
WANNA switch rows and collumns,
i mean right now first row is AA AB AC AD etc
i wanna make it  AA BA CA DA EA etc
and so each collumn would go further down
AA AB AC AD not to the right like its right now, but down

+ Instead of waiting for a second tap
        >> moving mouse instantly with a first tap based on a collumn



        #1m #3w #чт #2025 / #2025_01_16 #winter
<!-- 4d3e47e694d299874602a7191789cce0be1e7adb -->
+ now when I do caps > caps+JKL > caps again, it would not turn on shifted mode in a 3rd step, I have to again press caps for that
        - (1st step, dummy shifted mode without pressing else) Caps + CapsUp 
        > (2nd step, navigation) Caps + JKL + CapsUp 
        > (3rd step) Caps + CapsUp
        and on a third step its not sending a shifted key


+ also, when i want to go back to my powered mode (naVigation) and doing caps+JKL, 
        it would for some reason take me extra click to get the movement, 
        >> now instantelly creating a movement based on a shortcut

---
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




