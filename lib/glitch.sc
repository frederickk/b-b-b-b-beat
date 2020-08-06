Engine_Glitch : CroneEngine {
    var <synth;

  *new { arg context, doneCallback;
    ^super.new(context, doneCallback);
  }

  alloc {
    SynthDef(\Glitch, { arg out, lfoVol = 4, cutoff = 10000, amp = 0.3;
      var noize1, noize2, noize3, sig;

      noize1 = BPF.ar(
        WhiteNoise.ar(
          mul: SinOsc.ar(
            lfoVol,
            phase: Rand(0, pi),
            mul: Rand(0.1, 1)
          )
        ), cutoff * Rand(0, 1)
      );

      noize2 = BPF.ar(
        WhiteNoise.ar(
          mul: SinOsc.ar(
            lfoVol,
            phase: Rand(0, pi),
            mul: Rand(0.1, 1)
          )
        ), cutoff * Rand(0, 1)
      );

      noize3 = BPF.ar(
        WhiteNoise.ar(
          mul: SinOsc.ar(
            lfoVol,
            phase: Rand(0, pi),
            mul: Rand(0.1, 1)
          )
        ), cutoff * Rand(0, 1)
      );

      sig = noize1 + noize2 + noize3;
      sig = Limiter.ar(sig * amp);

      Out.ar(out, (sig).dup);
    }).add;

    context.server.sync;

    synth = Synth.new(\Glitch, [
      \out, context.out_b.index],
      context.xg);

    // Norns commands
    this.addCommand("play", "", {
      synth.run(true);
    });

    this.addCommand("stop", "", {
      synth.run(false);
    });

    this.addCommand("lfoVol", "f", {|msg|
      synth.set(\lfoVol, msg[1]);
    });

    this.addCommand("cutoff", "f", {|msg|
      synth.set(\cutoff, msg[1]);
    });

		this.addCommand("amp", "f", {|msg|
			synth.set(\amp, msg[1]);
		});
  }

  free {
    synth.free;
  }
}