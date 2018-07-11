'use strict';

require('./static/style.css');
const Elm = require('./elm/Main.elm');

let app = Elm.Main.fullscreen({
  debug: true,
  scene: [
    "#########################################",
    "#.......................................#",
    "#.......................          ......#",
    "#|||||||||..........P...E         ......#",
    "#|**| O  O..............................#",
    "#|**| || |....OOOOOOOOO.................#",
    "#|**| || |.....OOOOOOO........*.........#",
    "#|**| || |......OOOOO...................#",
    "#|**| ||=|...................*..........#",
    "#|**| ||||.....       ..................#",
    "#|**| ||*|....         ..........*......#",
    "#|**|E||*|...           ................#",
    "#|||||||||..............................#",
    "#...................*...................#",
    "#.......................................#",
    "#....*.........................*........#",
    "#............*..........................#",
    "#.......................................#",
    "#########################################"
  ]
});
