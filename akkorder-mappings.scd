(
// TempoClock.default.tempo
/*

This is a pretty strange controller setup

Instead of direclty affecting parameters in the patterns above, most controller actions set the values of a dict which is only applied to the patterns once the "set" action is used.

*/
	// Actions
	a = IdentityDictionary.new;

	// Values
	v = IdentityDictionary.new;

	// v.put(\tempooff, 1);

	// overall tempo
	v.put(\changetempo, 1);

	// Offset octave in all running patterns
	v.put(\octoff, 0);

	a.put(\startPat, {|el|
		var val = el.value;
		if(val == 1, {
			"Starting pattern".postln;
			// ~scale = Scale.choose;
			v = IdentityDictionary.new;
			Pdef(\master).play;
		})
	});

	a.put(\syncFaders, {|el|
		(1..8).do{|num|
			MKtl('nano').elAt('sl', num.asSymbol).doAction;
			MKtl('nano').elAt('kn', num.asSymbol).doAction;
		};
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


	a.put(\randScale, {|el|
		var val = el.value;
		if(val == 1, {
			var newScale = Scale.choose;
			"New scale: %".format(newScale.name).postln;
			Pdefn(\scale).source = newScale
		})
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

// 	a.put(\tempooff, {|el|
// 		var val = el.value;
// 		val = val.linexp(0.0,1.0,0.001,4);
// 		"Changing tempoclock speed: %".format(val).postln;
// 		v.put(\tempooff, val)
// 	});

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
		val= val.linlin(0.0,1.0,-6,6).round.asInteger;
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

		"Mapping for korg nanokontrol".postln;

		// Set up controller
		MKtl('nano', "*nanokontrol2");

		MKtl('nano').elAt(\tr, \play).action = a[\startPat];
		MKtl('nano').elAt(\tr, \stop).action = a[\stopPat];
		MKtl('nano').elAt(\tr, \fwd).action = a[\randScale];

		MKtl('nano').elAt(\tr, \cycle).action = a[\newComposition];
		MKtl('nano').elAt(\tr, \mset).action = a[\applyChanges];

		MKtl('nano').elAt(\sl, \1).action = a[\noteOffset];
		MKtl('nano').elAt(\sl, \2).action = a[\detune];
		MKtl('nano').elAt(\sl, \3).action = a[\chordTightness];
		MKtl('nano').elAt(\sl, \4).action = a[\changePanSpeed];
		MKtl('nano').elAt(\sl, \5).action = a[\stuts];
		// MKtl('nano').elAt(\sl, \7).action = a[\changeSpeed];

		MKtl('nano').elAt(\sl, \6).action = a[\octoff];

		MKtl('nano').elAt(\kn, \1).action = a[\changetempo];
		MKtl('nano').elAt(\kn, \8).action = a[\amp];

		a[\syncFaders].value;

		// MKtl('nano').elAt(\kn, \1).action = a[\changeSpeed];
		// MKtl('nano').elAt(\kn, \1).action = nil;
		// MKtl('nano').elAt(\kn, \2).action = a[\rootNote];
		// MKtl('nano').elAt(\kn, \2).action = nil;
		// MKtl('nano').elAt(\kn, \3).action = a[\stuts];
		// MKtl('nano').elAt(\kn, \7).action = a[\changetempo];

	};

	~playstationMapping = {

		"Mapping for playstation knockoff controller".postln;

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

)

