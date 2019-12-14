(
	/*
    _    _    _                 _           
   / \  | | _| | _____  _ __ __| | ___ _ __ 
  / _ \ | |/ / |/ / _ \| '__/ _` |/ _ \ '__|
 / ___ \|   <|   < (_) | | | (_| |  __/ |   
/_/   \_\_|\_\_|\_\___/|_|  \__,_|\___|_|   

	This is the script used to generate the compositions for the pieces on the
	release "Akkorder" by Mads Kjeldgaard, released by Ambitious Tapes in 2020.

	With this you can generate as many versions of the pieces as you want.

	The script creates a generative composition of interlaced chord structures,
	plays it and records it to your desktop in realtime.

	The script has a few features that I will describe below:

	DISJOINTED CHORDS 
	My main interest for these pieces was to work with a sort of
	timed dissolving where the chords would progressively go from having the notes
	of the chord played at the same time to having each note becoming more and more
	offset so that the chord falls apart, before it snaps back into place.
	Something interesting happens, psychoacoustically I think, when several of
	these are played at the same time. 

	TEMPOBOT
	A tempobot is included. It is a probability based bot which may or may not
	dynamically change the overall tempo of the composition while it plays. Watch
	the post window to see what it's up to.

	GENERATIVE TONALITY
	The root note and scale is randomly chosen at the beginning of each iteration

	ARBITRARY SOUND SOURCE
	The sound source can be a square wave, triangle wave or saw wave played back in anything from 1 to 64 speakers

	STUTTER STRUCTURES
	Each chord "stream" is organized in a probability based stutter structure. 

	*/

	/*

	STEP 0: Set the settings for the composition

	*/

	~numChans = 2;
	~filter = [\rlpf, \dfm1].choose; // rlpf or dfm1
	~source = [\square, \saw, \tri].choose; // square, saw, tri

	~pieceDurInBeats = 512;
	~record = true;
	~initTempo = 1.0;

	~layers = 12;

	~root = rrand(-6,6);
	~scale = Scale.choose;
	// ~mainCurve = Pwhite(-10.0,10.0); // \exp

	// Curve used for the central envelope in the patterns
	~mainCurve = \lin;

	~tempoChangeProbability = 0.5;
	~tempoChangeTime = 32;

	~chordTightness = 0.25; //rrand(0.75,1.0);
	~unisonAmount = rrand(0.0,0.5);

	~chords = [
		[0,2,5],
		[0,2,4],
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
		TempoClock.default.tempo_(1);

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
			{|env, freq=442, width=0.5| PulseDPW.ar(freq: freq, width: width, mul: env)}
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
	};

	s.boot;

	s.waitForBoot{
		~composition.play(quant:0.125)
	};

	/*

	STEP 2: Make, record and play the composition
	Also: start tempobot

	*/

	TempoClock.default.tempo_(~initTempo);

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
		Pseq((1..numStuts),inf), 
		stutDegrees
	);

	var env = Pn(
		Pseg(
			Pseq([0.00001,1.0,0.00001], inf), 
			edur,
			~mainCurve
		)
	);

	var tight = (~chordTightness * 100).clip(1,100);

	var pat = Pbind(
		\scale, scale,
		\octave, oct,
		\root, root,
		\stutDegrees, Pseq([0,2,3],inf),
		\stutPat, stutPat,
		\degree, chord + Pkey(\stutPat), 
		\dur, d, 
		\env, env,
		\lag, Pwhite(0.0,0.01).clump(chordSize), 
		\strum, Pkey(\env)/tight,
		\release, 1+Pkey(\env),
		\detune, Pkey(\env) * 2,
		\amp, amp,
		\cutoff, Pkey(\env)/4 + 0.5,
		\pan, rrand(0.25,0.75)	
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

	Pfindur(dur,
		Ptpar([
			0 * dur, ~makeLayers.value(numStuts: stuts[0], scale: scale, root: root, numLayers: ~layers, chord: ~chords.choose),
			1 * dur, ~makeLayers.value(numStuts: stuts[1], scale: scale, root: root, numLayers: ~layers, chord: ~chords.choose),
			2 * dur, ~makeLayers.value(numStuts: stuts[2], scale: scale, root: root, numLayers: ~layers, chord: ~chords.choose)
		])
	)
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

// ------- Tempo changer ------- //
Tdef(\tempoChanger, {

	var fadeTime = ~tempoChangeTime;
	var deviation = 0.1;

	// Time between tempo adjustments
	var timeGrain = 0.01;

	// Fade time
	var fTime = fadeTime ?? 8;

	// Current tempo
	var ogTemp = TempoClock.default.tempo;

	// Target tempo
	// var newTemp = 0.01;
	var newTemp = if(ogTemp < 0.25, {
		ogTemp + (1* deviation)
	}, {
		ogTemp + ([1,-1].choose * deviation)
	}
);

// Envelope used for the fading
var env = Pseg([ogTemp, newTemp], fTime, \exp).asStream;

var val = 0;

// Do the tempo change
loop{
	timeGrain.wait;

	val = env.next;

	if(val.isNil, { 
		Tdef(\tempoChanger).stop;
	}, {
		TempoClock.default.tempo = val;
	})
}
}).reset;

Tdef(\tempoBot, {
	"Tempobot is alive".postln;

	loop{ 
		var now = Date.getDate.stamp;
		if(~tempoChangeProbability.coin, {
			"%: Tempobot changing tempo!".format(now).postln;
			Tdef(\tempoChanger).reset.play
		}, {
			"%: Tempobot not changing tempo".format(now).postln;
		});

		~tempoChangeTime.wait;
	}
}).reset.play;

)
