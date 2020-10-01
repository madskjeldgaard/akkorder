(
	/*

	STEP 0: Set the settings for the composition

	*/

	~numChans = 2;
	~filter = \rlpf; //[\rlpf, \dfm1].choose; // rlpf or dfm1

	~pieceDurInBeats = 1024;
	~record = false;
	~initTempo = 1.0;

	~layers = 12;

	~root = rrand(-6,6);
	~scale = Scale.aeolian;
	~source = \saw;

	// Curve used for the central envelope in the patterns
	~mainCurve = \lin;

	~chordTightness = 0.25; //rrand(0.75,1.0);
	~unisonAmount = 0; //rrand(0.0,0.5);

	~chords = [
		[0,2,5],
		[3,4,7],
		[0,2,4],
		[2,4,7],
		[1,3,5,7]
	];

	/*

	STEP 1: Setup and server boot

	Anything beyond this point is implementation details. 

	*/

	// Num hardware outputs
	s.options.numOutputBusChannels_(~numChans);
	s.options.numInputBusChannels_(0);

	s.doWhenBooted{
		var panfunc, filterfunc, sourcefunc;
		// Change tempo
		// TempoClock.default.tempo_(0.5);
		sourcefunc = case
		{ ~source == \saw } {
			"Setting source function to saw".postln;
			{|env, freq=442| DPW4Saw.ar(freq: freq, mul: env)}
		}
		{ ~source == \tri } {
			"Setting source function to tri".postln;
			{|env, freq=442| DPW3Tri.ar(freq: freq, mul: env)}
		}
		{ ~source == \square } {
			"Setting source function to square".postln;
			{|env, freq=442, pulsewidth=0.5| PulseDPW.ar(freq: freq, width: pulsewidth, mul: env)}
		};

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
			{|sig, pan=0.0, width=1.5, orientation=0.5| 
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
		};

		// Synth
		SynthDef.new(\default, {
			arg dur, attack=0.01, release=1.0,
			t_gate=1, out, amp=0.5;

			var env = EnvGen.kr(Env.perc(attack, release), t_gate, timeScale: dur, doneAction: 2);
			// var sig = DPW3Tri.ar(freq: freq, mul: env);
			// var sig = DPW4Saw.ar(freq: freq, mul: env);
			var sig = SynthDef.wrap(sourcefunc, prependArgs: [env]);


			sig = SynthDef.wrap(filterfunc, prependArgs:[sig, env]);
			sig = SynthDef.wrap(panfunc, prependArgs:[sig]);

			Out.ar(out, sig * amp);
		}).store;

		Pdef(\master, ~makeComposition.value(~root, ~scale, ~pieceDurInBeats)).play;

	};

	// s.boot;

	/*

	STEP 2: Make, record and play the composition
	Also: start tempobot

	*/

	// ------- Pattern machine ------- //

	~recFunc = {
		var recpath = "~/Desktop/akkorder_%-root%-%.wav".format(
			Date.getDate.stamp, 
			~root,
			~scale.name.toLower
		).asAbsolutePath;

		s.record(path: recpath);

		fork{
			~pieceDurInBeats.wait;
			Tdef(\tempoChanger).stop;
			Tdef(\tempoBot).stop;
			s.stopRecording;
			"%: Done".format(Date.getDate.stamp).postln;
		}
	};

	~record.if({ ~recFunc.value });
	~report = "";

	~makeChordPat = { |oct=5, edur=16, d=0.125, unison=0.0, root, chord, scale, numStuts=3, degreeList=#[0,2,3], amp=0.01|
	var chordSize = chord.size;

	var stutDegrees = Pseq(degreeList,inf);

	var stutPat = Pstutter(
		Pdefn(\stuts, 0) + Pseq((1..numStuts),inf), 
		stutDegrees
	);

	var env = Pn(
		Pseg(
			Pseq([0.00001,1.0,0.00001], inf), 
			edur.clip(0.1,256.0),
			~mainCurve
		)
	);

	var tight = (Pdefn(\tight,1) * 100).clip(1,100);

	var pat = Pbind(
		\scale, scale,
		\stretch, Pdefn(\speed, 1),
		\octave, Pdefn(\octoff, 0) + oct,
		\root, Pdefn(\root, 0),
		\stutDegrees, Pseq([0,2,3],inf),
		\stutPat, stutPat,
		\degree, Pdefn(\note,0)+chord + Pkey(\stutPat), 
		\dur, d.clip(0.001,4.0), 
		\env, env,
		// \lag, Pwhite(0.0,0.01).clump(chordSize), 
		\strum, Pkey(\env)/tight,
		\release, 1+(Pkey(\env)/3),
		\detune, Pkey(\env) * 2  * Pdefn(\detune, 1),
		\amp, Pdefn(\amp, 1) * amp,
		\cutoff, Pkey(\env)/4 + 0.5,
		\pan, Psinen(Pdefn(\pan, 0.1)/rrand(10,100))//Pseg([0,1.0], (Pdefn(\pan,1)/rrand(10,100)).clip(0.00001,10.0), \lin, inf)
	);

	// Unison
	if(unison.isKindOf(Pattern) or: {unison > 0.0}, {
		var detuneMinFreq = 0.1, detuneMaxFreq=10.0;
		var detuneFreq = unison.linexp(0.0,1.0,detuneMinFreq,detuneMaxFreq);

		// Create a duplicate layer which is detuned
		pat = Ppar([
			// Original at half amp
			Pbindf(
				pat, 
				\amp, Pkey(\amp)/2
			), 

			// Detuned at half amp
			Pbindf(
				pat, 
				\amp, Pkey(\amp)/2,
				\detune, Pkey(\detune) * Pwhite(1.0, 1+unison) * detuneFreq 
			)
		])
	});

	pat
};

~stutTheseDegrees = Array.fill(~layers, {
	[0,1,2,3,4,5,6,7].wchoose(
		[0.3,0.05,0.05,0.05,0.15,0.15,0.1,0.1].normalizeSum
	)
});

~makeLayers = {|numLayers=10, numStuts=3, root=0, chord, scale|

	var layers;
	layers = numLayers.collect{|layerNum|
		var thisPat;
		// var beatOffset = 1; 
		var beatOffset = 1/[2,4,8].choose;
		var newLayerEveryBeatNum = layerNum * ((~pieceDurInBeats/(3*numLayers)) + layerNum + beatOffset).round;
		var octave = [3,4,5,6,7].wchoose(
			[0.05,0.15,0.3,0.3,0.15].normalizeSum
		);

		var degrees = if(layerNum > 3, 
			{ ~stutTheseDegrees[..layerNum]}, 
			{ ~stutTheseDegrees[..2]}
		);

		// Metadata
		var m = "Layer num %".format(layerNum);
		m = m + "\n";
		m = m + "Starting at beat num %".format(newLayerEveryBeatNum);
		m = m + "\n";
		m = m + "octave: %".format(octave);
		m = m + "\n";
		m = m + "degrees: %".format(degrees);
		m = m + "\n";
		m = m + "numStuts: %".format(numStuts);
		m = m + "\n";
		m = m + "chord: %".format(chord);
		m = m + "\n";
		m = m + "scale: %".format(scale.name);
		m = m + "\n";
		m = m + "root: %".format(root);
		m = m + "\n";
		m = m + "-----------\n";

		m.postln;

		thisPat = ~makeChordPat.value(
			oct: octave,
			edur: [8,16,32].choose,
			d: [
				1/8,
				// Pseq([0.125, Rest(0.125)].scramble,inf), 
				Pseq([1/8, Rest(1/8)].scramble,inf)
			].wchoose([0.65,0.35]),
			unison: ~unisonAmount,
			scale: scale,
			root: root,
			chord: chord,
			numStuts: numStuts,
			degreeList: degrees, 
			amp: numLayers/300
		);

		[newLayerEveryBeatNum, thisPat]
	}.flatten; 

	Ptpar(layers)
};

~makeSection = { |dur=512, scale, root=0, stutFactor=1|
	var stuts = (1..3) * stutFactor;

	if(0.5.coin, { stuts = stuts.reverse });

		Ptpar([
			0 * dur, ~makeLayers.value(numStuts: stuts[0], scale: scale, root: root, numLayers: ~layers, chord: ~chords.choose),
			1 * dur, ~makeLayers.value(numStuts: stuts[1], scale: scale, root: root, numLayers: ~layers, chord: ~chords.choose),
			2 * dur, ~makeLayers.value(numStuts: stuts[2], scale: scale, root: root, numLayers: ~layers, chord: ~chords.choose)
		])
};

~makeComposition = {|startroot=0, scale, totaldur=1024|
	~makeSection.value(totaldur, scale, startroot)
};

// Make and record the composition
~composition = ~makeComposition.value(~root, ~scale, ~pieceDurInBeats);

~scaleChoice = {|addToDict|
	var name, scale;

	// Random scale name
	name = Scale.names.choose;

	// Check for duplicates
	if(addToDict.includesKey(name), { name = Scale.names.choose });

	// Get scale object for name
	scale = Scale.at(name);

	// Add to dictionary
	addToDict.put(name, scale)	
};

~getScales = {|addToDict, numScales=10|
	numScales.do{ ~scaleChoice.value(addToDict) };
};

	// Set up default tempoclock with a big queue
	// t = TempoClock.new(1.5, nil, nil,  queueSize: 2.pow(14).round);

	TempoClock.default.tempo_(2);

	Pdef.defaultQuant = 4;
	Pdefn.defaultQuant = 4;
)

/*

This is a pretty strange controller setup

Instead of direclty affecting parameters in the patterns above, most controller actions set the values of a dict which is only applied to the patterns once the "set" action is used.

*/
(
	// Actions
	a = IdentityDictionary.new;

	// Values
	v = IdentityDictionary.new;

	v.put(\tempooff, 1);
	v.put(\changetempo, 2);
	v.put(\octoff, 4);


	a.put(\startPat, {|el|
		var val = el.value;
		if(val == 1, {
			"Starting pattern".postln;
			// ~scale = Scale.choose;
			v = IdentityDictionary.new;
			Pdef(\master).play;
		})
	});

	a.put(\newComposition, {|el|
		Pdef(\master, ~makeComposition.value(~root, ~scale, ~pieceDurInBeats));
	});

	a.put(\stopPat, {|el|
		var val = el.value;
		if(val == 1, {
			"stopping pattern".postln;
			Pdef(\master).stop;
		})
	});

	a.put(\applyChanges, {|el|
		var val = el.value;

		if(val == 1, {
			"Applying changes".postln;

			v.keysValuesDo{|key, value|
				"Setting % to %".format(key, value).postln;
				Pdefn(key).source = value;
			};
		});

		TempoClock.default.tempo_(v[\changetempo] ?? 1)
	});

	a.put(\rootNote, {|el|
		var val = el.value;
		val = val.linlin(0.0,1.0,-7,7).round.asInteger;
		"Root note: %".format(val).postln;

		v.put(\root, val)
	});

	a.put(\noteOffset, {|el|
		var val = el.value;
		val = val.linlin(0.0,1.0,-7,7).round.asInteger;
		"note offset: %".format(val).postln;

		v.put(\note, val)
	});

	a.put(\chordTightness, {|el|
		var val = el.value.roundUp(0.01);
		"chord tightness: %".format(val).postln;

		v.put(\tight, val)
	});

	a.put(\tempoprob, {|el|
		var val = el.value;
		"Changing tempo probability: %".format(val).postln;
		~tempoChangeProbability	= val;
	});

	a.put(\tempooff, {|el|
		var val = el.value;
		val = val.linexp(0.0,1.0,0.001,4);
		"Changing tempoclock speed: %".format(val).postln;
		v.put(\tempooff, val)
	});

	a.put(\detune, {|el|
		var val = el.value;
		val = val.linexp(0.0,1.0,1.0,8.0);
		"Changing detune scale: %".format(val).postln;
		v.put(\detune, val)
	});

	a.put(\changeChords, {|el|
		var val = el.value;
		"Changing chords".postln;
	});

	a.put(\changeSpeed, {|el|
		var val = el.value;
		val = val.linexp(0.0,1.0,16.0,0.5).roundUp(0.01);
		"Changing speed: %".format(val).postln;

		v.put(\speed, val)
	});

	a.put(\octoff, {|el|
		var val = el.value;
		val= val.linlin(0.0,1.0,-6,6).round.asinteger;
		"changing octave offset: %".format(val).postln;
		v.put(\octoff, val)
	});

	a.put(\octaveplusone, {|el|
		"changing octave offset by adding 1".postln;
		v.put(\octoff, v.at(\octoff) + 1)
	});

	a.put(\octaveminusone, {|el|
		"changing octave offset by subtracting 1".postln;
		v.put(\octoff, v[\octoff] - 1)
	});

	a.put(\changePanSpeed, {|el|
		var val = el.value.linexp(0.0,1.0,0.1,4.0);
		"Changing pan speed: %".format(val).postln;
		v.put(\pan, val)
	});

	a.put(\stuts, {|el|
		var val = el.value.linlin(0.0,1.0,0,4.0).round.asInteger;
		"Changing stutter offset: %".format(val).postln;
		v.put(\stuts, val)
	});

	a.put(\amp, {|el|
		var val = el.value;
		"Changing amp: %".format(val).postln;
		Pdefn(\amp).quant_(0.0).source = val;
		// v.put(\amp, val)
	});

	a.put(\changetempo, {|el|
		var val = el.value.linexp(0.0,1.0,0.01,4.0);
		"Changing tempo: %".format(val).postln;
		v.put(\changetempo, val)
	});

	~nanoMapping = {

		// Set up controller
		MKtl('nano', "*nanokontrol2");

		MKtl('nano').elAt(\tr, \play).action = a[\startPat];
		MKtl('nano').elAt(\tr, \stop).action = a[\stopPat];
		MKtl('nano').elAt(\tr, \cycle).action = a[\newComposition];
		MKtl('nano').elAt(\tr, \mset).action = a[\applyChanges];

		// MKtl('nano').elAt(\kn, \1).action = a[\changeSpeed];
		MKtl('nano').elAt(\kn, \1).action = nil;
		// MKtl('nano').elAt(\kn, \2).action = a[\rootNote];
		MKtl('nano').elAt(\kn, \2).action = nil;
		MKtl('nano').elAt(\kn, \3).action = a[\stuts];
		MKtl('nano').elAt(\kn, \7).action = a[\changetempo];
		MKtl('nano').elAt(\kn, \8).action = a[\amp];

		MKtl('nano').elAt(\sl, \1).action = a[\noteOffset];
		MKtl('nano').elAt(\sl, \2).action = a[\octOff];
		MKtl('nano').elAt(\sl, \3).action = a[\chordTightness];
		MKtl('nano').elAt(\sl, \4).action = a[\changePanSpeed];
		MKtl('nano').elAt(\sl, \5).action = a[\detune];
	};

	~playstationMapping = {

		// Set up controller
		// If permission errors, run this in a terminal:
		// sudo chmod 666 /dev/hidraw*
		//
		// On the controller: Press the "home" button so that two leds light up on the front
		// On the back of the controller: set rocker switch to D

		MKtl('ps1gamepad', "shanwan_ps3");
		// MKtl('ps1gamepad').trace(true);

		// MKtl('ps1gamepad').elAt('bt', 'start');
		// MKtl('ps1gamepad').elAt('bt', 'sel');

		// MKtl('ps1gamepad').elAt('bt', 'hat_l');
		// MKtl('ps1gamepad').elAt('bt', 'hat_r');

		// MKtl('ps1gamepad').elAt('bt', 'x');
		// MKtl('ps1gamepad').elAt('bt', 'y');
		// MKtl('ps1gamepad').elAt('bt', 'a');
		// MKtl('ps1gamepad').elAt('bt', 'b');

		// MKtl('ps1gamepad').elAt('bt', 'l1');
		// MKtl('ps1gamepad').elAt('bt', 'l2');
		// MKtl('ps1gamepad').elAt('bt', 'r1');
		// MKtl('ps1gamepad').elAt('bt', 'r2');


		// MKtl('ps1gamepad').elAt('joy', 'l', 'x');
		// MKtl('ps1gamepad').elAt('joy', 'l', 'y');

		// MKtl('ps1gamepad').elAt('joy', 'r', 'x');
		// MKtl('ps1gamepad').elAt('joy', 'r', 'y');

		// MKtl('ps1gamepad').elAt('compass', 'compass');
		MKtl('ps1gamepad').elAt('bt', 'start').action = a[\startPat]; // FIXME: Toggle?
		MKtl('ps1gamepad').elAt('bt', 'sel').action = a[\newComposition];

		// FIXME: IS this the right strategy?
		MKtl('ps1gamepad').elAt('bt', 'l1').action = a[\applyChanges];

		MKtl('ps1gamepad').elAt('bt', 'l2').action = a[\octaveminusone];
		MKtl('ps1gamepad').elAt('bt', 'r2').action = a[\octaveplusone];

		// MKtl('ps1gamepad').elAt(\kn, \1).action = a[\changeSpeed];
		// MKtl('ps1gamepad').elAt(\kn, \1).action = nil;
		// MKtl('ps1gamepad').elAt(\kn, \2).action = a[\rootNote];
		MKtl('ps1gamepad').elAt('joy', 'l', 'x').action = a[\stuts];
		// MKtl('ps1gamepad').elAt(\kn, \7).action = a[\changetempo];
		// MKtl('ps1gamepad').elAt(\kn, \8).action = a[\amp];

		MKtl('ps1gamepad').elAt('joy', 'l', 'y').action = a[\noteOffset];
		// MKtl('ps1gamepad').elAt(\sl, \2).action = a[\octOff];
		MKtl('ps1gamepad').elAt('joy', 'r', 'x').action = a[\detune];
		MKtl('ps1gamepad').elAt('joy', 'r', 'y').action = a[\chordTightness];
		// MKtl('ps1gamepad').elAt(\sl, \4).action = a[\changePanSpeed];
	};

	~playstationMapping.value;
)



(
m = MKtl('ps1gamepad', "shanwan_ps3");
m.elAt('bt', 'a').action = {|el|
	if(el.value == 1, {
		z.next(()).play;
	}, {nil})
};

)

MKtl('ps1gamepad').trace(true);

// MKtl('ps1gamepad').elAt('bt', 'start');
// MKtl('ps1gamepad').elAt('bt', 'sel');

p = Pbind(\dur, 0.25, \degree, Pwhite(0,10));
z = p.asStream;
z.next(()).play

(
Pspawn(
	Pbind(
		\delta, 2,
		\divs, 8,
		\detune, Pwhite(0.0,1.0),
		\chord, Pseq([
			#[1,2,3], 
			#[2,5,6], 
			#[3,6,8]
		],inf),
		\method, \par,
		\pattern, Pfunc { |ev|
			var detune = ev[\detune];
			var chord = ev[\chord];
			var mainDelta = ev[\delta];
			var divisions = ev[\divs];

			Pbind(
				\instrument, \default,
				\degree, Pseq((1..4),2) + chord,
				\dur, mainDelta/divisions
			)
		},
	)
).play;
)
