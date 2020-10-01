/*

HERLEV 2019

*/
// ------- Setup ------- // 
(
	~numChans = 2;
	~filter = \dfm1;
	~record = true;

	// Num hardware outputs
	s.options.numOutputBusChannels_(~numChans);
	s.options.numInputBusChannels_(0);

	s.doWhenBooted{
		var panfunc, filterfunc;
		var recpath = "~/Desktop/akkorder-%-%chans.wav".format(
			Date.getDate.stamp, 
			~numChans
		).asAbsolutePath;

		~record.if({ s.record(path: recpath) });

		// Defaults
		Pdefn(\scale, Scale.major);
		Pdefn(\chord, [0, 2, 5]);
		Pdefn(\root, 0);
		Pdefn(\amp, 0.60);
		Pdefn(\stutDegrees, 
			Pstutter(
				Pseq((1..3),inf), 
				Pseq([0,2,3],inf)
			)
		);

		// Change tempo
		TempoClock.default.tempo_(1.5);

		// Pan function
		panfunc = case
		{~numChans == 1} { 
			"Setting pan function to mono (no panning)".postln;
			{|sig, pan| sig }
		}
		{~numChans == 2} {
			"Setting pan function to stereo".postln;
			{|sig, pan=0.5| Pan2.ar(in:sig, pos: pan.linlin(0.0,1.0,-1.0,1.0)) }
		}
		{~numChans > 2} {
			"Setting pan function to multichan (% channels)".format(~numChans).postln;
			{|sig, pan=0.0, width=2.0, orientation=0.5| 
				PanAz.ar(
					numChans: ~numChans, 
					in: sig, 
					pos: pan.linlin(0.0,1.0,-1.0,1.0),
					width: width, 
					orientation: orientation
				) 
			}
		};

		// Filter function
		filterfunc = case
		{~filter == \rlpf} { 
			"Setting filter function to RLPF".postln;
			{|sig, env, cutoff=0.3, rq=1| 
				cutoff = cutoff.linexp(0.0,1.0,40,20000);
				RLPF.ar(sig, cutoff, rq.clip(0.0,1.0)) 
			}
		}
		{~filter == \dfm1} {
			"Setting filter function to DFM1".postln;
			{|sig, env, cutoff=0.75, res=0.5| 
				cutoff = cutoff.linexp(0.0,1.0,40,20000);
				DFM1.ar(
					sig, 
					cutoff,
					res: res, 
					inputgain: 1.0,  
					type: 0.0,  
					noiselevel: 0.0
				)
			}
		}
		{~filter == \tb303} {
			"Setting filter function to tb303 simulation RLPFD".postln;
			{|sig, env, cutoff=0.35, res=0.5, dist=0.0| 
				cutoff = cutoff.linexp(0.0,1.0,40,12000);
				RLPFD.ar(
					sig, 
					cutoff, //env.linexp(0.0,1.0,cutoff/4, cutoff), 
					res.linlin(0.0,1.0,0.0,0.75), 
					dist
				) * 3	
			}
		};

		// Synth
		SynthDef.new(\default, {
			arg dur, attack=0.01, release=1.0,
			t_gate=1, out, freq=442, amp=0.5;

			var env = EnvGen.kr(Env.perc(attack, release), t_gate, timeScale: dur, doneAction: 2);
			var sig = DPW3Tri.ar(freq: freq, mul: env);

			sig = SynthDef.wrap(filterfunc, prependArgs:[sig, env]);
			sig = SynthDef.wrap(panfunc, prependArgs:[sig]);

			Out.ar(out, sig * amp);
		}).add;
	};

	s.boot;
)
// ------- Hello ------- //
(
	Synth(\default, [\freq, [50,53,55].choose.midicps, \dur, 1, \amp, 0.35]);

	"Hello ...".postln;
)
(
	Synth(\default, [\freq, [65,63,65].choose.midicps, \dur, 1, \amp, 0.35]);

	"My name is Mads ...".postln;
)
(
	Synth(\default, [\freq, [45, 47, 48].choose.midicps, \dur, 1, \amp, 0.35]);

	"I'm happy to be here... ".postln;
)
(	
	Pbind(\dur,0.05 * Pseries(1,0.1,16), \octave, 4, \degree, Pseries(1,1,16),\pan, Pwhite(), \amp, 0.35).play;

	"... playing these sounds for you:".postln;
)
(
	Pbind(\dur,0.025 * Pseries(1,0.1,16), \degree, Pseries(1,1,16),\pan, Pwhite(), \amp, 0.35).play;

	"... swarms of notes ".postln;
)
(
	Pbind(\degree, Pbrown(1,10,1,32), \dur, Pkey(\degree)/50, \pan, Pwhite(), \amp, 0.35).play;
	"and strange patterns...".postln
)
(
	Pbind(\degree, Pbrown(1,4,1,4), \octave, 4,\dur, Pseq([0.5,0.25],inf), \pan, Pwhite(), \amp, 0.35).play;
	"constructions, really ...".postln
)
// ------- Pattern machine ------- //
(
	f = { |oct=5, edur=16, d=0.125, unison=0.0|
		var chordSize = Pdefn(\chord).source.size;
		var pat = Pbind(
			\scale, Pdefn(\scale),
			\octave, oct,
			\root, Pdefn(\root),
			\degree, Pdefn(\chord) + Pdefn(\stutDegrees), 
			\dur, d, 
			\env, Pn(
				Pseg(
					Pseq([0.00001,1.0,0.00001], inf), 
					edur,
					\exp
				)
			),
			\lag, Pwhite(0.0,0.01).clump(chordSize), 
			\strum, Pkey(\env)/12,
			\release, 1+Pkey(\env),
			\detune, Pkey(\env) * 2,
			\amp, Pdefn(\amp),
			\cutoff, 0.75,
			// \pan, Pkey(\env) * [0.05, 0.5, 0.95]			
			\pan, 
				Pwhite(0.95,1.0).clump(chordSize) *
				 Pseg(Pseq([0.0,1.0],inf), edur * Pxrand([1,2,3,2],inf), \lin, \inf)
		);

		if(unison.isKindOf(Pattern) or: {unison > 0.0}, {
			"unison't %!".format(unison).postln;
			pat = Ppar([
				Pbindf(pat, \amp, Pkey(\amp)/2), 
				Pbindf(pat, \detune, Pkey(\detune) * Pwhite(1.0, 1+unison) * unison.linexp(0.0,1.0,0.1,10.0), \amp, Pkey(\amp)/2)
			])
		}, {
			"not unison't %!".format(unison).postln;
		});

		pat
	};

	// Create layers with time offset
	k = {|numLayers=8|
		var lays = numLayers.collect{ |i|
			[
				i*64+i,
				f.value(
					oct: [3,4,5,6,7].wchoose([0.1,0.2,0.3,0.3,0.1].normalizeSum), 
					edur: [16,32,64].wchoose([0.25,0.5,0.25]),
					unison: 0.0 //Psinen(0.0001)
				)
			]
		}.flatten;

		lays = Ptpar(lays);
		
		Pbindf(lays, \amp, Pkey(\amp)/numLayers)
	};

	// Play first version
	Pdef(\chords1, k.value).play(quant:1);

)
// ------- Tempo changer ------- //
(
~targetTempo = 0.715;
~fadeTime = 128;

Tdef(\tempo, {

	// Time between tempo adjustments
	var timeGrain = 0.01;

	// Fade time
	var fTime = ~fadeTime ?? 8;

	// Current tempo
	var ogTemp = TempoClock.default.tempo;

	// Target tempo
	// var newTemp = 0.01;
	var newTemp = ~targetTempo ?? 0.5;

	// Envelope used for the fading
	var env = Pseg([ogTemp, newTemp], fTime, \exp).asStream;

	var val = 0;

	// Do the tempo change
	loop{
		timeGrain.wait;

		val = env.next;

		if(val.isNil, { 
			"Done changing tempo".postln;
			Tdef(\tempo).stop 
		}, {
			"Tempo = %".format(val).postln;
			TempoClock.default.tempo = val;
		})
	}
}).play;
)
// ------- Change structure internals ------- //
(
	Pdefn(\scale, Scale.major).quant_(8);
	Pdefn(\chord, [0, 2, 5]).quant_(8);
	Pdefn(\root, -3).quant_(8);
	Pdefn(\amp, 0.17);
	Pdefn(\stutDegrees, 
		Pstutter(
			1, //Pseq((1..3),inf), 
			Pseq([0,3,2,5,3,7],inf)
		)
	).quant_(8);
)
// ------- Add new layers ------- //
(
	Pdef(\chords2, 
		Pbindf(
			Pdef(\chords1), 
			\degree, 2+Pkey(\degree)
		)
	).play(quant: 3);
)

(
	Pdef(\chords3, 
		Pbindf(
			Pdef(\chords1), \dur, Pkey(\dur) * 2, 
			\degree, 2-Pkey(\degree),
			\amp, 0.5*Pkey(\amp)
		)
	).play(quant: 8);
)

(
	Pdef(\chords4, 
		Pbindf(
			Pdef(\chords1), 
			\stretch, 1,
			\dur, Pkey(\dur), 
			\degree, Pseq([5,4],inf)+Pkey(\degree),
			\amp, 0.35 * Pkey(\amp)
		)
	).play(quant: 1);
)


(
	Pdef(\mike3, 
		Pbind(
			\dur, 1,
			\stretch, 2,
			\degree, Pdefn(\digz, 0)
		)
	).play;
)

Pdefn(\digz, 7).quant_(4)

TempoClock.default.tempo_(1)

Pdefn(\root, 0);
























Pdefn(\root, rrand(0,10)).quant_(8);




Pdefn(\chord, [0, 2, 5]).quant_(16);

