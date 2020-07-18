B-B-B-B-Beat
---

A blatant copy of [Ableton's Beat Repeat](https://www.ableton.com/en/blog/guide-beat-repeat-quantize-courses/) for Norns, with some added glitchy inspiration from [MASF Possessed](https://www.youtube.com/results?search_query=masf+possessed)/[MWFX Judder](https://www.youtube.com/results?search_query=mwfx+judder).

Follow development progress at [https://llllllll.co/t/35047](https://llllllll.co/t/b-b-b-b-beat-ableton-beat-repeat/35047).

![B-B-B-B-Beat UI](.assets/b-b-b-b-beat.gif)


## Requirements

[Norns](https://monome.org/norns) or [Fates](https://llllllll.co/t/fates-a-diy-norns-dac-board-for-raspberry-pi/22999) or device. For Fates owners, BPM value can be persistently controlled using the 4th encoder, for Norns owners it's `E2` the first page `P0`


## Install/Update

Since B-B-B-B-Beat is still a bit rough around the edges the only way to install is described below under [Development](#development).

**After install or update `RESET` or `SLEEP` is required, because B-B-B-B-Beat installs a new engine.**


## Params

Here's a table of all the controls and their values (also listed within the params menu).


| Page    | Controller                    | Description                               | Values                         |
| ------- | ----------------------------- | ----------------------------------------- | ------------------------------ |
| All     | E1                            | Change page                               |                                | 
| All     | K2                            | Resync to beat 1                          |                                |
| All     | K3                            | Randomize parameters                      |                                |
| 0       | E2 or E4                      | BPM                                       | 20 - 300                       |
| 1       | E2                            | Interval length                           | 1/256 - 4                      |
| 1       | E2                            | Grid length                               | 1/256 - 4                      |
| 2       | E2                            | % repeat occurance (chance)               | 0 - 100%                       |
| 2       | E3                            | amount of Grid variance                   | 0 - 10                         |
| 3       | E2                            | % glitch occurance                        | 0 - 100%                       |

## Development

Download [github.com/frederickk/b-b-b-b-beat/archive/primary.zip](https://github.com/frederickk/b-b-b-b-beat/archive/primary.zip) and upload to Norns using [sftp/Cyberduck/etc](https://llllllll.co/t/norns-maiden/14052/41) then rename folder to `b-b-b-b-beat`.

Or [SSH](https://monome.org/docs/norns/maiden/#ssh) into your Norns/Fates, then enter the following commands in terminal.

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

- v0.0.3 Initial release

