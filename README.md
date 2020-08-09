B-B-B-B-Beat
---

v0.7.1

A blatant copy of [Ableton's Beat Repeat](https://www.ableton.com/en/blog/guide-beat-repeat-quantize-courses/) for Norns, with some added glitchy inspiration from [MASF Possessed](https://www.youtube.com/results?search_query=masf+possessed)/[MWFX Judder](https://www.youtube.com/results?search_query=mwfx+judder).

This script uses live audio for all of its beat repeating magic!

This script is getting closer and more stable to be a 1.0. I've added some additional params to manage the glitchy aspects. Further testing is required and I'm also looking to add some features before an official release. So, I'm releasing this here to gather feedback and bugs as I inch my way towards a 1.0.0.

![B-B-B-B-Beat UI](.assets/b-b-b-b-beat.gif)

## Demo

I'll post a brief demo showing B-B-B-B-Beat in action, soon.


## Requirements

[Norns](https://monome.org/norns) or [Fates](https://llllllll.co/t/fates-a-diy-norns-dac-board-for-raspberry-pi/22999) or device. For Fates owners, BPM value can be persistently controlled using the 4th encoder, for Norns owners it's `E2` the first page `P0`


## Install/Update

B-B-B-B-Beat can be installed via [Maiden's](https://norns.local/maiden) project manager.

Or you can download [https://github.com/frederickk/b-b-b-b-beat/archive/primary.zip](https://github.com/frederickk/b-b-b-b-beat/archive/primary.zip) and upload to Norns using [sftp/Cyberduck/etc](https://llllllll.co/t/norns-maiden/14052/41) then rename folder to `b-b-b-b-beat`.


## Params

![B-B-B-B-Beat parameters](.assets/b-b-b-b-beat-params.gif)

Here's a table of all the controls and their value ranges. These params can also be controled with Midi CC via `MAP` within params menu.

| Page    | Controller                    | Description                               | Values                         |
| ------- | ----------------------------- | ----------------------------------------- | ------------------------------ |
| All     | E1                            | Change page                               |                                |
| All     | K2                            | Resync to beat 1                          |                                |
| All     | K3                            | Randomize parameters                      |                                |
| 0       | E2 or E4                      | BPM                                       | 20 - 300                       |
| 1       | E2                            | Interval length                           | 1/256 - 4                      |
| 1       | E2                            | Grid length                               | 1/256 - 4                      |
| 2       | E2                            | % repeat occurrence (chance)              | 0 - 100%                       |
| 2       | E3                            | amount of Grid variance                   | 0 - 10                         |
| 3       | E2                            | % glitch occurrence                       | 0 - 100%                       |


## Development

[SSH](https://monome.org/docs/norns/maiden/#ssh) into your Norns/Fates, then enter the following commands in terminal.

```bash
$ cd dust/code
$ git clone https://github.com/frederickk/b-b-b-b-beat.git
```

If you want to get the latest version run these commands:

```bash
$ cd dust/code/b-b-b-b-beat
$ git fetch origin
$ git checkout primary
$ git merge origin/primary
```


## Changelog
- v0.7.0
    - Removed SC engine, restart no longer required on install
    - Addressed repeat (tempo/softcut) bugs
    - Tweaked UI
- v0.6.0
    - Refactored codebase 
- v0.5.0
    - Fixed Glitch engine
    - Added param to toggle glitch noise (hiss)
    - Added param to toggle UI glitch
    - Added param to toggle stutter
    - Added to Maiden
- v0.4.0
    - Fixed params bug; params:add_option
    - Fixed "Chance" param; default 100%
    - Added Midi passthrough
    - Enabled param reading/writing
- v0.3.0 Initial release
