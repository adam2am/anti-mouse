nice question about an overkill -
# whats needed here, whats actually needed while this stage, could be soo fcking great + supporting a main idea, makes so much sense
== probably:



## currently:
### wanna finish this week max, too much time on it (#4m #1w #5fr #2025 / #2025_04_04 #spring)


- 2 - sub-cells precision
precise sub-cells + better shortcuts overall, 
nicer way of handling within a cell... how?
because its, well, conflicting with 1/2 numbers (multi-monitor), 
and also not covering full range being lil bit not precise within the cell, what are the pottential options here?


/ CVBNM - not used, 
/ but if to keep those and make 4x4 subgrids =  1 - C CC VV V?  //  2 - C CV VC V? (chords)


# 3 modes:
[
1.  ULTRA-FAST SUBGRID - hold right hand keys (uiopjkl;m,.) while on a cell
        how is it fast: 
        -> caps(hold)+Q/1/2(monitors) == actibating a grid
        -> Cell(Q+L) = position
        -> (holdingL)+Z > precise cursor releasing caps = tap
        // potential: to add if space in hold = dont need a tap? questionable.
        |
        => activating subgrid of the left-hand keys(asdfzxcvqwer)
        **Hold Second Key + Distinct Keys:** (New Idea)
        **Mechanism:** Press Col key -> As soon as Row key *being pressed and held* -> While Row key is held, distinct keys (e.g., `qwerasdfzcv`) select 3x4 sub-cell -> Releasing Row key performs click. (Tapping Row key normally just selects cell center/memory).
        
        **Pros:** Integrates sub-cell selection and click into one fluid motion after cell selection. No extra keys needed beyond grid + distinct subgrid keys.
        
        **Cons:** Requires holding a key, potentially less ergonomic. Timing sensitive (tap vs hold). Might interfere with key repeat. Complex logic.
        
        **Rating:** Speed: 8/10 (potentially), Precision: 8/10, Less Motions: 8/10, Conflict Risk: Low-Med, Ergonomics: Medium. **Overall: 8/10**
        -- potential refinement:
                >> when right hand (rowCol) button being held: 
                bto make subgrid for the left (qwer)
                also can make if chrod being held like that releasing gonna press it ?


2. MiddleSpeed subgrid (automatic right hand subgrid, if missclicked > press left hand buttons to make move again)
        **Modal Distinct Keys (Right Hand 3x3):** (Option 5 from 1.0, refined)
        **Mechanism:** 
        -> Cell selected 
        -> Subgrid mode active (uiopjkl;m,.) 
        -> Press a key from a distinct set on the right hand (e.g., `uio`, `jkl`, `m,.`) for 3x3 sub-cell. 
        Press `Space`/Release Caps to click. Pressing any *left-hand* main grid key (`qwerasdfzxcv`) immediately starts a new selection.

        **Pros:** No modifier hold, single key press for subcell, clear separation (left hand restarts, right hand selects subcell), avoids monitor/Numpad conflicts, good ergonomics. Addresses "flawed if missclicked" - just press a left-hand key.
        
        **Cons:** Requires learning the right-hand map. 3x3 initially (expandable).
        
        **Rating:** Speed: 8/10, Precision: 8/10, Less Motions: 8/10, Conflict Risk: Low, Ergonomics: Good. **Overall: 8/10**
        >> this is making rapid presses (uipojkl;) impossible
        >> so if I missclick > I cant do again unless I do extra click (qwertasdfzxcvb)
        -- potential refinement:
            >> when right hand (rowCol) button being held: 
            bto make subgrid for the left (qwer)
            also can make if chrod being held like that releasing gonna press it ?


3.  ExtraKeySubGrid - Alt. To activate subgrid requires pressing another button ()
        **Contextual Modifier (Alt - Post-Selection):** (New Idea)
        **Mechanism:** Cell selected (Col+Row pressed) -> Now, pressing `Alt` + home row key (`w/e/r`...) selects 3x3 sub-cell. `Alt` only has this function immediately after cell selection. Pressing `Alt` at other times is ignored or passed through. Pressing grid key starts new selection.
        **Pros:** Similar to #1 but reduces `Alt+Key` conflict window significantly. Ergonomic, 3x3 precision.
        **Cons:** Slightly more complex logic (timing/context for Alt). Still requires modifier.
        **Rating:** Speed: 7/10, Precision: 8/10, Less Motions: 7/10, Conflict Risk: Low, Ergonomics: Good. **Overall: 7.5/10**
]




- also not being too fast, grid is taking time to show up
        (fast pressing caps+caps+cell) 
        > making it type the letter instead




## further:
- if monitor not being used (3/4) = we have extra buttons to store functionality in
        for example = snapping to specific Collumn if using it a lot like q / a etc


-  0 - choosing which one side I dont need to save position of a subcell for 
/ choosing what cells I gotta save position for?
/ == if often visiting this thing

        - saving state of subcell not working 100% of the time. 
        probably dont even need it
        / deleting saving previous subcell position?
        / just choose what cell I wanna save position for in settings? = like with a chat q.


- 1 - more robust activation overall based on analysis of a logic flow



-- another option could be 
/ qwerty - 1/3 top
/ asdfg - a/3 mid
/ zxcvb - 1/3 bot
-- but it doesn't do anything about the fast precision


- 2 - storing favorite positions where to click?
        Alt+Caps+1/2/3/4/5/6?
        or some other key bindings?
        caps+3/4/5 holding = storing and just caps+3 = activating 
- 2.1 - chording = qlql = jumping to that saved place ql2qlqlql
                / oaoa = jumping to it

- 3 - darker theme (sometimes cant see a letters) = I like mouseless (windows one)

- 4 - ability to JLK cursor, scroll and click it like in firefox

- 5 - just mouseless mode, without a lessmotions-Hotkeys cursor within
        = caps + pa would insta jump to that PA and other spaces





# ok, imma keep those:
#4m #1w #7sun #2025 / #2025_04_06 #spring
- refined: activation on caps+caps(hold) 
        instead of 2 full caps presses with releases
        = lil bit more speed

- added: tracking for a grid on/off
        = sometimes there were double grid for some reason (caps+caps+q)
        / also some logic flaws in hiding it

#4m #1w #5fr #2025 / #2025_04_04 #spring
potentially 
=> setup hotstring ;settings 
== opening up the textbox with all the manual settings, current map + modes etc


// refining, i dont like the "," as a target option, just gonn delete it? to see whats up


--- angle, potentially storing the position of the subcell for each monitor as an extra option
        if monitor 1 - EBN, monitor 2 could be just EB
        it has to detect the positon of current cursor (which monitor)


- 1 - regular grid feels soo much nicer when different hands (ql / is etc),
but when the same hand (qa, es), feels not smooth at all     
// angle: to make it more differentiated by hand 
/         = 1 letter for a left one, 2nd for a righ1t one

- /caps1/caps2 potential nicer more intuitive short11cuts between monitors


# checked, not really working:
- 1 - caps+q to caps+tab => reverse, annoying shortcut
