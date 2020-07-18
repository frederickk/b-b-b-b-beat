Engine_Glitch : CroneEngine {
	var pg;
  var lfoVol = 4;
  var cutoff = 10000;
  var amp = 0.3;
  var <synth;

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

  alloc {
    pg = ParGroup.tail(context.xg);
    // lfoVol: LFO volume, range 0–8
    // cutoff: band pass filter cutoff, range 0–20000
    SynthDef(\Glitch, { arg out, lfoVol = 4, cutoff = 10000, amp = 0.3;
      var sig = {
        // var lfoVol = MouseX.kr(0, 8) * Rand(0, 1);
        // var cutoff = MouseY.kr(0, 20000) * Rand(0, 1);
        var noize = BPF.ar(
          WhiteNoise.ar(
            mul: SinOsc.ar(
              lfoVol,
              phase: Rand(0, pi),
              mul: Rand(0.1, 1)
            )
          ), cutoff * Rand(0, 1000)
        );
        
        noize + noize + noize
      };
      
      Out.ar(out, (sig * amp));
    }).add;

		context.server.sync;

		synth = Synth.new(\Glitch, [
			\out, context.out_b.index,
			\lfoVol, context.in_b[0].index,
			\cutoff, context.in_b[1].index,
			\amp, 1],
		context.xg);
    
    // Norns commands
    this.addCommand("play", "f", { arg msg;
      amp = msg[1];
      Synth(\Glitch, [\out, context.out_b, \lfoVol, lfoVol, \cutoff, cutoff, \amp, amp], target:pg);
    });

		this.addCommand("lfoVol", "f", { arg msg;
			synth.set(\lfoVol, msg[1]);
		});
		
		this.addCommand("cutoff", "f", { arg msg;
			synth.set(\cutoff, msg[1]);
		}); 

		this.addCommand("amp", "f", { arg msg;
			synth.set(\amp, msg[1]);
		});		
  }
}

