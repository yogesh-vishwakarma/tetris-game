#!/bin/bash

clear
echo -e '\n\n\n'
echo -e '===========    =========    ============           =========   ==========         ====='
echo -e '    ||         ||                ||                ||      ||      ||            ||    ||'
echo -e '    ||         ||                ||                ||      ||      ||            ||    ||'
echo -e '    ||         ||                ||                ||    ||        ||             ||'
echo -e '    ||         ||======          ||                ||=====         ||               ||'
echo -e '    ||         ||                ||                ||    ||        ||                 ||'
echo -e '    ||         ||                ||                ||     ||       ||                   ||'
echo -e '    ||         ||                ||                ||      ||      ||             ||   ||'
echo -e '    ||         =========         ||                ||       ||  =========           ==='
echo -e '\n\n\n'
echo -e '--------------------------------press one for new game----------------------------------'
echo -e '-------------------------------------------or-------------------------------------------'
echo -e '--------------------------------press anything for exit----------------------------------\n\n\n\n\n\n\n'
echo -e '\t\t\t\t\t\t\t\tby:\n'
echo -e '\t\t\t\t\t\t\t\tYOGESH VISHWAKARMA  16IT150'
echo -e '\t\t\t\t\t\t\t\tAMIT KUMAR BANARJEE 16IT106'
echo -e '\t\t\t\t\t\t\t\tARUNABHA PATRA      16IT109'
echo -e '\t\t\t\t\t\t\t\tRAM KUMAR GHASTI    16IT132\n\n\n'
read -n1 as
if [[ $as == 1 ]]; then
{


# 2 signals are used: SIGUSR1 to decrease delay after level up and SIGUSR2 to quit
# they are sent to all instances of this script
# because of that we should process them in each instance
# in this instance we are ignoring both signals
trap '' SIGUSR1 SIGUSR2

# Those are commands sent to controller by key press processing code
# In controller they are used as index to retrieve actual functuon from array
QUIT=0
RT=1
LT=2
ROT=3
DN=4
DP=5
HELPTOGGLE=6
NEXTTOGGLE=7
COLORTOGGLE=8

DELAY=1          # initial delay between piece movements
DFACTOR=0.8 # this value controld delay decrease for each level up

# color codes
RED=1
GREEN=2
YELLOW=3
BLUE=4
FUCHSIA=5
CYAN=6
WHITE=7

# Location and size of playfield, color of border
WPLAYFIELD=10
HPLAYFIELD=20
XPLAYFIELD=30
YPLAYFIELD=1
COLORBORDER=$YELLOW

# Location and color of score information
XSCORE=1
YSCORE=2
COLORSCORE=$GREEN

# Location and color of help information
XHELP=58
YHELP=1
COLORHELP=$CYAN

# Next piece location
XNEXT=14
YNEXT=11

# Location of "game over" in the end of the game
XGAMEOVER=1
YGAMEOVER=$((HPLAYFIELD + 3))

# Intervals after which game level (and game speed) is increased 
UPLEVEL=20

colors=($RED $GREEN $YELLOW $BLUE $FUCHSIA $CYAN $WHITE)

colorno=true    # do we use color or not
showtime=true    # controller runs while this flag is true
empty="  "  # how we draw empty cell
filled="[]" # how we draw filled cell

points=0           # score variable initialization
level=1           # level variable initialization
completedlines=0 # completed lines counter initialization

# bufferscreen is variable, that accumulates all screen changes
# this variable is printed in controller once per game cycle
puts() {
    bufferscreen+=${1}
}

# move cursor to (x,y) and print string
# (1,1) is upper left corner of the screen
xyprint() {
    puts "\033[${2};${1}H${3}"
}

# foreground color
fgset() {
    $colorno && return
    puts "\033[3${1}m"
}

# background color
bgset() {
    $colorno && return
    puts "\033[4${1}m"
}


# playfield is 1-dimensional array, data is stored as follows:
# each array element contains cell color value or -1 if cell is empty
fieldredraw() {
    local j i x y xp yp

    ((xp = XPLAYFIELD))
    for ((y = 0; y < HPLAYFIELD; y++)) {
        ((yp = y + YPLAYFIELD))
        ((i = y * WPLAYFIELD))
        xyprint $xp $yp ""
        for ((x = 0; x < WPLAYFIELD; x++)) {
            ((j = i + x))
            if ((${field[$j]} == -1)) ; then
                puts "$empty"
            else
                fgset ${field[$j]}
                bgset ${field[$j]}
                puts "$filled"
                puts "\033[0m"
            fi
        }
    }
}

scoreupdate() {
    # Arguments: 1 - number of completed lines
    ((completedlines += $1))
    ((points += ($1 * $1)))
    if (( points > UPLEVEL * level)) ; then          # if level should be increased
        ((level++))                                  # increment level
        pkill -SIGUSR1 -f "/bin/bash $0" # and send SIGUSR1 signal to all instances of this script (please see ticker for more details)
    fi
    puts "\033[1m"
    fgset $COLORSCORE
    xyprint $XSCORE $YSCORE         "Lines completed: $completedlines"
    xyprint $XSCORE $((YSCORE + 1)) "Level:           $level"
    xyprint $XSCORE $((YSCORE + 2)) "Points:          $points"
    puts "\033[0m"
}

help=(
"  Use cursor keys"
"       or"
"      s: up"
"a: left,  d: right"
"    space: drop"
"      q: quit"
"  c: toggle color"
"n: toggle show next"
"h: turn off menu "
)

onhelp=-1 # if this flag is 1 help is shown

helptoggle() {
    local i s

    puts "\033[1m"
    fgset $COLORHELP
    for ((i = 0; i < ${#help[@]}; i++ )) {
        # ternary assignment: if onhelp is 1 use string as is, otherwise substitute all characters with spaces
        ((onhelp == 1)) && s="${help[i]}" || s="${help[i]//?/ }"
        xyprint $XHELP $((YHELP + i)) "$s"
    }
    ((onhelp = -onhelp))
    puts "\033[0m"
}

piece=(
"00011011"                         # square piece
"0212223210111213"                 # line piece
"0001111201101120"                 # S piece
"0102101100101121"                 # Z piece
"01021121101112220111202100101112" # L piece
"01112122101112200001112102101112" # inverted L piece
"01111221101112210110112101101112" # T piece
)

piecedraw() {
    # Arguments:
   
    local i x y

    # loop through piece cells: 4 cells, each has 2 coordinates
    for ((i = 0; i < 8; i += 2)) {
        ((x = $1 + ${piece[$3]:$((i + $4 * 8 + 1)):1} * 2))
        ((y = $2 + ${piece[$3]:$((i + $4 * 8)):1}))
        xyprint $x $y "$5"
    }
}

piecenext=0
rotatenext=0
colornext=0

onnext=1 # if this flag is 1 next piece is shown

nexttoggle() {
    case $onnext in
        1) ((onnext == -1)) && return
    piecedraw $XNEXT $YNEXT $piecenext $rotatenext "${filled//?/ }"; onnext=-1 ;;
        -1) onnext=1; 
            fgset $colornext
             bgset $colornext
            ((onnext == -1)) && return
            piecedraw $XNEXT $YNEXT $piecenext $rotatenext "${filled}"
            puts "\033[0m" ;;
    esac
}


locnewpiece() {
    local j i x y x_test=$1 y_test=$2

    for ((j = 0, i = 1; j < 8; j += 2, i = j + 1)) {
        ((y = ${piece[$piececurrent]:$((j + rotatecurrentpiece * 8)):1} + y_test)) # new y coordinate of piece cell
        ((x = ${piece[$piececurrent]:$((i + rotatecurrentpiece * 8)):1} + x_test)) # new x coordinate of piece cell
        ((y < 0 || y >= HPLAYFIELD || x < 0 || x >= WPLAYFIELD )) && return 1         # check if we are out of the play field
        ((${field[y * WPLAYFIELD + x]} != -1 )) && return 1                       # check if location is already ocupied
    }
    return 0
}

randomnext() {
    # next piece becomes current
    piececurrent=$piecenext
    rotatecurrentpiece=$rotatenext
    colorcurrent=$colornext
    # place current at the top of play field, approximately at the center
    ((xpiece = (WPLAYFIELD - 4) / 2))
    ((ypiece = 0))
    # check if piece can be placed at this location, if not - game over
    locnewpiece $xpiece $ypiece || quitcmd
    fgset $colorcurrent
    bgset $colorcurrent
    piecedraw $((xpiece * 2 + XPLAYFIELD)) $((ypiece + YPLAYFIELD)) $piececurrent $rotatecurrentpiece "${filled}"
    puts "\033[0m"

    ((onnext == -1)) && return
    piecedraw $XNEXT $YNEXT $piecenext $rotatenext "${filled//?/ }"
    # now let's get next piece
    ((piecenext = RANDOM % ${#piece[@]}))
    ((rotatenext = RANDOM % (${#piece[$piecenext]} / 8)))
    ((colornext = RANDOM % ${#colors[@]}))
        fgset $colornext
    bgset $colornext
    ((onnext == -1)) && return
    piecedraw $XNEXT $YNEXT $piecenext $rotatenext "${filled}"
    puts "\033[0m"
}

borderdraw() {
    local i x1 x2 y

    puts "\033[1m"
    fgset $COLORBORDER
    ((x1 = XPLAYFIELD - 2))               # 2 here is because border is 2 characters thick
    ((x2 = XPLAYFIELD + WPLAYFIELD * 2)) # 2 here is because each cell on play field is 2 characters wide
    for ((i = 0; i < HPLAYFIELD + 1; i++)) {
        ((y = i + YPLAYFIELD))
        xyprint $x1 $y "{{"
        xyprint $x2 $y "}}"
    }

    ((y = YPLAYFIELD + HPLAYFIELD))
    for ((i = 0; i < WPLAYFIELD; i++)) {
        ((x1 = i * 2 + XPLAYFIELD)) # 2 here is because each cell on play field is 2 characters wide
        xyprint $x1 $y '=='
        #xyprint $x1 $((y + 1)) "{}"
    }
    puts "\033[0m"
}

colortoggle() {
    $colorno && colorno=false || colorno=true
        fgset $colornext
    bgset $colornext
    ((onnext == -1)) && return
    piecedraw $XNEXT $YNEXT $piecenext $rotatenext "${filled}"
    puts "\033[0m"
    scoreupdate 0
    helptoggle
    helptoggle
    borderdraw
    fieldredraw
    fgset $colorcurrent
    bgset $colorcurrent
    piecedraw $((xpiece * 2 + XPLAYFIELD)) $((ypiece + YPLAYFIELD)) $piececurrent $rotatecurrentpiece "${filled}"
    puts "\033[0m"
}



# this function runs in separate process
# it sends DOWN commands to controller with appropriate delay
ticker() {
    # on SIGUSR2 this process should exit
    trap exit SIGUSR2
    trap 'DELAY=$(awk "BEGIN {print $DELAY * $DFACTOR}")' SIGUSR1
    
    while true ; do echo -n $DN; sleep $DELAY; done
}

# this function processes keyboard input
reader() {
    trap exit SIGUSR2 # this process exits on SIGUSR2
    trap '' SIGUSR1   # SIGUSR1 is ignored
    local -u key a='' b='' cmd esc_ch=$'\x1b'
    # commands is associative array, which maps pressed keys to commands, sent to controller
    declare -A commands=([A]=$ROT [C]=$RT [D]=$LT
        [_S]=$ROT [_A]=$LT [_D]=$RT
        [_]=$DP [_Q]=$QUIT [_H]=$HELPTOGGLE [_N]=$NEXTTOGGLE [_C]=$COLORTOGGLE)

    while read -s -n 1 key ; do
        case "$a$b$key" in
            "${esc_ch}["[ACD]) cmd=${commands[$key]} ;; # cursor key
            *${esc_ch}${esc_ch}) cmd=$QUIT ;;           # exit on 2 escapes
            *) cmd=${commands[_$key]:-} ;;              # regular key. If space was pressed $key is empty
        esac
        a=$b   # preserve previous keys
        b=$key
        [ -n "$cmd" ] && echo -n "$cmd"
    done
}

fieldflatten() {
    local i j k x y
    for ((i = 0, j = 1; i < 8; i += 2, j += 2)) {
        ((y = ${piece[$piececurrent]:$((i + rotatecurrentpiece * 8)):1} + ypiece))
        ((x = ${piece[$piececurrent]:$((j + rotatecurrentpiece * 8)):1} + xpiece))
        ((k = y * WPLAYFIELD + x))
        field[$k]=$colorcurrent
    }
}

# this function goes through field array and eliminates lines without empty cells
linescompleted() {
    local j i linecomplete
    ((linecomplete = 0))
    for ((j = 0; j < WPLAYFIELD * HPLAYFIELD; j += WPLAYFIELD)) {
        for ((i = j + WPLAYFIELD - 1; i >= j; i--)) {
            ((${field[$i]} == -1)) && break # empty cell found
        }
        ((i >= j)) && continue # previous loop was interrupted because empty cell was found
        ((linecomplete++))
        # move lines down
        for ((i = j - 1; i >= 0; i--)) {
            field[$((i + WPLAYFIELD))]=${field[$i]}
        }
        # mark cells as free
        for ((i = 0; i < WPLAYFIELD; i++)) {
            field[$i]=-1
        }
    }
    return $linecomplete
}

fallenpiece() {
    fieldflatten
    linescompleted && return
    scoreupdate $?
    fieldredraw
}

piecemove() {
# arguments: 1 - new x coordinate, 2 - new y coordinate
# moves the piece to the new location if possible
    if locnewpiece $1 $2 ; then # if new location is ok
    piecedraw $((xpiece * 2 + XPLAYFIELD)) $((ypiece + YPLAYFIELD)) $piececurrent $rotatecurrentpiece "${empty}"                   # let's wipe out piece current location
        xpiece=$1                # update x ...
        ypiece=$2                # ... and y of new location
        fgset $colorcurrent
    bgset $colorcurrent
    piecedraw $((xpiece * 2 + XPLAYFIELD)) $((ypiece + YPLAYFIELD)) $piececurrent $rotatecurrentpiece "${filled}"
    puts "\033[0m"                      # and draw piece in new location
        return 0                          # nothing more to do here
    fi                                    # if we could not move piece to new location
    (($2 == ypiece)) && return 0 # and this was not horizontal move
    fallenpiece                  # let's finalize this piece
    randomnext                       # and start the new one
    return 1
}

rightcmd() {
    piecemove $((xpiece + 1)) $ypiece
}

leftcmd() {
    piecemove $((xpiece - 1)) $ypiece
}

rotatecmd() {
    local available_rotations rotationold rotationnew

    available_rotations=$((${#piece[$piececurrent]} / 8))            
    rotationold=$rotatecurrentpiece                              # preserve current orientation
    rotationnew=$(((rotationold + 1) % available_rotations))        # calculate new orientation
    rotatecurrentpiece=$rotationnew                              # set orientation to new
    if locnewpiece $xpiece $ypiece ; then # check if new orientation is ok
        rotatecurrentpiece=$rotationold                         
    piecedraw $((xpiece * 2 + XPLAYFIELD)) $((ypiece + YPLAYFIELD)) $piececurrent $rotatecurrentpiece "${empty}"                                            # clear piece image
        rotatecurrentpiece=$rotationnew                          # set new orientation
        fgset $colorcurrent
    bgset $colorcurrent
    piecedraw $((xpiece * 2 + XPLAYFIELD)) $((ypiece + YPLAYFIELD)) $piececurrent $rotatecurrentpiece "${filled}"
    puts "\033[0m"                                                  # draw piece with new orientation
    else                                                              # if new orientation is not ok
        rotatecurrentpiece=$rotationold                          
    fi
}

downcmd() {
    piecemove $xpiece $((ypiece + 1))
}

dropcmd() {
    # move piece all way down
    
    while piecemove $xpiece $((ypiece + 1)) ; do : ; done
}

quitcmd() {
    showtime=false                               
    pkill -SIGUSR2 -f "/bin/bash $0" # ... send SIGUSR2 to all script instances to stop forked processes ...
    xyprint $XGAMEOVER $YGAMEOVER "Game over!"
    echo -e "$bufferscreen"                     
}

controller() {
    # SIGUSR1 and SIGUSR2 are ignored
    trap '' SIGUSR1 SIGUSR2
    local cmd commands

    # initialization of commands array with appropriate functions
    commands[$QUIT]=quitcmd
    commands[$RT]=rightcmd
    commands[$LT]=leftcmd
    commands[$ROT]=rotatecmd
    commands[$DN]=downcmd
    commands[$DP]=dropcmd
    commands[$HELPTOGGLE]=helptoggle
    commands[$NEXTTOGGLE]=nexttoggle
    commands[$COLORTOGGLE]=colortoggle

    local i x1 x2 y

    
    for ((i = 0; i < HPLAYFIELD * WPLAYFIELD; i++)) {
        field[$i]=-1
    }

    clear
    echo -ne "\033[?25l"
    randomnext
    randomnext
    colortoggle

    while $showtime; do           # run while showtime variable is true, it is changed to false in quitcmd function
        echo -ne "$bufferscreen" 
        bufferscreen=""          
        read -s -n 1 cmd         
        ${commands[$cmd]}        
    done
}

stty_g=`stty -g` # let's save terminal state

# output of ticker and reader is joined and piped into controller
(
    ticker & # ticker runs as separate process
    reader
)|(
    controller
)

echo -ne "\033[?25h"
stty $stty_g # terminal state
}
else
    clear
    echo -e '\n\n\n\n'
    echo '--------------------------------------------exit confirmed-------------------------------------'
    echo -e '\n\n\n\n '
fi
