#!/bin/bash
# Launch any game/app with 8BitDo Ultimate 2C controller support
# Usage: ./launch.sh /path/to/game.app
#    or: ./launch.sh steam://open/bigpicture

export SDL_GAMECONTROLLERCONFIG="03000000c82d00001d30000001000000,8BitDo Ultimate 2C Wired Controller,a:b1,b:b0,x:b3,y:b4,leftshoulder:b6,rightshoulder:b7,back:b10,start:b11,guide:b12,leftstick:b13,rightstick:b14,leftx:a0,lefty:a1,rightx:a2,righty:a3,lefttrigger:a4,righttrigger:a5,dpup:h0.1,dpright:h0.2,dpdown:h0.4,dpleft:h0.8,platform:Mac OS X"

if [ -z "$1" ]; then
    echo "Usage: ./launch.sh <app-path-or-url>"
    echo ""
    echo "Examples:"
    echo "  ./launch.sh /Applications/SomeGame.app"
    echo "  ./launch.sh steam://open/bigpicture"
    echo ""
    echo "Or set the environment variable globally:"
    echo "  export SDL_GAMECONTROLLERCONFIG='$SDL_GAMECONTROLLERCONFIG'"
    exit 1
fi

TARGET="$1"
shift

if [[ "$TARGET" == *"://"* ]]; then
    open "$TARGET"
elif [[ "$TARGET" == *.app ]]; then
    open -a "$TARGET" --args "$@"
else
    "$TARGET" "$@"
fi