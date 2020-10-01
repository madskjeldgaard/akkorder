(
	/*

	STEP 0: Set the settings for the composition

	*/

	~numChans = 2;
	~filter = \rlpf; //[\rlpf, \dfm1].choose; // rlpf or dfm1

	~pieceDurInBeats = 1024;
	~record = false;
	~initTempo = 0.9;

	~layers = 12;

	~root = rrand(-6,6);
	// ~scale = Scale.aeolian;
	// ~scale = Pdefn(\scale, Scale.choose);
	~scale = Pdefn(\scale, Scale.ionian);
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
			{|sig, pan=0.0| Pan2.ar(in:sig, pos: pan) }

			// {|sig, pan=0.5| Pan2.ar(in:sig, pos: pan.linlin(0.0,1.0,-1.0,1.0)) }
		}
		{~numChans > 2} {
			"Setting pan function to multichan (% channels)".format(~numChans).postln;
			{|sig, pan=0.0, width=1.5, orientation=0.5| 
				PanAz.ar(
					numChans: ~numChans, 
					in: sig, 
					pos: pan,
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

		// Pdef(\master, ~makeComposition.value(~root, Pdefn(\scale, Scale.choose), ~pieceDurInBeats)).play;

		// Setup mapping
		"/home/mads/code/sc/akkorder/akkorder-mappings.scd".load;

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
			~scale.source.name.toLower
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
		\cutoff, Pkey(\env)/5 + 0.6,
		\pan, Psine(Pdefn(\pan, 0.1) / rrand(10,100) )
		// \pan, Psinen(Pdefn(\pan, 0.1)/rrand(10,100))//Pseg([0,1.0], (Pdefn(\pan,1)/rrand(10,100)).clip(0.00001,10.0), \lin, inf)
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
		m = m + "scale: %".format(scale.source.name);
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

	TempoClock.default.tempo_(~initTempo);

	Pdef.defaultQuant = 4;
	Pdefn.defaultQuant = 4;


	~nanoMapping.value;
)

/*

1. Press cycle
2. Touch all sliders
3. Apply
4. Play

*/


// TempoClock.default.tempo
